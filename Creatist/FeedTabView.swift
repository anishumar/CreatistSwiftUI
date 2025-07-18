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
    @State private var selectedPost: PostWithDetails? = nil
    let segments = ["Trending", "Following"]
    let pageSize = 10

    var body: some View {
        NavigationStack {
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
                    if selectedSegment == 0 {
                        ZStack {
                            TrendingCollectionView(posts: posts) { post in
                                selectedPost = post
                            }
                            .frame(height: 600)
                            .padding(.horizontal, 14)
                            NavigationLink(
                                destination: Group {
                                    if let post = selectedPost {
                                        ScrollView {
                                            VStack(alignment: .leading, spacing: 24) {
                                                // Selected post detail at the top
                                                PostCellView(post: post, userCache: $userCache, fetchUser: fetchUser)
                                                    .padding(.bottom, 16)
                                                // All trending posts below, with the selected post first, then the rest
                                                let orderedPosts = [post] + posts.filter { $0.id != post.id }
                                                ForEach(orderedPosts, id: \.id) { trendingPost in
                                                    if trendingPost.id != post.id {
                                                        PostCellView(post: trendingPost, userCache: $userCache, fetchUser: fetchUser)
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
            }
            .onAppear { Task { await reloadPosts() } }
            .onChange(of: selectedSegment) { _ in Task { await reloadPosts() } }
            .navigationTitle("Feed")
        }
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
            if post.isCollaborative, !post.collaborators.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: -6) {
                        ForEach(post.collaborators, id: \.userId) { collaborator in
                            if let user = userCache[collaborator.userId] {
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
                                    .onAppear { fetchUser(collaborator.userId) { _ in } }
                            }
                        }
                    }
                    // Names together
                    let names = post.collaborators.compactMap { userCache[$0.userId]?.name }.joined(separator: ", ")
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
                            .onAppear { fetchUser(post.userId) { _ in } }
                    }
                }
            }
            // 2. Media
            if let media = post.media.sorted(by: { $0.order < $1.order }).first {
                AsyncImage(url: URL(string: media.url)) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                            )
                    } else if phase.error != nil {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                            )
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                            .frame(height: 220)
                    }
                }
                .frame(height: 220)
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