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
    static let flatColors: [Color] = [
        Color(red: 1.00, green: 0.60, blue: 0.30), // Orange
        Color(red: 1.00, green: 0.30, blue: 0.30), // Red
        Color(red: 0.30, green: 0.60, blue: 1.00), // Blue
        Color(red: 0.60, green: 0.40, blue: 1.00), // Purple
        Color(red: 0.78, green: 0.68, blue: 0.92), // Soft purple
        Color(red: 1.00, green: 0.78, blue: 0.60)  // Soft orange
    ]
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Flat, bold color background
            GenreCell.flatColors[genreIndex % GenreCell.flatColors.count]
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            // Large, blurred, zoomed-in SF Symbol for genre
            genreSymbol
                .font(.system(size: 70, weight: .bold))
                .foregroundColor(
                    colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.18)
                )
                .blur(radius: 0.5)
                .scaleEffect(1.3)
                .offset(x: 38, y: -18)
            // Genre name
            Text(genre.rawValue.capitalized)
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding([.leading, .bottom], 12)
                .shadow(color: .white.opacity(0.2), radius: 2)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
    }
    // Helper to get the genre's index for color cycling
    private var genreIndex: Int {
        UserGenre.allCases.firstIndex(of: genre) ?? 0
    }
    // SF Symbol for each genre
    private var genreSymbol: some View {
        let symbolName: String
        switch genre.rawValue.lowercased() {
        case "photographer": symbolName = "camera.aperture"
        case "videographer": symbolName = "video.fill"
        case "musician": symbolName = "music.note"
        case "painter": symbolName = "paintpalette.fill"
        case "writer": symbolName = "pencil.and.outline"
        case "singer": symbolName = "mic.fill"
        case "guitarist": symbolName = "guitars.fill"
        case "dancer": symbolName = "figure.dance"
        case "actor": symbolName = "theatermasks.fill"
        case "composer": symbolName = "music.quarternote.3"
        case "editor": symbolName = "scissors"
        case "drummer": symbolName = "music.mic"
        case "violinist": symbolName = "music.note.list"
        case "flutist": symbolName = "wind"
        case "sitarist": symbolName = "music.note.house"
        case "percussionist": symbolName = "metronome"
        case "vocalist": symbolName = "waveform"
        case "graphicdesigner": symbolName = "scribble.variable"
        case "director": symbolName = "film.fill"
        default: symbolName = "star.fill"
        }
        return Image(systemName: symbolName)
    }
}

#Preview {
    DiscoverView()
}
