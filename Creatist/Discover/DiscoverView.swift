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

// Add this extension to map genre to image name
extension UserGenre {
    var imageName: String {
        "genre_\(self.rawValue)"
    }
}

// Update GenreCell to show image
struct GenreCell: View {
    let genre: UserGenre
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(genre.imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 120)
                .clipped()
                .accessibilityLabel(Text("\(genre.rawValue.capitalized) icon"))
            // Gradient overlay for text readability
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.45)]),
                startPoint: .center, endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            // Genre name
            Text(genre.rawValue.capitalized)
                .font(.headline)
                .foregroundColor(.white)
                .padding([.leading, .bottom], 12)
                .shadow(radius: 4)
        }
        .frame(height: 120)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    DiscoverView()
}
