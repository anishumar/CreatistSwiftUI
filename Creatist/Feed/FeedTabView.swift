import SwiftUI

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
    @StateObject private var viewModel = UserListViewModel()
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
                                    if nextCursor != nil, !isLoadingMore {
                                        loadMorePosts()
                                    }
                                }
                            )
                            .padding(.horizontal, 12)
                            NavigationLink(
                                destination: Group {
                                    if let post = selectedPost {
                                        VStack(spacing: 0) {
                                            List {
                                                PostCellView(post: post, viewModel: viewModel)
                                                    .listRowInsets(EdgeInsets())
                                                    .listRowSeparator(.hidden)
                                                    .listRowBackground(Color.clear)
                                                    .buttonStyle(PlainButtonStyle())
                                                let orderedPosts = [post] + posts.filter { $0.id != post.id }
                                                ForEach(orderedPosts, id: \.id) { trendingPost in
                                                    if trendingPost.id != post.id {
                                                        PostCellView(post: trendingPost, viewModel: viewModel)
                                                            .listRowInsets(EdgeInsets())
                                                            .listRowSeparator(.hidden)
                                                            .listRowBackground(Color.clear)
                                                            .buttonStyle(PlainButtonStyle())
                                                    }
                                                }
                                            }
                                            .listStyle(PlainListStyle())
                                            .scrollContentBackground(.hidden)
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
                                    PostCellView(post: post, viewModel: viewModel)
                                        .listRowInsets(EdgeInsets())
                                        .listRowSeparator(.hidden)
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
            .onAppear { 
                Task { 
                    await reloadPosts() 
                } 
            }
            .onChange(of: selectedSegment) { _ in 
                Task { 
                    await reloadPosts() 
                } 
            }
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
        
        let feedType: FeedType = selectedSegment == 0 ? .trending : .following
        
        // For following feed, always fetch fresh data when reloading
        // This ensures we get the latest posts after follow/unfollow actions
        if feedType == .following {
            posts = []
            await loadPosts(reset: true)
            isLoading = false
        } else if cacheManager.isCacheValid(for: feedType) {
            // For trending, use cache if valid
            posts = cacheManager.getCachedPosts(for: feedType)
            isLoading = false
        } else {
            posts = []
            await loadPosts(reset: true)
            isLoading = false
        }
    }

    func loadPosts(reset: Bool = false) async {
        let feedType: FeedType = selectedSegment == 0 ? .trending : .following
        
        let result: PaginatedPosts
        if selectedSegment == 0 {
            result = await Creatist.shared.fetchTrendingPosts(limit: pageSize, cursor: reset ? nil : nextCursor)
        } else {
            result = await Creatist.shared.fetchFollowingFeed(limit: pageSize, cursor: reset ? nil : nextCursor)
        }
        
        // Update posts and cache
        if reset {
            posts = result.posts
            // Only cache if we got posts
            if !result.posts.isEmpty {
                cacheManager.cachePosts(result.posts, for: feedType, append: false)
            }
        } else {
            posts.append(contentsOf: result.posts)
            if !result.posts.isEmpty {
                cacheManager.cachePosts(result.posts, for: feedType, append: true)
            }
        }
        nextCursor = result.nextCursor
        
        // If we're resetting and got no posts, clear error message (user might not be following anyone)
        if reset && result.posts.isEmpty {
            errorMessage = nil
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
