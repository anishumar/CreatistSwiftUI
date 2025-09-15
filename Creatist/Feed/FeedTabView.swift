import SwiftUI
import Foundation
import AVKit

struct FeedView: View {
    @State private var selectedSegment = 0
    @State private var posts: [PostWithDetails] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var nextCursor: String? = nil
    @State private var errorMessage: String? = nil
    @State private var selectedPost: PostWithDetails? = nil
    @State private var showChatList = false
    @StateObject private var cacheManager = CacheManager.shared
    let segments = ["Trending", "Following"]
    let pageSize = 20

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Always show title and segment control
                VStack(alignment: .leading, spacing: 10) {
                    Text("Feed")
                        .font(.largeTitle).bold()
                        .padding(.horizontal, 18)
                    Picker("Feed Type", selection: $selectedSegment) {
                        ForEach(0..<segments.count, id: \.self) { idx in
                            Text(segments[idx])
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 0)
                }
                .padding(.top, 18)
                .padding(.bottom, 4)
                if isLoading && posts.isEmpty {
                    if selectedSegment == 0 {
                        TrendingCollectionSkeletonView()
                            .padding(.horizontal, 12)
                    } else {
                        FeedLoadingView(isTrending: false)
                    }
                } else if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                } else {
                    if selectedSegment == 0 {
                        VStack(spacing: 0) {
                            TrendingCollectionView(
                                posts: posts, 
                                onPostSelected: { post in
                                    selectedPost = post
                                },
                                onLoadMore: {
                                    // Check if we need to load more posts for trending
                                    if nextCursor != nil, !isLoadingMore {
                                        loadMorePosts()
                                    }
                                }
                            )
                            .padding(.horizontal, 12)
                            NavigationLink(
                                destination: Group {
                                    if let post = selectedPost {
                                        ScrollView {
                                            VStack(alignment: .leading, spacing: 24) {
                                                // Selected post detail at the top
                                                PostCellView(post: post)
                                                    .padding(.bottom, 16)
                                                // All trending posts below, with the selected post first, then the rest
                                                let orderedPosts = [post] + posts.filter { $0.id != post.id }
                                                ForEach(orderedPosts, id: \.id) { trendingPost in
                                                    if trendingPost.id != post.id {
                                                        PostCellView(post: trendingPost)
                                                            .padding(.vertical, 8)
                                                    }
                                                }
                                            }
                                            .padding()
                                        }
                                    }
                                },
                                isActive: Binding(
                                    get: { selectedPost != nil },
                                    set: { if !$0 { selectedPost = nil } }
                                )
                            ) { EmptyView() }
                            .hidden()
                        }
                        .padding(.top, 8)
                    } else {
                        VStack(spacing: 0) {
                            List {
                                ForEach(posts, id: \.id) { post in
                                    PostCellView(post: post)
                                    .onAppear {
                                        checkIfShouldLoadMore(post: post)
                                    }
                                }
                                if isLoadingMore {
                                    HStack { Spacer(); 
                                        SkeletonView(width: 20, height: 20, cornerRadius: 10)
                                        Spacer() 
                                    }
                                }
                            }
                            .listStyle(PlainListStyle())
                            .refreshable { await reloadPosts() }
                        }
                        .padding(.horizontal, 2)
                        .padding(.top, 8)
                    }
                }
            }
            .onAppear { Task { await reloadPosts() } }
            .onChange(of: selectedSegment) { _ in Task { await reloadPosts() } }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showChatList = true }) {
                        Image(systemName: "message")
                    }
                }
            }
            .navigationDestination(isPresented: $showChatList) {
                ChatListView()
            }
        }
    }

    func reloadPosts() async {
        isLoading = true
        isLoadingMore = false
        errorMessage = nil
        nextCursor = nil
        
        // Try to load from cache first
        let feedType: FeedType = selectedSegment == 0 ? .trending : .following
        if cacheManager.isCacheValid(for: feedType) {
            posts = cacheManager.getCachedPosts(for: feedType)
            isLoading = false
        } else {
            posts = []
            await loadPosts(reset: true)
            isLoading = false
        }
    }

    func loadPosts(reset: Bool = false) async {
        do {
            let result: PaginatedPosts
            let feedType: FeedType = selectedSegment == 0 ? .trending : .following
            
            if selectedSegment == 0 {
                result = await Creatist.shared.fetchTrendingPosts(limit: pageSize, cursor: reset ? nil : nextCursor)
            } else {
                result = await Creatist.shared.fetchFollowingFeed(limit: pageSize, cursor: reset ? nil : nextCursor)
            }
            
            if reset {
                posts = result.posts
                cacheManager.cachePosts(result.posts, for: feedType, append: false)
            } else {
                posts.append(contentsOf: result.posts)
                cacheManager.cachePosts(result.posts, for: feedType, append: true)
            }
            nextCursor = result.nextCursor
        } catch {
            errorMessage = "Failed to load posts."
        }
    }

    func loadMorePosts() {
        guard !isLoadingMore, let _ = nextCursor else { return }
        isLoadingMore = true
        Task {
            await loadPosts()
            isLoadingMore = false
        }
    }

    func checkIfShouldLoadMore(post: PostWithDetails) {
        if post.id == posts.last?.id, nextCursor != nil, !isLoadingMore {
            loadMorePosts()
        }
    }

}

struct PostCellView: View {
    let post: PostWithDetails
    @StateObject private var cacheManager = CacheManager.shared
    @State private var author: User? = nil
    @State private var collaborators: [User] = []
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var showComments: Bool = false
    @State private var comments: [PostComment] = []
    @State private var newComment: String = ""
    @State private var isLoadingComments: Bool = false
    @State private var isAddingComment: Bool = false
    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. User image(s) and name(s)
            if post.isCollaborative, !post.collaborators.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: -6) {
                        ForEach(post.collaborators, id: \.userId) { collaborator in
                            if let user = cacheManager.getUser(collaborator.userId) {
                                if let url = user.profileImageUrl, let imgUrl = URL(string: url) {
                                    AsyncImage(url: imgUrl) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else if phase.error != nil {
                                            Image(systemName: "person.crop.circle.fill").resizable().scaledToFill().foregroundColor(.gray)
                                        } else {
                                            ProgressView().frame(width: 36, height: 36)
                                        }
                                    }
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                } else {
                                    Image(systemName: "person.crop.circle.fill").resizable().scaledToFill().frame(width: 36, height: 36).clipShape(Circle()).foregroundColor(.gray)
                                }
                            } else {
                                Color.gray.frame(width: 36, height: 36).clipShape(Circle())
                                    .onAppear { fetchUser(collaborator.userId) }
                            }
                        }
                    }
                    // Names together
                    let names = post.collaborators.compactMap { cacheManager.getUser($0.userId)?.name }.joined(separator: ", ")
                    if !names.isEmpty {
                        Text(names)
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    if let user = author {
                        UserImageAndName(user: user)
                    } else {
                        Color.gray.frame(width: 36, height: 36).clipShape(Circle())
                            .onAppear { fetchUser(post.userId) }
                    }
                }
            }
            // 2. Media
            if let media = post.media.sorted(by: { $0.order < $1.order }).first {
                if media.url.lowercased().hasSuffix(".mp4") || media.type == "video" {
                    if let url = URL(string: media.url) {
                        VideoPlayer(player: AVPlayer(url: url))
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    AsyncImage(url: URL(string: media.url)) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: 320)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if phase.error != nil {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: 320)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(.gray)
                        } else {
                            ProgressView()
                                .frame(height: 320)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 320)
                }
            }
            // 3. Like, comment, share buttons
            HStack(spacing: 24) {
                Button(action: {
                    Task {
                        if isLiked {
                            let success = await Creatist.shared.unlikePost(postId: post.id)
                            if success {
                                isLiked = false
                                likeCount = max(0, likeCount - 1)
                            }
                        } else {
                            let success = await Creatist.shared.likePost(postId: post.id)
                            if success {
                                isLiked = true
                                likeCount += 1
                            }
                        }
                    }
                }) {
                    Label("\(likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .primary)
                }
                Button(action: { showComments = true }) {
                    Label("\(comments.count > 0 ? comments.count : post.commentCount)", systemImage: "bubble.right")
                }
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }.font(.subheadline)
            // 4. Title
            if let caption = post.caption {
                Text(caption).font(.headline)
            }
            // 5. Description (if available)
            if let desc = post.topComments.first?.content, !desc.isEmpty {
                Text(desc).font(.subheadline).foregroundColor(.secondary)
            }
            // 6. Tags
            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.tags, id: \.self) { tag in
                            Text("#\(tag)").font(.caption).foregroundColor(.accentColor)
                        }
                    }
                }
            }
            // 7. Time
            Text(post.createdAt, style: .relative).font(.caption).foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .onAppear {
            // Try to get author from cache first
            if let cachedAuthor = cacheManager.getUser(post.userId) {
                author = cachedAuthor
            } else if author == nil {
                fetchUser(post.userId)
            }
            
            // Try to get collaborators from cache first
            if post.isCollaborative && !post.collaborators.isEmpty {
                let cachedCollaborators = post.collaborators.compactMap { collaborator in
                    cacheManager.getUser(collaborator.userId)
                }
                if !cachedCollaborators.isEmpty {
                    collaborators = cachedCollaborators
                }
                
                // Fetch any missing collaborators
                let missingIds = post.collaborators.filter { collaborator in
                    !collaborators.contains { $0.id == collaborator.userId }
                }.map { $0.userId }
                
                for id in missingIds {
                    fetchUser(id)
                }
            }
            // Initialize like state
            likeCount = post.likeCount
        }
        .sheet(isPresented: $showComments) {
            NavigationView {
                VStack {
                    if isLoadingComments {
                        ProgressView("Loading comments...")
                    } else {
                        List(comments, id: \.id) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comment.content).font(.body)
                                Text(comment.createdAt, style: .relative).font(.caption).foregroundColor(.gray)
                            }
                        }
                    }
                    HStack {
                        TextField("Add a comment...", text: $newComment)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Send") {
                            guard !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            isAddingComment = true
                            Task {
                                if let added = await Creatist.shared.addComment(postId: post.id, content: newComment) {
                                    comments.insert(added, at: 0)
                                    newComment = ""
                                }
                                isAddingComment = false
                            }
                        }.disabled(isAddingComment || newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }.padding()
                }
                .navigationTitle("Comments")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showComments = false }
                    }
                }
                .onAppear {
                    isLoadingComments = true
                    Task {
                        comments = await Creatist.shared.getComments(postId: post.id)
                        isLoadingComments = false
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let media = post.media.sorted(by: { $0.order < $1.order }).first, let url = URL(string: media.url) {
                ShareSheet(activityItems: [url])
            } else {
                ShareSheet(activityItems: ["Check out this post on Creatist!"])
            }
        }
    }
    
    func fetchUser(_ userId: UUID) {
        print("🔍 Fetching user: \(userId)")
        
        // Check cache first
        if let cachedUser = cacheManager.getUser(userId) {
            print("✅ Found user in cache: \(cachedUser.name)")
            if post.userId == userId {
                author = cachedUser
                print("✅ Set author: \(cachedUser.name)")
            } else if post.isCollaborative && post.collaborators.contains(where: { $0.userId == userId }) {
                if !collaborators.contains(where: { $0.id == userId }) {
                    collaborators.append(cachedUser)
                    print("✅ Added collaborator: \(cachedUser.name)")
                }
            }
            return
        }
        
        print("🌐 User not in cache, fetching from network...")
        // Fetch from network if not in cache
        Task {
            if let user = await Creatist.shared.fetchUserById(userId: userId) {
                print("✅ Fetched user from network: \(user.name), profileImageUrl: \(user.profileImageUrl ?? "nil")")
                await MainActor.run {
                    cacheManager.cacheUser(user)
                    if post.userId == userId {
                        author = user
                        print("✅ Set author from network: \(user.name)")
                    } else if post.isCollaborative && post.collaborators.contains(where: { $0.userId == userId }) {
                        if !collaborators.contains(where: { $0.id == userId }) {
                            collaborators.append(user)
                            print("✅ Added collaborator from network: \(user.name)")
                        }
                    }
                }
            } else {
                print("❌ Failed to fetch user: \(userId)")
            }
        }
    }
}

struct UserImageAndName: View {
    let user: User
    var body: some View {
        HStack(spacing: 8) {
            if let url = user.profileImageUrl, let imgUrl = URL(string: url) {
                AsyncImage(url: imgUrl) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "person.crop.circle.fill").resizable().aspectRatio(contentMode: .fill).foregroundColor(.gray)
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().aspectRatio(contentMode: .fill).frame(width: 36, height: 36).foregroundColor(.gray)
            }
            Text(user.name).font(.subheadline).bold()
        }
    }
}

// Helper for share sheet
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Add ChatListView at the end of the file
struct ChatListView: View {
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var showNewChat = false
    // Remove dummy chats, use an empty array for now
    let chats: [(id: UUID, name: String, lastMessage: String, unread: Int)] = []
    var filteredChats: [(id: UUID, name: String, lastMessage: String, unread: Int)] {
        if searchText.isEmpty { return chats }
        return chats.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.lastMessage.localizedCaseInsensitiveContains(searchText) }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chats")
                    .font(.largeTitle).bold()
                Spacer()
                Button(action: { showNewChat = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .padding(8)
                        .background(Circle().fill(Color.accentColor))
                        .foregroundColor(.white)
                }
            }
            .padding([.top, .horizontal])
            // Native search bar
            SearchBar(text: $searchText, isEditing: $isSearching)
                .padding(.horizontal)
                .padding(.bottom, 4)
            Divider()
            if filteredChats.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.secondary)
                    Text("No chats yet")
                        .font(.title3).bold()
                        .foregroundColor(.primary)
                    Text("Start a new chat to connect with someone!")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(filteredChats, id: \ .id) { chat in
                        HStack {
                            Circle().fill(Color(.systemGray4)).frame(width: 44, height: 44)
                            VStack(alignment: .leading) {
                                Text(chat.name).font(.headline)
                                Text(chat.lastMessage).font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            if chat.unread > 0 {
                                Text("\(chat.unread)")
                                    .font(.caption).bold()
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Circle().fill(Color.green))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $showNewChat) {
            NavigationView {
                VStack {
                    Text("Start a new chat")
                        .font(.title2)
                        .padding()
                    Spacer()
                    Button("Close") { showNewChat = false }
                        .padding()
                }
                .navigationTitle("New Chat")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// UIKit native search bar wrapper
import UIKit
struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    @Binding var isEditing: Bool
    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        @Binding var isEditing: Bool
        init(text: Binding<String>, isEditing: Binding<Bool>) {
            _text = text
            _isEditing = isEditing
        }
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            isEditing = true
        }
        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            isEditing = false
        }
        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
            isEditing = false
            text = ""
        }
    }
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, isEditing: $isEditing)
    }
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = "Search"
        searchBar.showsCancelButton = true
        searchBar.autocapitalizationType = .none
        return searchBar
    }
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
        uiView.showsCancelButton = isEditing
    }
} 