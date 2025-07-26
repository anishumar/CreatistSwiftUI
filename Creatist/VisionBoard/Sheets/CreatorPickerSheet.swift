import SwiftUI

struct CreatorPickerSheet: View {
    let genre: UserGenre
    let users: [User]
    let selected: [User] // Add this parameter
    let onSelect: (User) -> Void
    let onCancel: () -> Void
    @State private var searchText: String = ""
    @State private var suggestions: [User] = []
    @State private var isLoadingSuggestions = false

    var filteredUsers: [User] {
        let selectedIds = Set(selected.map { $0.id })
        let availableUsers = users.filter { !selectedIds.contains($0.id) }
        if searchText.isEmpty {
            return availableUsers
        } else {
            return availableUsers.filter { user in
                user.name.localizedCaseInsensitiveContains(searchText) ||
                (user.username?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var filteredSuggestions: [User] {
        let followingIds = Set(users.map { $0.id })
        let selectedIds = Set(selected.map { $0.id })
        let filtered = suggestions.filter { !followingIds.contains($0.id) && !selectedIds.contains($0.id) }
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { user in
                user.name.localizedCaseInsensitiveContains(searchText) ||
                (user.username?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(filteredUsers, id: \ .id) { user in
                        DetailedUserCardNoFollowCompact(user: user)
                            .onTapGesture {
                                onSelect(user)
                            }
                    }
                    if isLoadingSuggestions {
                        ProgressView().padding()
                    } else if !filteredSuggestions.isEmpty {
                        Divider().padding(.vertical, 8)
                        Text("Suggestions for \(genre.rawValue.capitalized)")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        ForEach(filteredSuggestions, id: \ .id) { user in
                            DetailedUserCardNoFollowCompact(user: user)
                                .onTapGesture {
                                    onSelect(user)
                                }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Add Creator")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by name or username")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
            .task {
                isLoadingSuggestions = true
                let genreSuggestions = await Creatist.shared.fetchUsers(for: genre)
                suggestions = genreSuggestions
                isLoadingSuggestions = false
            }
        }
    }
}

// Custom environment key for image size
private struct DetailedUserCardImageSizeKey: EnvironmentKey {
    static let defaultValue: CGSize? = nil
}
extension EnvironmentValues {
    var _detailedUserCardImageSize: CGSize? {
        get { self[DetailedUserCardImageSizeKey.self] }
        set { self[DetailedUserCardImageSizeKey.self] = newValue }
    }
} 