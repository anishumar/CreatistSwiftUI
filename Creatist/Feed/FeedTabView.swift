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

                // Feed Content
                if selectedSegment == 0 {
                    // Trending Feed (Grid)
                    if let post = selectedPost {
                        // Detail View for Selected Post
                        ScrollView {
                            VStack(spacing: 0) {
                                // Selected Post
                                PostCellView(post: post, onUpdate: handlePostUpdate)
                                    .padding(.horizontal)
                                
                                Divider().padding(.vertical)
                                
                                // More posts
                                LazyVStack(spacing: 20) {
                                    Text("More Trending")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                    
                                    let orderedPosts = [post] + posts.filter { $0.id != post.id }
                                    ForEach(orderedPosts, id: \.id) { trendingPost in
                                        if trendingPost.id != post.id {
                                            PostCellView(post: trendingPost, onUpdate: handlePostUpdate)
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .transition(.move(edge: .trailing))
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: {
                                    withAnimation {
                                        selectedPost = nil
                                    }
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    } else {
                        // Grid View
                        TrendingCollectionView(
                            posts: posts,
                            onPostSelected: { post in
                                withAnimation {
                                    selectedPost = post
                                }
                            },
                            onLoadMore: {
                                loadMorePosts()
                            }
                        )
                    }
                } else {
                    // Following Feed (List)
                    List {
                        ForEach(posts, id: \.id) { post in
                            PostCellView(post: post, onUpdate: handlePostUpdate)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                        }
                        
                        if isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                        } else {
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    loadMorePosts()
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await refreshFeed()
                    }
                }
            }
        }
    }
    .navigationTitle(selectedPost == nil ? "Feed" : "Post")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        if selectedPost == nil {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ChatListView()) {
                    Image(systemName: "message")
                        .foregroundColor(.primary)
                }
            }
        }
    }
    .onAppear {
        if posts.isEmpty {
            Task {
                await refreshFeed()
            }
        }
    }
    .onChange(of: selectedSegment) { _ in Task { await refreshFeed() } }
}
    
    private func handlePostUpdate(_ updatedPost: PostWithDetails) {
        print("🔄 handlePostUpdate called for post: \(updatedPost.id)")
        print("   Updated comment count: \(updatedPost.commentCount)")
        print("   Updated like count: \(updatedPost.likeCount)")
        
        // Update posts array
        if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
            print("   Found post at index \(index), updating...")
            print("   Old comment count: \(posts[index].commentCount)")
            posts[index] = updatedPost
            print("   New comment count: \(posts[index].commentCount)")
        } else {
            print("   ⚠️ Post not found in posts array!")
        }
        
        // Update selectedPost if it matches
        if selectedPost?.id == updatedPost.id {
            print("   Updating selectedPost as well")
            selectedPost = updatedPost
        }
    }

    func refreshFeed() async {
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
    var onUpdate: ((PostWithDetails) -> Void)? = nil
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
    @State private var isLoadingMoreComments = false
    @State private var hasMoreComments = true
    @State private var commentsCursor: String? = nil

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
                                // Update parent
                                let updatedPost = post.copy(likeCount: likeCount)
                                onUpdate?(updatedPost)
                            }
                        } else {
                            let success = await Creatist.shared.likePost(postId: post.id)
                            if success {
                                isLiked = true
                                likeCount += 1
                                // Update parent
                                let updatedPost = post.copy(likeCount: likeCount)
                                onUpdate?(updatedPost)
                            }
                        }
                    }
                }) {
                    Label("\(likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .primary)
                }
                Button(action: { showComments = true }) {
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                        .foregroundColor(.primary)
                }
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.primary)
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
            // Check if we have comments loaded in cache or if we need to trust the post count
            // We don't auto-load comments here to save bandwidth, but we respect the post.commentCount
        }
        .sheet(isPresented: $showComments) {
            NavigationView {
                VStack(spacing: 0) {
                    if isLoadingComments {
                        VStack {
                            Spacer()
                            ProgressView("Loading comments...")
                                .padding()
                            Spacer()
                        }
                    } else if comments.isEmpty && !hasMoreComments { // Only show "No comments" if we've loaded all and there are none
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No comments yet")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Be the first to comment")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(comments, id: \.id) { comment in
                                    CommentRowView(comment: comment, cacheManager: cacheManager)
                                }

                                if hasMoreComments {
                                    if isLoadingMoreComments {
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                    } else {
                                        Button(action: {
                                            loadMoreComments()
                                        }) {
                                            Text("Load more comments")
                                                .font(.subheadline)
                                                .foregroundColor(.accentColor)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    
                    // Comment input section
                    Divider()
                    HStack(spacing: 12) {
                        // Current user's profile picture
                        if let currentUser = cacheManager.currentUser, 
                           let profileUrl = currentUser.profileImageUrl,
                           let url = URL(string: profileUrl) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.gray)
                        }
                        
                        TextField("Add a comment...", text: $newComment, axis: .vertical)
                            .lineLimit(1...4)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        
                        Button(action: {
                            guard !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            print("💬 Adding comment to post: \(post.id)")
                            print("   Comment text: \(newComment)")
                            isAddingComment = true
                            Task {
                                if let added = await Creatist.shared.addComment(postId: post.id, content: newComment) {
                                    print("✅ Comment added successfully: \(added.id)")
                                    await MainActor.run {
                                        comments.insert(added, at: 0)
                                        newComment = ""
                                        print("   Current comment count in list: \(comments.count)")
                                        print("   Post comment count before update: \(post.commentCount)")
                                        
                                        // Update parent with new comment count
                                        let newCount = post.commentCount + 1
                                        print("   New comment count: \(newCount)")
                                        let updatedPost = post.copy(commentCount: newCount)
                                        print("   Calling onUpdate with count: \(updatedPost.commentCount)")
                                        onUpdate?(updatedPost)
                                    }
                                } else {
                                    print("❌ Failed to add comment")
                                }
                                await MainActor.run {
                                    isAddingComment = false
                                }
                            }
                        }) {
                            if isAddingComment {
                                ProgressView()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                            }
                        }
                        .disabled(isAddingComment || newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))
                }
                .navigationTitle("Comments")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showComments = false }
                    }
                }
                .onAppear {
                    if comments.isEmpty { // Only load if comments are not already loaded
                        isLoadingComments = true
                        Task {
                            await loadComments(reset: true)
                        }
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
    
    private func loadComments(reset: Bool = false) async {
        print("📥 loadComments(reset: \(reset)) for post: \(post.id)")
        if reset {
            commentsCursor = nil
            hasMoreComments = true
            await MainActor.run {
                comments = []
            }
        }
        
        // SAFETY: Only load first page since backend doesn't support pagination
        // Backend returns same 10 comments regardless of offset/cursor
        print("   Loading first 10 comments only (backend doesn't support pagination)")
        let fetchedComments = await Creatist.shared.getCommentsWithOffset(postId: post.id, limit: 10, offset: 0)
        print("   Fetched: \(fetchedComments.count) comments")
        
        await MainActor.run {
            comments = fetchedComments
            commentsCursor = nil
            hasMoreComments = false
            isLoadingComments = false
            isLoadingMoreComments = false
            print("✅ Loaded \(comments.count) comments (backend limitation)")
        }
    }
    
    private func loadMoreComments() {
        guard !isLoadingMoreComments && hasMoreComments else { return }
        isLoadingMoreComments = true
        Task {
            await loadComments()
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

// CommentRowView - Instagram-style comment with profile picture
struct CommentRowView: View {
    let comment: PostComment
    @ObservedObject var cacheManager: CacheManager
    @State private var commentAuthor: User? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User profile picture
            if let user = commentAuthor {
                if let profileUrl = user.profileImageUrl, let url = URL(string: profileUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else if phase.error != nil {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .foregroundColor(.gray)
                        } else {
                            ProgressView()
                                .frame(width: 32, height: 32)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .padding(.top, 4) // Align with text top
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.gray)
                        .padding(.top, 4) // Align with text top
                }
            } else {
                // Placeholder while loading
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
                    .padding(.top, 4) // Align with text top
                    .onAppear {
                        fetchCommentAuthor()
                    }
            }
            
            // Comment content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let user = commentAuthor {
                        Text(user.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("Loading...")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(comment.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(comment.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func fetchCommentAuthor() {
        // Check cache first
        if let cachedUser = cacheManager.getUser(comment.userId) {
            commentAuthor = cachedUser
            return
        }
        
        // Fetch from network if not in cache
        Task {
            if let user = await Creatist.shared.fetchUserById(userId: comment.userId) {
                await MainActor.run {
                    cacheManager.cacheUser(user)
                    commentAuthor = user
                }
            }
        }
    }
}

// Add ChatListView at the end of the file
struct ChatListView: View {
    @State private var searchText: String = ""
    @State private var showNewChat = false
    // Add dummy data to make search bar visible
    let chats: [(id: UUID, name: String, lastMessage: String, unread: Int)] = [
        (UUID(), "John Doe", "Hey, how are you?", 2),
        (UUID(), "Jane Smith", "Thanks for the help!", 0),
        (UUID(), "Mike Johnson", "See you tomorrow", 1)
    ]
    var filteredChats: [(id: UUID, name: String, lastMessage: String, unread: Int)] {
        if searchText.isEmpty { return chats }
        return chats.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.lastMessage.localizedCaseInsensitiveContains(searchText) }
    }
    var body: some View {
        NavigationStack {
            if filteredChats.isEmpty {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .searchable(text: $searchText, prompt: "Search chats")
            }
        }
        .navigationTitle("Chats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showNewChat = true }) {
                    Image(systemName: "plus")
                }
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

extension PostWithDetails {
    func copy(likeCount: Int? = nil, commentCount: Int? = nil) -> PostWithDetails {
        return PostWithDetails(
            id: self.id,
            userId: self.userId,
            caption: self.caption,
            isCollaborative: self.isCollaborative,
            status: self.status,
            visibility: self.visibility,
            sharedFromPostId: self.sharedFromPostId,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            deletedAt: self.deletedAt,
            media: self.media,
            tags: self.tags,
            collaborators: self.collaborators,
            likeCount: likeCount ?? self.likeCount,
            commentCount: commentCount ?? self.commentCount,
            viewCount: self.viewCount,
            authorName: self.authorName,
            topComments: self.topComments
        )
    }
}
