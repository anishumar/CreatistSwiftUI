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

    var user: User? {
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId })
    }

    var body: some View {
        ZStack {
            // Frosted glassy accent color gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color.accentColor.opacity(0.85), Color.clear]),
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
            .background(.ultraThinMaterial)

            ScrollView {
                VStack(spacing: 16) {
                    if let user = user {
                        // Profile image
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
                                        ProgressView()
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

                        // Username & handle
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

                        // Stats
                        HStack(spacing: 24) {
                            StatView(number: Double(followersCount), label: "Followers")
                            StatView(number: Double(followingCount), label: "Following")
                            StatView(number: 0, label: "Projects")
                            StatView(number: user.rating ?? 0, label: "Rating", isDouble: true)
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 24)

                        // Bio/description
                        if let desc = user.description, !desc.isEmpty {
                            Text(desc)
                                .font(.body)
                                .foregroundColor(Color.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                        } else {
                            Text(user.email)
                                .font(.body)
                                .foregroundColor(Color.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                        }

                        // Info rows
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

                        // Action buttons
                        HStack(spacing: 24) {
                            ProfileFollowButton(userId: user.id, viewModel: viewModel)
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
                        // Segmented control
                        Picker("Section", selection: $selectedSection) {
                            ForEach(0..<sections.count, id: \.self) { idx in
                                Text(sections[idx])
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        // Section content
                        if selectedSection == 0 {
                            if isLoadingPosts {
                                ProgressView().padding()
                            } else if userPosts.isEmpty {
                                Text("No projects found.")
                                    .foregroundColor(Color.secondary)
                                    .padding()
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
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
                                                            ProgressView()
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
                                .padding(.horizontal)
                            }
                            // Navigation to detail
                            NavigationLink(
                                destination: Group {
                                    if let post = selectedPost {
                                        PostCellView(post: post, userCache: .constant([:]), fetchUser: {_,_ in })
                                            .padding()
                                    }
                                },
                                isActive: Binding(
                                    get: { selectedPost != nil },
                                    set: { if !$0 { selectedPost = nil } }
                                )
                            ) { EmptyView() }.hidden()
                        } else {
                            // Top Works placeholder
                            VStack {
                                Text("Top Works")
                                    .foregroundColor(Color.secondary)
                                    .padding()
                                // TODO: List top works here
                            }
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showDirectChat) {
            if let currentUser = Creatist.shared.user, let otherUser = user {
                let urlString = "ws://localhost:8080/ws/message/\(otherUser.id.uuidString)?token=\(KeychainHelper.get("accessToken") ?? "")"
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
            if let user = user {
                followersCount = await Creatist.shared.fetchFollowersCount(for: user.id.uuidString)
                followingCount = await Creatist.shared.fetchFollowingCount(for: user.id.uuidString)
                if selectedSection == 0 {
                    await loadUserPosts(for: user.id)
                }
            }
        }
        .onChange(of: selectedSection) { newValue in
            if newValue == 0, let user = user {
                Task { await loadUserPosts(for: user.id) }
            }
        }
    }

    func loadUserPosts(for userId: UUID) async {
        isLoadingPosts = true
        let posts = await Creatist.shared.fetchUserPosts(userId: userId)
        await MainActor.run {
            userPosts = posts
            isLoadingPosts = false
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
