import Foundation

// MARK: - Enums

enum MediaType: String, Codable, CaseIterable, Sendable {
    case image = "image"
    case video = "video"
}

enum UserGenre: String, Codable, CaseIterable, Sendable {
    case videographer = "videographer"
    case photographer = "photographer"
    case vocalist = "vocalist"
    case dancer = "dancer"
    case drummer = "drummer"
    case editor = "editor"
    case actor = "actor"
    case composer = "composer"
    case director = "director"
    case writer = "writer"
    case graphicDesigner = "graphicDesigner"
    case singer = "singer"
    case guitarist = "guitarist"
    case sitarist = "sitarist"
    case pianist = "pianist"
    case violinist = "violinist"
    case flutist = "flutist"
    case percussionist = "percussionist"
}

enum PaymentMode: String, Codable, CaseIterable, Sendable {
    case free = "free"
    case paid = "paid"
}

enum WorkMode: String, Codable, CaseIterable, Sendable {
    case online = "Online"
    case onsite = "Onsite"
    case onlineOnsite = "OnsiteOnline"
}

// MARK: - Location Model

struct Location: Codable, Sendable {
    var latitude: Double
    var longitude: Double
    
    func distance(to other: Location) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = (other.latitude - latitude) * .pi / 180
        let deltaLon = (other.longitude - longitude) * .pi / 180
        
        let a = sin(deltaLat/2) * sin(deltaLat/2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon/2) * sin(deltaLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return 6371 * c // Earth's radius in km
    }
}

// MARK: - User Model

struct User: Codable, Sendable {
    var id: UUID
    var name: String
    var email: String
    var password: String
    var profileImageUrl: String?
    var age: Int?
    var genres: [UserGenre]?
    var paymentMode: PaymentMode?
    var workMode: WorkMode?
    var location: Location?
    var rating: Double?
    var city: String?
    var country: String?
    var distance: Double?
    var isFollowing: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case password
        case profileImageUrl = "profile_image_url"
        case age
        case genres
        case paymentMode = "payment_mode"
        case workMode = "work_mode"
        case location
        case rating
        case city
        case country
        case distance
        case isFollowing = "is_following"
    }
    
    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    func distance(to other: User) -> Double {
        guard let myLocation = location, let otherLocation = other.location else {
            return Double.infinity // Return infinity if location is missing
        }
        return myLocation.distance(to: otherLocation)
    }
}

// MARK: - Auth Models

struct Credential: Codable {
    let email: String
    let password: String
    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

struct LoginResponse: Codable {
    let message: String
    let access_token: String?
    let refresh_token: String?
    let token_type: String?
    let expires_in: Int?
}

struct Response: Codable {
    let message: String
}

// MARK: - Showcase Models

struct Showcase: Codable, Sendable {
    var id: UUID = .init()
    var owner_id: UUID
    var visionboard: UUID?
    var description: String?
    var media_link: String?
    var media_type: String? // Use MediaType? if you want type safety
}

struct ShowCaseLike: Codable, Sendable {
    var user_id: UUID
    var showcase_id: UUID
}

struct ShowCaseBookmark: Codable, Sendable {
    var user_id: UUID
    var showcase_id: UUID
}

// MARK: - Comment Models

struct Comment: Codable, Sendable {
    var id: UUID
    var showcase_id: UUID
    var text: String
    var author_id: UUID
    var timestamp: Date
}

struct CommentUpvote: Codable, Sendable {
    var user_id: UUID
    var comment_id: UUID
}

// MARK: - Vision Board Models

struct VisionBoard: Codable, Sendable {
    var id: UUID
    var owner_id: UUID
    var name: String
    var description: String
    var start_date: Date
    var end_date: Date
}

struct VisionBoardRole: Codable, Sendable {
    var visionboard_id: UUID
    var role: UserGenre
    var user_id: UUID
}

struct VisionBoardTask: Codable, Sendable {
    var user_id: UUID
    var visionboard_id: UUID
    var title: String
    var start_date: Date
    var end_date: Date
}

// MARK: - Follower Model

struct Follower: Codable, Sendable {
    var user_id: UUID
    var following_id: UUID
}

struct OTPRequest: Codable, Sendable {
    var email_address: String
    var otp: String?
}

struct UsersResponse: Codable {
    let users: [User]?
    let message: String?
}

struct ArtistsResponse: Codable {
    let artists: [User]
} 
