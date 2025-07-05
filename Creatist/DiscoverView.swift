import SwiftUI

struct DiscoverView: View {
    @State private var searchText: String = ""
    let genres = UserGenre.allCases
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    @State private var selectedGenre: UserGenre? = nil
    
    var filteredGenres: [UserGenre] {
        if searchText.isEmpty {
            return genres
        } else {
            return genres.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredGenres, id: \ .self) { genre in
                        Button(action: {
                            print("Genre tapped: \(genre.rawValue)")
                            selectedGenre = genre
                        }) {
                            GenreCell(genre: genre)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Editor, Composer and many more")
            .background(
                NavigationLink(
                    destination: Group {
                        if let genre = selectedGenre {
                            TopNearbyView(genre: genre)
                        }
                    },
                    isActive: Binding(
                        get: { selectedGenre != nil },
                        set: { if !$0 { selectedGenre = nil } }
                    )
                ) { EmptyView() }
                .hidden()
            )
        }
    }
}

struct UserListView: View {
    let genre: UserGenre
    @State private var users: [User] = []
    @State private var isLoading: Bool = true
    
    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else if users.isEmpty {
                Text("No users found for \(genre.rawValue.capitalized)")
                    .foregroundColor(.secondary)
            } else {
                ForEach(users, id: \ .id) { user in
                    VStack(alignment: .leading) {
                        Text(user.name)
                            .font(.headline)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(genre.rawValue.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                users = await Creatist.shared.fetchUsers(for: genre)
                isLoading = false
            }
        }
    }
}

struct GenreCell: View {
    let genre: UserGenre
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .shadow(radius: 2)
            Text(genre.rawValue.capitalized)
                .font(.headline)
                .padding()
        }
        .frame(height: 100)
    }
}

#Preview {
    DiscoverView()
}
