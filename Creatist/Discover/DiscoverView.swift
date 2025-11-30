import SwiftUI

struct DiscoverView: View {
    @State private var searchText: String = ""
    @State private var searchResults: [User] = []
    @State private var isSearching: Bool = false
    @State private var followingUserIds: Set<UUID> = []
    @State private var hasLoadedFollowing: Bool = false
    @StateObject private var viewModel = UserListViewModel()
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
                if !searchText.isEmpty {
                    // Show search results
                    LazyVStack(spacing: 12) {
                        if isSearching {
                            ProgressView("Searching...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding()
                        } else if searchResults.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                    .foregroundColor(.secondary)
                                Text("No users found")
                                    .font(.title3).bold()
                                    .foregroundColor(.primary)
                                Text("Try searching with a different name")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        } else {
                            ForEach(searchResults, id: \.id) { user in
                                NavigationLink(destination: UserProfileView(userId: user.id, viewModel: viewModel)) {
                                    UserSearchResultRow(
                                        user: user,
                                        followingUserIds: $followingUserIds,
                                        onFollowStatusChanged: { isFollowing, userId in
                                            // Refresh from API after follow/unfollow to ensure consistency
                                            Task { @MainActor in
                                                await refreshFollowingList()
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    // Show genre grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredGenres, id: \.self) { genre in
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
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Editor, Composer and many more")
            .onChange(of: searchText) { newValue in
                if !newValue.isEmpty {
                    Task {
                        await performSearch(query: newValue)
                    }
                } else {
                    searchResults = []
                    isSearching = false
                }
            }
            .onAppear {
                // Refresh following list when view appears (e.g., when returning from profile view)
                // This ensures search results reflect the latest follow/unfollow status
                Task { @MainActor in
                    await refreshFollowingList()
                }
            }
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
    
    private func performSearch(query: String) async {
        guard !query.isEmpty else { return }
        
        print("🔍 DiscoverView: Starting search for '\(query)'")
        await MainActor.run {
            isSearching = true
        }
        searchResults = await Creatist.shared.searchUsers(query: query)
        print("🔍 DiscoverView: Search completed, found \(searchResults.count) users")
        
        // Always refresh following list when search results are loaded to ensure latest state
        await refreshFollowingList()
        
        await MainActor.run {
            isSearching = false
        }
    }
    
    @MainActor
    private func refreshFollowingList() async {
        guard let currentUserId = Creatist.shared.user?.id.uuidString else {
            return
        }
        
        print("🔄 DiscoverView: Refreshing following list from API...")
        let followingList = await Creatist.shared.fetchFollowing(for: currentUserId)
        let newFollowingIds = Set(followingList.map { $0.id })
        
        // Always assign new Set instance to ensure SwiftUI detects the change
        // This ensures the UI updates even if the contents are the same
        followingUserIds = newFollowingIds
        
        hasLoadedFollowing = true
    }
}

struct UserSearchResultRow: View {
    let user: User
    @Binding var followingUserIds: Set<UUID>
    let onFollowStatusChanged: (Bool, UUID) -> Void
    @State private var isLoadingFollow: Bool = false
    @State private var localIsFollowing: Bool = false
    
    private var isOwnProfile: Bool {
        user.id == Creatist.shared.user?.id
    }
    
    // Use local state that syncs with the binding
    private var isFollowing: Bool {
        localIsFollowing
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            if let url = user.profileImageUrl, let imgUrl = URL(string: url) {
                AsyncImage(url: imgUrl) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let rating = user.rating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(String(format: "%.1f", rating))
                                .foregroundColor(.primary)
                                .font(.caption)
                        }
                    }
                }
                
                if let genres = user.genres, !genres.isEmpty {
                    Text(genres.map { $0.rawValue.capitalized }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Location
                let locationText = [user.city, user.country].compactMap { $0 }.joined(separator: ", ")
                if !locationText.isEmpty {
                    Text(locationText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Follow button - only show if not own profile
            if !isOwnProfile {
                Button(action: {
                    Task { @MainActor in
                        isLoadingFollow = true
                        let wasFollowing = isFollowing
                        let newState = !wasFollowing
                        
                        // Update local state immediately for instant UI feedback
                        localIsFollowing = newState
                        
                        // Update the binding immediately for instant UI feedback
                        var updatedSet = followingUserIds
                        if wasFollowing {
                            updatedSet.remove(user.id)
                        } else {
                            updatedSet.insert(user.id)
                        }
                        followingUserIds = Set(updatedSet) // Force new instance
                        
                        // Call API
                        let success: Bool
                        if wasFollowing {
                            success = await Creatist.shared.unfollowUser(userId: user.id.uuidString)
                        } else {
                            success = await Creatist.shared.followUser(userId: user.id.uuidString)
                        }
                        
                        if success {
                            // Ensure local state matches the binding after API call
                            localIsFollowing = followingUserIds.contains(user.id)
                            // Notify parent to refresh from API to ensure consistency
                            onFollowStatusChanged(newState, user.id)
                        } else {
                            // Revert optimistic update on failure
                            localIsFollowing = wasFollowing
                            var revertedSet = followingUserIds
                            if wasFollowing {
                                revertedSet.insert(user.id)
                            } else {
                                revertedSet.remove(user.id)
                            }
                            followingUserIds = Set(revertedSet)
                        }
                        
                        isLoadingFollow = false
                    }
                }) {
                    Group {
                        if isLoadingFollow {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Text(isFollowing ? "Unfollow" : "Follow")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(isFollowing ? .secondary : .white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isFollowing ? Color(.systemGray5) : Color.accentColor)
                    )
                }
                .disabled(isLoadingFollow)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            // Initialize local state from binding
            localIsFollowing = followingUserIds.contains(user.id)
        }
        .onChange(of: followingUserIds.count) { _ in
            // Sync local state when followingUserIds changes (e.g., from API refresh or other actions)
            let newFollowingState = followingUserIds.contains(user.id)
            if newFollowingState != localIsFollowing {
                localIsFollowing = newFollowingState
            }
        }
        .task(id: followingUserIds.count) {
            // Also watch for Set changes using task modifier
            let newFollowingState = followingUserIds.contains(user.id)
            if newFollowingState != localIsFollowing {
                await MainActor.run {
                    localIsFollowing = newFollowingState
                }
            }
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
