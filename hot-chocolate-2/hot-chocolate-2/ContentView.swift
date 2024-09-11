import SwiftUI
import AppIntents
extension UIApplication {
    func endEditing(_ force: Bool = false) {
        windows.filter {$0.isKeyWindow}.first?.endEditing(force)
    }
}

import WatchConnectivity
import UIKit



struct ContentView: View {
    @StateObject private var resultsFetcher = ResultsFetcher() // Add this
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SubmitFormView()
                .tabItem {
                    Label("Submit Data", systemImage: "document.badge.arrow.up")
                    
                }
                .tag(0)
            
            ResultsView() // Pass the results fetcher here
                .tabItem {
                    Label("View Results", systemImage: "list.bullet.clipboard")
                }
                .tag(1)
        }
        .onAppear {
            resultsFetcher.fetchResults() // Preload results when ContentView appears
        }
    }
}

struct SubmitFormView: View {
    @State private var name = ""
    @State private var location = ""
    @State private var richness = 5
    @State private var sweetness = 5
    @State private var creaminess = 5
    @State private var speed = 5
    @State private var temperature = 5
    @State private var isSubmitted = false
    @State private var isAnimating = false

    private let nameKey = "savedName"

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Your Information")) {
                    TextField("Your Name", text: $name)
                        .onAppear {
                            loadName()
                        }
                    TextField("Hot Chocolate Restaurant Name", text: $location)
                }

                Section(header: Text("Rate the Hot Chocolate")) {
                    SliderField(title: "Richness", value: $richness)
                    SliderField(title: "Sweetness", value: $sweetness)
                    SliderField(title: "Creaminess", value: $creaminess)
                    SliderField(title: "Speed", value: $speed)
                    SliderField(title: "Temperature", value: $temperature)
                    Button(action: submitData) {
                        if isSubmitted {
                            Label("Submitted", systemImage: "checkmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .background(isSubmitted ? Color.green : Color.accentColor)
                                .listRowBackground(Color.clear)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        } else {
                            Label("Submit Form", systemImage: "arrow.up.document")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .background(isSubmitted ? Color.green : Color.accentColor)
                                .listRowBackground(Color.clear)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .transition(.opacity)
                        }
                    }
                    .disabled(isSubmitted)
                }
            }
            .navigationTitle("Submit Hot Chocolate")
        }
        .onChange(of: isSubmitted) { newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    resetForm()
                }
            }
        }
    }

    func submitData() {
        // Save the name
        saveName()

        // Trigger a big haptic feedback
        self.isSubmitted = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()


        let formData: [String: Any] = [
            "name": name,
            "location": location,
            "richness": richness,
            "sweetness": sweetness,
            "creaminess": creaminess,
            "speed": speed,
            "temperature": temperature
        ]

        if let url = URL(string: "https://script.google.com/macros/s/AKfycbzhNI2GvZBFs7p2mVX2CpZv1ydPLvaMftoqj7dJECy58K-nkOMkD8qPeYplcA3eKLI/exec") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let jsonData = try? JSONSerialization.data(withJSONObject: formData)
            request.httpBody = jsonData

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Failed to submit form: \(error)")
                    return
                }

                DispatchQueue.main.async {
                    self.isSubmitted = false
                }
            }.resume()
        }
    }

    func resetForm() {
        name = ""
        location = ""
        richness = 5
        sweetness = 5
        creaminess = 5
        speed = 5
        temperature = 5
        isSubmitted = false
    }

    // Save the name to UserDefaults
    private func saveName() {
        UserDefaults.standard.set(name, forKey: nameKey)
    }

    // Load the name from UserDefaults
    private func loadName() {
        if let savedName = UserDefaults.standard.string(forKey: nameKey) {
            name = savedName
        }
    }
}

struct SliderField: View {
    var title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(title): \(value)")
            Slider(value: Binding(
                get: { Double(value) },
                set: { newValue in
                    value = Int(newValue).clamped(to: 1...10)
                    UIApplication.shared.endEditing() // Hide keyboard
                }
            ), in: 1...10, step: 1)
        }
    }
}
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension Binding {
    // Helper to bind a slider to Int values
    func map<T>(to range: ClosedRange<T>) -> Binding<T> where Value == Double, T: BinaryFloatingPoint {
        Binding<T>(
            get: { T(self.wrappedValue) },
            set: { self.wrappedValue = Double($0).clamped(to: Double(range.lowerBound)...Double(range.upperBound)) }
        )
    }
}

import SwiftUI

class ResultsFetcher: ObservableObject {
    @Published var results = [HotChocolateResult]()
    @Published var isLoading = true // State to track loading status
    
    func fetchResults() {
        if let url = URL(string: "https://script.google.com/macros/s/AKfycbzhNI2GvZBFs7p2mVX2CpZv1ydPLvaMftoqj7dJECy58K-nkOMkD8qPeYplcA3eKLI/exec") {
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data {
                    let results = try? JSONDecoder().decode([HotChocolateResult].self, from: data)
                    DispatchQueue.main.async {
                        self.results = results ?? []
                        self.isLoading = false // Hide the loading indicator
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false // Hide the loading indicator in case of error
                    }
                }
            }.resume()
        }
    }
}

struct ResultsView: View {
    @State private var results = [HotChocolateResult]()
    @State private var isLoading = true
    @State private var searchText = ""

    // Determine the highest-rated result
    private var highestRatedResult: HotChocolateResult? {
        filteredResults.first
    }

    private var filteredResults: [HotChocolateResult] {
        let sortedResults = results.sorted { $0.overallScore > $1.overallScore }
        
        if searchText.isEmpty {
            return sortedResults
        } else {
            return sortedResults.filter { $0.location.lowercased().contains(searchText.lowercased()) }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    Label("Loading...", systemImage:"mug.fill")
                        .symbolEffect(.breathe)
                        .scaleEffect(1.5)
                        .bold()
                        .foregroundColor(.accentColor)
                        
                        
                } else {
                    List {
                        ForEach(filteredResults.indices, id: \.self) { index in
                            let result = filteredResults[index]
                            HStack {
                                if index == 0 {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                } else if index == 1 {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.gray)
                                } else if index == 2 {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.brown)
                                }

                                NavigationLink(destination: ResultDetailView(result: result)) {
                                    HStack {
                                        Text(result.location)
                                        Spacer()
                                        Text(String(format: "%.2f", result.overallScore))
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                        }
                    }

                    if let topResult = highestRatedResult {
                        Button(action: {
                            openInMaps(address: topResult.location)
                        }) {
                            Text("Get Directions to \(topResult.location)")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding()
                        }
                    }
                }
            }
            .onAppear(perform: fetchResults)
            .navigationTitle("Results")
        }
    }

    private func openInMaps(address: String) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://maps.apple.com/?address=\(encodedAddress)") {
            UIApplication.shared.open(url)
        }
    }

    func fetchResults() {
        if let url = URL(string: "https://script.google.com/macros/s/AKfycbzhNI2GvZBFs7p2mVX2CpZv1ydPLvaMftoqj7dJECy58K-nkOMkD8qPeYplcA3eKLI/exec") {
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data {
                    let results = try? JSONDecoder().decode([HotChocolateResult].self, from: data)
                    DispatchQueue.main.async {
                        self.results = results ?? []
                        self.isLoading = false // Hide the loading indicator
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false // Hide the loading indicator in case of error
                    }
                }
            }.resume()
        }
    }
}

struct SearchBar: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search"
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
        uiView.delegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UISearchBarDelegate {
        var parent: SearchBar

        init(_ parent: SearchBar) {
            self.parent = parent
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }
    }
}


import SwiftUI

struct ResultDetailView: View {
    let result: HotChocolateResult

    var body: some View {
        VStack(alignment: .leading) {
            // Information section
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "tag.fill")
                        .padding(.top, 5)
                    Text(result.name)
                        .font(.headline)
                }
            }
            .padding(.bottom, 10)
            
            // Ratings section
            VStack(alignment: .leading, spacing: 8) {
                RatingBar(title: "Richness", value: result.richness)
                RatingBar(title: "Sweetness", value: result.sweetness)
                RatingBar(title: "Creaminess", value: result.creaminess)
                RatingBar(title: "Speed", value: result.speed)
                RatingBar(title: "Temperature", value: result.temperature)
            }
            .padding(.vertical)
            
            // Overall Score
            VStack(alignment: .leading) {
                RatingBar(title: "Overall Score", value: Int(result.overallScore))
                    .padding(.bottom)
                    .bold()
            }
            .padding(.top)
            
            // Button section
            Button(action: openInMaps) {
                HStack {
                    Image(systemName: "map.fill")
                        .padding(.bottom, 10)
                    Text("Find nearest \(result.location) in Maps")
                        .padding(.bottom, 10)
                }
            }
            .padding(.top, 10)

            Spacer() // Push content to top
        }
        .padding() // Add padding around the VStack
        .navigationTitle(result.location)
    }
    
    private func openInMaps() {
        let encodedAddress = result.location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://maps.apple.com/?q=\(encodedAddress)") {
            UIApplication.shared.open(url)
        }
    }
}
struct ThickProgressViewStyle: ProgressViewStyle {
    var thickness: CGFloat = 20 // Thickness of the colored part
    var maxWidth: CGFloat = 300 // Maximum width of the progress bar

    func makeBody(configuration: Configuration) -> some View {
        VStack {
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: thickness / 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: thickness)
                    .frame(maxWidth: maxWidth) // Apply max width

                // Foreground (progress)
                RoundedRectangle(cornerRadius: thickness / 2)
                    .fill(Color.accentColor)
                    .frame(width: CGFloat(configuration.fractionCompleted ?? 0) * maxWidth, height: thickness)
            }
        }
    }
}

struct RatingBar: View {
    var title: String
    var value: Int
    
    var body: some View {
        HStack {
            Text("\(title)")
                .frame(width: 120, alignment: .leading) // Fixed width for alignment
            ProgressView(value: Double(value), total: 10)
                .progressViewStyle(ThickProgressViewStyle(thickness: 20, maxWidth: 200)) // Adjust max width if needed
            Text("\(value)/10")
                .fontWeight(.bold)
                .frame(width: 50, alignment: .leading) // Fixed width for alignment
        }
        .padding(.bottom, 5) // Add bottom padding for spacing between bars
    }
}

struct HotChocolateResult: Identifiable, Decodable {
    let id = UUID()
    let name: String
    let location: String
    let richness: Int
    let sweetness: Int
    let creaminess: Int
    let speed: Int
    let temperature: Int
    
    // Compute the overall score as the average of all ratings
    var overallScore: Double {
        let total = Double(richness + sweetness + creaminess + speed + temperature)
        return total / 5.0
    }
}
