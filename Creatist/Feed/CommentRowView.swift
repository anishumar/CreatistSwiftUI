import SwiftUI

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
                    .padding(.top, 4)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.gray)
                        .padding(.top, 4)
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
                    .padding(.top, 4)
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

