import SwiftUI
import Foundation

struct FeedView: View {
    @State private var selectedSegment = 0
    @State private var posts: [PostWithDetails] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var nextCursor: String? = nil
    @State private var errorMessage: String? = nil
    @State private var userCache: [UUID: User] = [:]
    let segments = ["Trending", "Following"]
    let pageSize = 10

    var body: some View {
        VStack {
            Picker("Feed Type", selection: $selectedSegment) {
                ForEach(0..<segments.count, id: \.self) { idx in
                    Text(segments[idx])
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            if isLoading && posts.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red)
            } else {
                List {
                    ForEach(posts, id: \.id) { post in
                        PostCellView(
                            post: post,
                            userCache: $userCache,
                            fetchUser: fetchUser
                        )
                        .onAppear {
                            checkIfShouldLoadMore(post: post)
                        }
                    }
                    if isLoadingMore {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable { await reloadPosts() }
            }
        }
        .onAppear { Task { await reloadPosts() } }
        .onChange(of: selectedSegment) { _ in Task { await reloadPosts() } }
    }

    func reloadPosts() async {
        isLoading = true
        isLoadingMore = false
        errorMessage = nil
        nextCursor = nil
        posts = []
        await loadPosts(reset: true)
        isLoading = false
    }

    func loadPosts(reset: Bool = false) async {
        do {
            let result: PaginatedPosts
            if selectedSegment == 0 {
                result = await Creatist.shared.fetchTrendingPosts(limit: pageSize, cursor: reset ? nil : nextCursor)
            } else {
                result = await Creatist.shared.fetchFollowingFeed(limit: pageSize, cursor: reset ? nil : nextCursor)
            }
            if reset {
                posts = result.posts
            } else {
                posts.append(contentsOf: result.posts)
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

struct PostCellView: View {
    let post: PostWithDetails
    @Binding var userCache: [UUID: User]
    var fetchUser: (UUID, @escaping (User?) -> Void) -> Void
    @State private var author: User? = nil
    @State private var collaborators: [User] = []
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var showComments: Bool = false
    @State private var comments: [PostComment] = []
    @State private var newComment: String = ""
    @State private var isLoadingComments: Bool = false
    @State private var isAddingComment: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. User image(s) and name(s)
            HStack(spacing: 12) {
                if post.isCollaborative, !post.collaborators.isEmpty {
                    ForEach(post.collaborators, id: \ .userId) { collaborator in
                        if let user = userCache[collaborator.userId] {
                            UserImageAndName(user: user)
                        } else {
                            Color.gray.frame(width: 36, height: 36).clipShape(Circle())
                                .onAppear { fetchUser(collaborator.userId) { _ in } }
                        }
                    }
                } else {
                    if let user = author {
                        UserImageAndName(user: user)
                    } else {
                        Color.gray.frame(width: 36, height: 36).clipShape(Circle())
                            .onAppear { fetchUser(post.userId) { _ in } }
                    }
                }
            }
            // 2. Media
            if let media = post.media.sorted(by: { $0.order < $1.order }).first {
                AsyncImage(url: URL(string: media.url)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "photo").resizable().aspectRatio(contentMode: .fit).foregroundColor(.gray)
                    } else {
                        ProgressView()
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                Button(action: { /* Share action */ }) {
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
                HStack(spacing: 8) {
                    ForEach(post.tags, id: \ .self) { tag in
                        Text("#\(tag)").font(.caption).foregroundColor(.accentColor)
                    }
                }
            }
            // 7. Time
            Text(post.createdAt, style: .relative).font(.caption).foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .onAppear {
            if author == nil {
                fetchUser(post.userId) { user in
                    self.author = user
                }
            }
            if post.isCollaborative && collaborators.isEmpty {
                let ids = post.collaborators.map { $0.userId }
                for id in ids {
                    fetchUser(id) { user in
                        if let user = user, !collaborators.contains(where: { $0.id == user.id }) {
                            collaborators.append(user)
                        }
                    }
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
                        List(comments, id: \ .id) { comment in
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