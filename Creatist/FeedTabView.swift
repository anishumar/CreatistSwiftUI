import SwiftUI
import Foundation

struct FeedView: View {
    @State private var selectedSegment = 0
    @State private var posts: [PostWithDetails] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var nextCursor: String? = nil
    @State private var errorMessage: String? = nil
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text(post.caption ?? "No Caption").font(.headline)
                            // Add more post details here
                        }
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
} 