import SwiftUI

struct CommentsSheetView: View {
    let post: PostWithDetails
    var onUpdate: ((PostWithDetails) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cacheManager = CacheManager.shared
    @State private var comments: [PostComment] = []
    @State private var newComment: String = ""
    @State private var isLoadingComments: Bool = false
    @State private var isAddingComment: Bool = false
    @State private var isLoadingMoreComments = false
    @State private var hasMoreComments = true
    @State private var commentsOffset: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoadingComments {
                    VStack {
                        Spacer()
                        ProgressView("Loading comments...")
                            .padding()
                        Spacer()
                    }
                } else if comments.isEmpty && !hasMoreComments {
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
                    if let currentUser = Creatist.shared.user, 
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
                        isAddingComment = true
                        Task {
                            if let added = await Creatist.shared.addComment(postId: post.id, content: newComment) {
                                await MainActor.run {
                                    comments.insert(added, at: 0)
                                    newComment = ""
                                    
                                    // Update parent with new comment count
                                    let newCount = post.commentCount + 1
                                    let updatedPost = post.copy(commentCount: newCount)
                                    onUpdate?(updatedPost)
                                }
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
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if comments.isEmpty {
                    isLoadingComments = true
                    Task {
                        await loadComments(reset: true)
                    }
                }
            }
        }
    }
    
    private func loadComments(reset: Bool = false) async {
        // Get current offset on main actor
        let currentOffset = await MainActor.run {
            if reset {
                comments = []
                commentsOffset = 0
                hasMoreComments = true
                return 0
            } else {
                return commentsOffset
            }
        }
        
        let fetchedComments = await Creatist.shared.getCommentsWithOffset(postId: post.id, limit: 10, offset: currentOffset)
        
        await MainActor.run {
            if reset {
                comments = fetchedComments
            } else {
                comments.append(contentsOf: fetchedComments)
            }
            
            // Update offset for next load
            commentsOffset += fetchedComments.count
            
            // If we got fewer comments than the limit, we've reached the end
            hasMoreComments = fetchedComments.count >= 10
            isLoadingComments = false
            isLoadingMoreComments = false
        }
    }
    
    private func loadMoreComments() {
        guard !isLoadingMoreComments && hasMoreComments else { return }
        isLoadingMoreComments = true
        Task {
            await loadComments()
        }
    }
}

