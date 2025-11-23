import SwiftUI

struct CountryCodePickerView: View {
    @Binding var selectedCountryCode: CountryCode
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    var filteredCountries: [CountryCode] {
        if searchText.isEmpty {
            return CountryCode.countries
        } else {
            return CountryCode.countries.filter { country in
                country.name.localizedCaseInsensitiveContains(searchText) ||
                country.code.localizedCaseInsensitiveContains(searchText) ||
                country.id.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search country", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Country list
                List(filteredCountries) { country in
                    Button(action: {
                        selectedCountryCode = country
                        dismiss()
                    }) {
                        HStack {
                            Text(country.flag)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.name)
                                    .foregroundColor(.primary)
                                    .font(.body)
                                Text(country.code)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            Spacer()
                            if country.id == selectedCountryCode.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

