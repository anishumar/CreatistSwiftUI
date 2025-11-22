import Foundation

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

