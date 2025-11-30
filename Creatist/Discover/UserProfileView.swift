import SwiftUI

struct UserProfileView: View {
    let userId: UUID
    @ObservedObject var viewModel: UserListViewModel
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var showDirectChat = false
    @State private var selectedSection = 0
    let sections = ["Projects", "Top Works"]
    @State private var userPosts: [PostWithDetails] = []
    @State private var isLoadingPosts = false
    @State private var selectedPost: PostWithDetails? = nil
    @State private var userCache: [UUID: User] = [:]

    @State private var fetchedUser: User? = nil
    @State private var isLoadingUser = false
    @State private var showFollowersSheet = false
    @State private var showFollowingSheet = false
    
    var user: User? {
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId }) ??
        fetchedUser
    }
    
    // Helper to update fetchedUser when follow status changes
    private func updateFetchedUserFollowStatus(_ isFollowing: Bool) {
        if var user = fetchedUser {
            user.isFollowing = isFollowing
            fetchedUser = user
        }
    }

    var body: some View {
        ZStack {
            backgroundView
            ScrollView {
                VStack(spacing: 16) {
                    if let user = user {
                        profileImageView(user: user)
                        usernameView(user: user)
                        statsView(user: user)
                        bioView(user: user)
                        infoRowsView(user: user)
                        actionButtonsView(user: user)
                        segmentedControlView
                        sectionContentView
                    } else if isLoadingUser {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView("Loading user profile...")
                                .font(.headline)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 16) {
                            Spacer()
                            Text("User not found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showDirectChat) {
            if let currentUser = Creatist.shared.user, let otherUser = user {
                let urlString = EnvironmentConfig.shared.wsURL(for: "/ws/message/\(otherUser.id.uuidString)?token=\(KeychainHelper.get("accessToken") ?? "")")
                if let url = URL(string: urlString) {
                    ChatView(
                        manager: ChatWebSocketManager(
                            url: url,
                            token: KeychainHelper.get("accessToken") ?? "",
                            userId: currentUser.id.uuidString,
                            isGroupChat: false,
                            otherUserId: otherUser.id.uuidString
                        ),
                        currentUserId: currentUser.id.uuidString,
                        title: "Chat with \(otherUser.name)"
                    )
                } else {
                    Text("Invalid chat URL")
                }
            } else {
                Text("User not logged in")
            }
        }
        .task {
            // Always refresh user data from backend to get latest follow status
            isLoadingUser = true
            
            // Fetch fresh user data from backend
            if let freshUser = await Creatist.shared.fetchUserById(userId: userId) {
                // Check if current user is following this user by fetching following list
                var updatedUser = freshUser
                if let currentUserId = Creatist.shared.user?.id.uuidString {
                    let followingList = await Creatist.shared.fetchFollowing(for: currentUserId)
                    updatedUser.isFollowing = followingList.contains { $0.id == userId }
                }
                
                await MainActor.run {
                    fetchedUser = updatedUser
                    isLoadingUser = false
                }
            } else {
                await MainActor.run {
                    isLoadingUser = false
                }
            }
            
            // Load user data if we have a user (use fetchedUser if available, otherwise use user from viewModel)
            let userToLoad = fetchedUser ?? user
            if let userToLoad = userToLoad {
                followersCount = await Creatist.shared.fetchFollowersCount(for: userToLoad.id.uuidString)
                followingCount = await Creatist.shared.fetchFollowingCount(for: userToLoad.id.uuidString)
                // Always load posts to get accurate count
                await loadUserPosts(for: userToLoad.id)
            }
        }
        .onChange(of: selectedSection) { newValue in
            // Posts are already loaded, no need to reload
        }
        .sheet(isPresented: $showFollowersSheet) {
            if let user = user {
                FollowersListView(userId: user.id.uuidString)
            } else {
                Text("User not available")
                    .padding()
            }
        }
        .sheet(isPresented: $showFollowingSheet) {
            if let user = user {
                FollowingListView(userId: user.id.uuidString)
            } else {
                Text("User not available")
                    .padding()
            }
        }
    }

    func loadUserPosts(for userId: UUID) async {
        // Check cache first and show immediately if available
        if let cachedPosts = CacheManager.shared.getCachedUserPosts(for: userId) {
            await MainActor.run {
                userPosts = cachedPosts
            }
        }
        
        // Set loading state
        await MainActor.run {
            isLoadingPosts = true
        }
        
        // Fetch fresh data
        let posts = await Creatist.shared.fetchUserPosts(userId: userId)
        await MainActor.run {
            userPosts = posts
            isLoadingPosts = false
        }
    }

    func fetchUser(userId: UUID, completion: @escaping (User?) -> Void) {
        if let cached = userCache[userId] {
            completion(cached)
            return
        }
        Task {
            if let user = await Creatist.shared.fetchUserById(userId: userId) {
                await MainActor.run {
                    userCache[userId] = user
                    completion(user)
                }
            } else {
                completion(nil)
            }
        }
    }
}

// Helper views
struct StatView: View {
    let number: Double
    let label: String
    var isDouble: Bool = false
    var body: some View {
        VStack {
            if isDouble {
                Text(String(format: "%.1f", number))
                    .font(.headline)
                    .foregroundColor(Color.primary)
            } else {
                Text("\(Int(number))")
                    .font(.headline)
                    .foregroundColor(Color.primary)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(Color.secondary)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Color.primary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color.secondary)
            Spacer()
        }
    }
}

// MARK: - View Components
extension UserProfileView {
    
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.accentColor.opacity(0.00), Color.accentColor.opacity(0.00)]),
            startPoint: .bottom,
            endPoint: .top
        )
        .ignoresSafeArea()
        .background(.ultraThinMaterial)
    }
    
    private func profileImageView(user: User) -> some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 110, height: 110)
            if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().aspectRatio(contentMode: .fill)
                            .foregroundColor(Color(.tertiaryLabel))
                    } else {
                        SkeletonView(width: 100, height: 100, cornerRadius: 50)
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }
    
    private func usernameView(user: User) -> some View {
        VStack(spacing: 4) {
            Text(user.name)
                .font(.title).bold()
                .foregroundColor(Color.primary)
                .padding(.top, 12)
                .padding(.horizontal, 24)
            if let username = user.username {
                Text("@\(username)")
                    .font(.subheadline)
                    .foregroundColor(Color.secondary)
                    .padding(.horizontal, 24)
            }
        }
    }
    
    private func statsView(user: User) -> some View {
        HStack(spacing: 24) {
            Button(action: { showFollowersSheet = true }) {
                StatView(number: Double(followersCount), label: "Followers")
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { showFollowingSheet = true }) {
                StatView(number: Double(followingCount), label: "Following")
            }
            .buttonStyle(PlainButtonStyle())
            
            StatView(number: Double(userPosts.count), label: "Projects")
            StatView(number: user.rating ?? 0, label: "Rating", isDouble: true)
        }
        .padding(.top, 8)
        .padding(.horizontal, 24)
    }
    
    private func bioView(user: User) -> some View {
        Group {
            if let desc = user.description, !desc.isEmpty {
                Text(desc)
                    .font(.body)
                    .foregroundColor(Color.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            } else {
                Text("Update your bio from Settings > Edit Profile")
                    .font(.body)
                    .foregroundColor(Color.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
    }
    
    private func infoRowsView(user: User) -> some View {
        VStack(spacing: 8) {
            if let city = user.city, let country = user.country {
                InfoRow(icon: "location", text: "\(city), \(country)")
            }
            if let workMode = user.workMode {
                InfoRow(icon: "globe", text: workMode.rawValue)
            }
            if let paymentMode = user.paymentMode {
                InfoRow(icon: paymentMode == .paid ? "creditcard.fill" : "gift.fill", text: paymentMode.rawValue.capitalized)
            }
            if let genres = user.genres, !genres.isEmpty {
                InfoRow(icon: "music.note.list", text: genres.map { $0.rawValue }.joined(separator: ", "))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.horizontal, 24)
        .multilineTextAlignment(.center)
    }
    
    private func actionButtonsView(user: User) -> some View {
        HStack(spacing: 24) {
            ProfileFollowButton(
                userId: user.id,
                viewModel: viewModel,
                providedUser: user,
                onFollowStatusChanged: { isFollowing in
                    updateFetchedUserFollowStatus(isFollowing)
                }
            )
            .frame(maxWidth: .infinity)
            Button(action: { showDirectChat = true }) {
                Text("Message")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                    )
                    .foregroundColor(.primary)
            }
            .disabled(false)
        }
        .frame(maxWidth: 340)
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
    
    private var segmentedControlView: some View {
        Picker("Section", selection: $selectedSection) {
            ForEach(0..<sections.count, id: \.self) { idx in
                Text(sections[idx])
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var sectionContentView: some View {
        Group {
            if selectedSection == 0 {
                projectsView
            } else {
                topWorksView
            }
        }
    }
    
    private var projectsView: some View {
        Group {
            if isLoadingPosts {
                UserProfileProjectsSkeleton()
            } else if userPosts.isEmpty {
                Text("No projects found.")
                    .foregroundColor(Color.secondary)
                    .padding()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(userPosts, id: \.id) { post in
                        Button(action: { selectedPost = post }) {
                            ZStack {
                                if let urlString = post.media.first?.url, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } else if phase.error != nil {
                                            Color(.systemGray4)
                                        } else {
                                            SkeletonView(cornerRadius: 12)
                                        }
                                    }
                                    .frame(height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    Color(.systemGray4).frame(height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let post = selectedPost {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                PostCellView(post: post)
                                    .padding(.bottom, 16)
                                let orderedPosts = [post] + userPosts.filter { $0.id != post.id }
                                ForEach(orderedPosts, id: \.id) { detailPost in
                                    if detailPost.id != post.id {
                                        PostCellView(post: detailPost)
                                            .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                        }
                    }
                },
                isActive: Binding(
                    get: { selectedPost != nil },
                    set: { if !$0 { selectedPost = nil } }
                )
            ) { EmptyView() }.hidden()
        )
    }
    
    private var topWorksView: some View {
        VStack {
            Text("Top Works")
                .foregroundColor(Color.secondary)
                .padding()
            // TODO: List top works here
        }
    }
} 
