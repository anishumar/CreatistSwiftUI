import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: String
    let senderId: String
    let receiverId: String?
    let message: String
    let createdAt: Date
    var avatarUrl: String?
    var visionboardId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case message
        case createdAt = "created_at"
        case avatarUrl = "avatar_url"
        case visionboardId = "visionboard_id"
    }

    func isCurrentUser(currentUserId: String) -> Bool {
        return senderId == currentUserId
    }
} 