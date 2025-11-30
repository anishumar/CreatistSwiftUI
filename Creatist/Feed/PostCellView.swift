import SwiftUI
import AVKit

struct PostCellView: View {
    let post: PostWithDetails
    var onUpdate: ((PostWithDetails) -> Void)? = nil
    @StateObject private var cacheManager = CacheManager.shared
    @State private var author: User? = nil
    @State private var collaborators: [User] = []
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var showComments: Bool = false
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
                                let updatedPost = post.copy(likeCount: likeCount)
                                onUpdate?(updatedPost)
                            }
                        } else {
                            let success = await Creatist.shared.likePost(postId: post.id)
                            if success {
                                isLiked = true
                                likeCount += 1
                                let updatedPost = post.copy(likeCount: likeCount)
                                onUpdate?(updatedPost)
                            }
                        }
                    }
                }) {
                    Label("\(likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { 
                    showComments = true 
                }) {
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { 
                    showShareSheet = true 
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .font(.subheadline)
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
            CommentsSheetView(post: post, onUpdate: onUpdate)
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
        // Check cache first
        if let cachedUser = cacheManager.getUser(userId) {
            if post.userId == userId {
                author = cachedUser
            } else if post.isCollaborative && post.collaborators.contains(where: { $0.userId == userId }) {
                if !collaborators.contains(where: { $0.id == userId }) {
                    collaborators.append(cachedUser)
                }
            }
            return
        }
        
        // Fetch from network if not in cache
        Task {
            if let user = await Creatist.shared.fetchUserById(userId: userId) {
                await MainActor.run {
                    cacheManager.cacheUser(user)
                    if post.userId == userId {
                        author = user
                    } else if post.isCollaborative && post.collaborators.contains(where: { $0.userId == userId }) {
                        if !collaborators.contains(where: { $0.id == userId }) {
                            collaborators.append(user)
                        }
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

