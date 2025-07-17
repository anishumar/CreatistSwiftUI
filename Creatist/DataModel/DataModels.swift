import Foundation

// MARK: - Enums

enum MediaType: String, Codable, CaseIterable, Sendable {
    case image = "image"
    case video = "video"
}

enum UserGenre: String, Codable, CaseIterable, Sendable, Identifiable {
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
    var id: String { self.rawValue }
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

// MARK: - Vision Board & Related Models

enum VisionBoardStatus: String, CaseIterable, Codable {
    case draft = "Draft"
    case active = "Active"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

enum AssignmentStatus: String, CaseIterable, Codable {
    case pending = "Pending"
    case accepted = "Accepted"
    case rejected = "Rejected"
    case removed = "Removed"
}

enum WorkType: String, CaseIterable, Codable {
    case online = "Online"
    case offline = "Offline"
}

enum PaymentType: String, CaseIterable, Codable {
    case paid = "Paid"
    case unpaid = "Unpaid"
}

enum TaskPriority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

enum TaskStatus: String, CaseIterable, Codable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case completed = "Completed"
    case blocked = "Blocked"
}

enum EquipmentStatus: String, CaseIterable, Codable {
    case required = "Required"
    case confirmed = "Confirmed"
    case notAvailable = "Not Available"
}

enum DependencyType: String, CaseIterable, Codable {
    case finishToStart = "Finish-to-Start"
    case startToStart = "Start-to-Start"
    case finishToFinish = "Finish-to-Finish"
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
    var username: String?
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
    var description: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case username
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
        case description
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

struct VisionBoardsResponse: Codable {
    let message: String
    let visionboards: [VisionBoard]
}

struct VisionBoardUsersResponse: Codable {
    let message: String
    let users: [User]
}

// MARK: - Vision Board & Related Models

struct VisionBoard: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let startDate: Date
    let endDate: Date
    let status: VisionBoardStatus
    let createdAt: Date
    let updatedAt: Date
    let createdBy: UUID
    // Add this property for custom card color
    let colorHex: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
        case colorHex = "color_hex"
    }
}

struct VisionBoardCreate: Codable {
    let name: String
    let description: String?
    let startDate: Date
    let endDate: Date
    let status: VisionBoardStatus
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case status
    }
    
    init(name: String, description: String? = nil, startDate: Date, endDate: Date, status: VisionBoardStatus = .draft) {
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
    }
}

struct VisionBoardUpdate: Codable {
    let name: String?
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let status: VisionBoardStatus?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case status
    }
    
    init(name: String? = nil, description: String? = nil, startDate: Date? = nil, endDate: Date? = nil, status: VisionBoardStatus? = nil) {
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
    }
}

struct Genre: Codable, Identifiable {
    let id: UUID
    let visionboardId: UUID
    let name: String
    let description: String?
    let minRequiredPeople: Int
    let maxAllowedPeople: Int?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case visionboardId = "visionboard_id"
        case name
        case description
        case minRequiredPeople = "min_required_people"
        case maxAllowedPeople = "max_allowed_people"
        case createdAt = "created_at"
    }
}

struct GenreCreate: Codable {
    let name: String
    let description: String?
    let minRequiredPeople: Int
    let maxAllowedPeople: Int?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case minRequiredPeople = "min_required_people"
        case maxAllowedPeople = "max_allowed_people"
    }
    
    init(name: String, description: String? = nil, minRequiredPeople: Int = 1, maxAllowedPeople: Int? = nil) {
        self.name = name
        self.description = description
        self.minRequiredPeople = minRequiredPeople
        self.maxAllowedPeople = maxAllowedPeople
    }
}

struct GenreUpdate: Codable {
    let name: String?
    let description: String?
    let minRequiredPeople: Int?
    let maxAllowedPeople: Int?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case minRequiredPeople = "min_required_people"
        case maxAllowedPeople = "max_allowed_people"
    }
    
    init(name: String? = nil, description: String? = nil, minRequiredPeople: Int? = nil, maxAllowedPeople: Int? = nil) {
        self.name = name
        self.description = description
        self.minRequiredPeople = minRequiredPeople
        self.maxAllowedPeople = maxAllowedPeople
    }
}

struct Equipment: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let category: String
    let brand: String?
    let model: String?
    let specifications: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case brand
        case model
        case specifications
    }
}

struct EquipmentCreate: Codable {
    let name: String
    let description: String?
    let category: String
    let brand: String?
    let model: String?
    let specifications: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case category
        case brand
        case model
        case specifications
    }
    
    init(name: String, description: String? = nil, category: String, brand: String? = nil, model: String? = nil, specifications: [String: AnyCodable]? = nil) {
        self.name = name
        self.description = description
        self.category = category
        self.brand = brand
        self.model = model
        self.specifications = specifications
    }
}

struct EquipmentUpdate: Codable {
    let name: String?
    let description: String?
    let category: String?
    let brand: String?
    let model: String?
    let specifications: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case category
        case brand
        case model
        case specifications
    }
    
    init(name: String? = nil, description: String? = nil, category: String? = nil, brand: String? = nil, model: String? = nil, specifications: [String: AnyCodable]? = nil) {
        self.name = name
        self.description = description
        self.category = category
        self.brand = brand
        self.model = model
        self.specifications = specifications
    }
}

struct GenreAssignment: Codable, Identifiable {
    let id: UUID
    let genreId: UUID
    let userId: UUID
    let status: AssignmentStatus
    let workType: WorkType
    let paymentType: PaymentType
    let paymentAmount: Decimal?
    let currency: String?
    let invitedAt: Date
    let respondedAt: Date?
    let assignedBy: UUID
    
    enum CodingKeys: String, CodingKey {
        case id
        case genreId = "genre_id"
        case userId = "user_id"
        case status
        case workType = "work_type"
        case paymentType = "payment_type"
        case paymentAmount = "payment_amount"
        case currency
        case invitedAt = "invited_at"
        case respondedAt = "responded_at"
        case assignedBy = "assigned_by"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        genreId = try container.decode(UUID.self, forKey: .genreId)
        userId = try container.decode(UUID.self, forKey: .userId)
        status = try container.decode(AssignmentStatus.self, forKey: .status)
        workType = try container.decode(WorkType.self, forKey: .workType)
        paymentType = try container.decode(PaymentType.self, forKey: .paymentType)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        invitedAt = try container.decode(Date.self, forKey: .invitedAt)
        respondedAt = try container.decodeIfPresent(Date.self, forKey: .respondedAt)
        assignedBy = try container.decode(UUID.self, forKey: .assignedBy)
        
        // Handle payment_amount as either string or decimal
        if let paymentAmountString = try container.decodeIfPresent(String.self, forKey: .paymentAmount) {
            paymentAmount = Decimal(string: paymentAmountString)
        } else if let paymentAmountDecimal = try container.decodeIfPresent(Decimal.self, forKey: .paymentAmount) {
            paymentAmount = paymentAmountDecimal
        } else {
            paymentAmount = nil
        }
    }
}

struct GenreAssignmentCreate: Codable {
    let genreId: UUID
    let userId: UUID
    let workType: WorkType
    let paymentType: PaymentType
    let paymentAmount: Decimal?
    let currency: String?
    
    enum CodingKeys: String, CodingKey {
        case genreId = "genre_id"
        case userId = "user_id"
        case workType = "work_type"
        case paymentType = "payment_type"
        case paymentAmount = "payment_amount"
        case currency
    }
    
    init(genreId: UUID, userId: UUID, workType: WorkType, paymentType: PaymentType, paymentAmount: Decimal? = nil, currency: String? = nil) {
        self.genreId = genreId
        self.userId = userId
        self.workType = workType
        self.paymentType = paymentType
        self.paymentAmount = paymentAmount
        self.currency = currency
    }
}

struct GenreAssignmentUpdate: Codable {
    let status: AssignmentStatus?
    let workType: WorkType?
    let paymentType: PaymentType?
    let paymentAmount: Decimal?
    let currency: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case workType = "work_type"
        case paymentType = "payment_type"
        case paymentAmount = "payment_amount"
        case currency
    }
    
    init(status: AssignmentStatus? = nil, workType: WorkType? = nil, paymentType: PaymentType? = nil, paymentAmount: Decimal? = nil, currency: String? = nil) {
        self.status = status
        self.workType = workType
        self.paymentType = paymentType
        self.paymentAmount = paymentAmount
        self.currency = currency
    }
}

struct RequiredEquipment: Codable, Identifiable {
    let id: UUID
    let genreAssignmentId: UUID
    let equipmentId: UUID
    let quantity: Int
    let isProvidedByAssignee: Bool
    let notes: String?
    let status: EquipmentStatus
    
    enum CodingKeys: String, CodingKey {
        case id
        case genreAssignmentId = "genre_assignment_id"
        case equipmentId = "equipment_id"
        case quantity
        case isProvidedByAssignee = "is_provided_by_assignee"
        case notes
        case status
    }
}

struct RequiredEquipmentCreate: Codable {
    let equipmentId: UUID
    let quantity: Int
    let isProvidedByAssignee: Bool
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case equipmentId = "equipment_id"
        case quantity
        case isProvidedByAssignee = "is_provided_by_assignee"
        case notes
    }
    
    init(equipmentId: UUID, quantity: Int = 1, isProvidedByAssignee: Bool = false, notes: String? = nil) {
        self.equipmentId = equipmentId
        self.quantity = quantity
        self.isProvidedByAssignee = isProvidedByAssignee
        self.notes = notes
    }
}

struct RequiredEquipmentUpdate: Codable {
    let quantity: Int?
    let isProvidedByAssignee: Bool?
    let notes: String?
    let status: EquipmentStatus?
    
    enum CodingKeys: String, CodingKey {
        case quantity
        case isProvidedByAssignee = "is_provided_by_assignee"
        case notes
        case status
    }
    
    init(quantity: Int? = nil, isProvidedByAssignee: Bool? = nil, notes: String? = nil, status: EquipmentStatus? = nil) {
        self.quantity = quantity
        self.isProvidedByAssignee = isProvidedByAssignee
        self.notes = notes
        self.status = status
    }
}

struct VisionBoardTask: Codable, Identifiable {
    let id: UUID
    let genreAssignmentId: UUID
    let title: String
    let description: String?
    let priority: TaskPriority
    let status: TaskStatus
    let dueDate: Date?
    let estimatedHours: Decimal?
    let actualHours: Decimal?
    let createdAt: Date
    let updatedAt: Date
    let createdBy: UUID
    
    enum CodingKeys: String, CodingKey {
        case id
        case genreAssignmentId = "genre_assignment_id"
        case title
        case description
        case priority
        case status
        case dueDate = "due_date"
        case estimatedHours = "estimated_hours"
        case actualHours = "actual_hours"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
    }
}

struct VisionBoardTaskCreate: Codable {
    let genreAssignmentId: UUID
    let title: String
    let description: String?
    let priority: TaskPriority
    let dueDate: Date?
    let estimatedHours: Decimal?
    
    enum CodingKeys: String, CodingKey {
        case genreAssignmentId = "genre_assignment_id"
        case title
        case description
        case priority
        case dueDate = "due_date"
        case estimatedHours = "estimated_hours"
    }
    
    init(genreAssignmentId: UUID, title: String, description: String? = nil, priority: TaskPriority = .medium, dueDate: Date? = nil, estimatedHours: Decimal? = nil) {
        self.genreAssignmentId = genreAssignmentId
        self.title = title
        self.description = description
        self.priority = priority
        self.dueDate = dueDate
        self.estimatedHours = estimatedHours
    }
}

struct VisionBoardTaskUpdate: Codable {
    let title: String?
    let description: String?
    let priority: TaskPriority?
    let status: TaskStatus?
    let dueDate: Date?
    let estimatedHours: Decimal?
    let actualHours: Decimal?
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case priority
        case status
        case dueDate = "due_date"
        case estimatedHours = "estimated_hours"
        case actualHours = "actual_hours"
    }
    
    init(title: String? = nil, description: String? = nil, priority: TaskPriority? = nil, status: TaskStatus? = nil, dueDate: Date? = nil, estimatedHours: Decimal? = nil, actualHours: Decimal? = nil) {
        self.title = title
        self.description = description
        self.priority = priority
        self.status = status
        self.dueDate = dueDate
        self.estimatedHours = estimatedHours
        self.actualHours = actualHours
    }
}

struct TaskDependency: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let dependsOnTaskId: UUID
    let dependencyType: DependencyType
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case dependsOnTaskId = "depends_on_task_id"
        case dependencyType = "dependency_type"
    }
}

struct TaskDependencyCreate: Codable {
    let dependsOnTaskId: UUID
    let dependencyType: DependencyType
    
    enum CodingKeys: String, CodingKey {
        case dependsOnTaskId = "depends_on_task_id"
        case dependencyType = "dependency_type"
    }
    
    init(dependsOnTaskId: UUID, dependencyType: DependencyType = .finishToStart) {
        self.dependsOnTaskId = dependsOnTaskId
        self.dependencyType = dependencyType
    }
}

struct TaskComment: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let userId: UUID
    let comment: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case userId = "user_id"
        case comment
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TaskCommentCreate: Codable {
    let comment: String
    
    init(comment: String) {
        self.comment = comment
    }
}

struct TaskCommentUpdate: Codable {
    let comment: String
    
    init(comment: String) {
        self.comment = comment
    }
}

struct TaskAttachment: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let fileName: String
    let fileUrl: String
    let fileType: String?
    let fileSize: Int?
    let uploadedBy: UUID
    let uploadedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case fileName = "file_name"
        case fileUrl = "file_url"
        case fileType = "file_type"
        case fileSize = "file_size"
        case uploadedBy = "uploaded_by"
        case uploadedAt = "uploaded_at"
    }
}

struct TaskAttachmentCreate: Codable {
    let fileName: String
    let fileUrl: String
    let fileType: String?
    let fileSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case fileName = "file_name"
        case fileUrl = "file_url"
        case fileType = "file_type"
        case fileSize = "file_size"
    }
    
    init(fileName: String, fileUrl: String, fileType: String? = nil, fileSize: Int? = nil) {
        self.fileName = fileName
        self.fileUrl = fileUrl
        self.fileType = fileType
        self.fileSize = fileSize
    }
}

// MARK: - Response Models with Related Data

struct VisionBoardWithGenres: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let startDate: Date
    let endDate: Date
    let status: VisionBoardStatus
    let createdAt: Date
    let updatedAt: Date
    let createdBy: UUID
    let genres: [Genre]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
        case genres
    }
}

struct GenreWithAssignments: Codable, Identifiable {
    let id: UUID
    let visionboardId: UUID
    let name: String
    let description: String?
    let minRequiredPeople: Int
    let maxAllowedPeople: Int?
    let createdAt: Date
    let assignments: [GenreAssignment]
    
    enum CodingKeys: String, CodingKey {
        case id
        case visionboardId = "visionboard_id"
        case name
        case description
        case minRequiredPeople = "min_required_people"
        case maxAllowedPeople = "max_allowed_people"
        case createdAt = "created_at"
        case assignments
    }
}

struct GenreAssignmentWithDetails: Codable, Identifiable {
    let id: UUID
    let genreId: UUID
    let userId: UUID
    let status: AssignmentStatus
    let workType: WorkType
    let paymentType: PaymentType
    let paymentAmount: Decimal?
    let currency: String?
    let invitedAt: Date
    let respondedAt: Date?
    let assignedBy: UUID
    let userName: String?
    let genreName: String?
    let equipment: [RequiredEquipment]
    let tasks: [VisionBoardTask]
    
    enum CodingKeys: String, CodingKey {
        case id
        case genreId = "genre_id"
        case userId = "user_id"
        case status
        case workType = "work_type"
        case paymentType = "payment_type"
        case paymentAmount = "payment_amount"
        case currency
        case invitedAt = "invited_at"
        case respondedAt = "responded_at"
        case assignedBy = "assigned_by"
        case userName = "user_name"
        case genreName = "genre_name"
        case equipment
        case tasks
    }
}

struct VisionBoardTaskWithDetails: Codable, Identifiable {
    let id: UUID
    let genreAssignmentId: UUID
    let title: String
    let description: String?
    let priority: TaskPriority
    let status: TaskStatus
    let dueDate: Date?
    let estimatedHours: Decimal?
    let actualHours: Decimal?
    let createdAt: Date
    let updatedAt: Date
    let createdBy: UUID
    let comments: [TaskComment]
    let attachments: [TaskAttachment]
    let dependencies: [TaskDependency]
    let userName: String?
    let genreName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case genreAssignmentId = "genre_assignment_id"
        case title
        case description
        case priority
        case status
        case dueDate = "due_date"
        case estimatedHours = "estimated_hours"
        case actualHours = "actual_hours"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
        case comments
        case attachments
        case dependencies
        case userName = "user_name"
        case genreName = "genre_name"
    }
}

struct VisionBoardSummary: Codable, Identifiable {
    let id: UUID
    let name: String
    let status: VisionBoardStatus
    let startDate: Date
    let endDate: Date
    let totalGenres: Int
    let totalAssignments: Int
    let totalTasks: Int
    let completedTasks: Int
    let createdBy: UUID
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case startDate = "start_date"
        case endDate = "end_date"
        case totalGenres = "total_genres"
        case totalAssignments = "total_assignments"
        case totalTasks = "total_tasks"
        case completedTasks = "completed_tasks"
        case createdBy = "created_by"
    }
}

// MARK: - Statistics Models

struct VisionBoardStats: Codable {
    let totalVisionboards: Int
    let activeVisionboards: Int
    let completedVisionboards: Int
    let totalAssignments: Int
    let pendingAssignments: Int
    let totalTasks: Int
    let completedTasks: Int
    let overdueTasks: Int
    
    enum CodingKeys: String, CodingKey {
        case totalVisionboards = "total_visionboards"
        case activeVisionboards = "active_visionboards"
        case completedVisionboards = "completed_visionboards"
        case totalAssignments = "total_assignments"
        case pendingAssignments = "pending_assignments"
        case totalTasks = "total_tasks"
        case completedTasks = "completed_tasks"
        case overdueTasks = "overdue_tasks"
    }
}

// MARK: - Helper Types

// Helper for handling any JSON value in specifications
struct AnyCodable: Codable {
    let value: Any
    
    init<T>(_ value: T?) {
        self.value = value ?? ()
}

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) { value = intVal; return }
        if let doubleVal = try? container.decode(Double.self) { value = doubleVal; return }
        if let boolVal = try? container.decode(Bool.self) { value = boolVal; return }
        if let stringVal = try? container.decode(String.self) { value = stringVal; return }
        if let dictVal = try? container.decode([String: AnyCodable].self) { value = dictVal; return }
        if let arrVal = try? container.decode([AnyCodable].self) { value = arrVal; return }
            value = ()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intVal as Int: try container.encode(intVal)
        case let doubleVal as Double: try container.encode(doubleVal)
        case let boolVal as Bool: try container.encode(boolVal)
        case let stringVal as String: try container.encode(stringVal)
        case let dictVal as [String: AnyCodable]: try container.encode(dictVal)
        case let arrVal as [AnyCodable]: try container.encode(arrVal)
        default: try container.encodeNil()
        }
    }
}

// Custom Decimal Codable support
extension Decimal: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let doubleValue = try? container.decode(Double.self) {
            self = Decimal(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = Decimal(string: stringValue) ?? 0
        } else {
            self = 0
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
}

// MARK: - Vision Board Creation Request Models

// API Response Models
struct VisionBoardResponse: Codable {
    let message: String
    let visionboard: VisionBoard
}

struct GenreResponse: Codable {
    let message: String
    let genre: Genre
}

struct AssignmentResponse: Codable {
    let message: String
    let assignment: GenreAssignment
}

struct NotificationResponse: Codable {
    let message: String
    let success: Bool
}

// Request models for the multi-step API process
struct AssignmentCreate: Codable {
    let userId: UUID
    let workType: WorkType
    let paymentType: PaymentType
    let paymentAmount: Decimal?
    let currency: String?
    let genreName: String // Track which genre this assignment belongs to
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case workType = "work_type"
        case paymentType = "payment_type"
        case paymentAmount = "payment_amount"
        case currency
        case genreName = "genre_name"
    }
}

// Legacy models (keeping for backward compatibility)
struct VisionBoardCreateRequest: Codable {
    let name: String
    let description: String?
    let startDate: Date
    let endDate: Date
    let status: VisionBoardStatus
    let genres: [GenreAssignmentRequest]
}

struct GenreAssignmentRequest: Codable {
    let genre: UserGenre
    let assignments: [CreatorAssignmentRequest]
}

struct CreatorAssignmentRequest: Codable {
    let userId: UUID
    let workMode: WorkMode
    let paymentType: PaymentType
    let paymentAmount: Decimal?
    let startDate: Date
    let endDate: Date
    let requiredEquipments: [String]
}

// MARK: - Notification Model (Generic)
struct NotificationItem: Codable, Identifiable {
    let id: UUID
    let receiverId: UUID
    let senderId: UUID
    let objectType: String
    let objectId: UUID
    let eventType: String
    var status: String // "unread", "read", etc.
    let data: [String: AnyCodable]?
    let message: String
    let createdAt: Date
    let updatedAt: Date
    enum CodingKeys: String, CodingKey {
        case id
        case receiverId = "receiver_id"
        case senderId = "sender_id"
        case objectType = "object_type"
        case objectId = "object_id"
        case eventType = "event_type"
        case status
        case data
        case message
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Invitation Model
struct Invitation: Codable, Identifiable {
    let id: UUID
    let receiverId: UUID
    let senderId: UUID
    let objectType: String
    let objectId: UUID
    var status: String
    let data: [String: AnyCodable]?
    let createdAt: Date
    let respondedAt: Date?
    enum CodingKeys: String, CodingKey {
        case id, status, data
        case receiverId = "receiver_id"
        case senderId = "sender_id"
        case objectType = "object_type"
        case objectId = "object_id"
        case createdAt = "created_at"
        case respondedAt = "responded_at"
    }
}

// Response wrapper for genre with assignments
struct GenreWithAssignmentsResponse: Codable {
    let message: String
    let genre: GenreWithAssignments
}

// MARK: - UI Helper Models (moved from VisionBoardView.swift)

struct IdentifiableUUID: Identifiable, Equatable {
    let id: UUID
}

struct UserResponse: Codable {
    let message: String?
    let user: User
} 

struct Draft: Identifiable, Codable {
    let id: UUID
    let visionboardId: UUID
    let userId: UUID
    let mediaUrl: String
    let mediaType: String?
    let description: String?
    let createdAt: Date
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case visionboardId = "visionboard_id"
        case userId = "user_id"
        case mediaUrl = "media_url"
        case mediaType = "media_type"
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct DraftComment: Identifiable, Codable {
    let id: UUID
    let draftId: UUID
    let userId: UUID
    let comment: String
    let createdAt: Date
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case draftId = "draft_id"
        case userId = "user_id"
        case comment
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
} 

// MARK: - Feed Post Model for FeedView (Backend-Compatible)

struct PostWithDetails: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let caption: String?
    let isCollaborative: Bool
    let status: String
    let visibility: String
    let sharedFromPostId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let media: [PostMedia]
    let tags: [String]
    let collaborators: [PostCollaborator]
    let likeCount: Int
    let commentCount: Int
    let viewCount: Int
    let authorName: String?
    let topComments: [PostComment]
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case caption
        case isCollaborative = "is_collaborative"
        case status
        case visibility
        case sharedFromPostId = "shared_from_post_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case media
        case tags
        case collaborators
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case viewCount = "view_count"
        case authorName = "author_name"
        case topComments = "top_comments"
    }
}

struct PostMedia: Identifiable, Codable {
    let id: UUID
    let postId: UUID
    let url: String
    let type: String
    let order: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case url
        case type
        case order
    }
}

struct PostCollaborator: Identifiable, Codable {
    let postId: UUID
    let userId: UUID
    let role: String
    
    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
        case role
    }
    var id: UUID { userId }
}

struct PostComment: Identifiable, Codable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let content: String
    let parentCommentId: UUID?
    let createdAt: Date
    let deletedAt: Date?
    let replies: [PostComment]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case content
        case parentCommentId = "parent_comment_id"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
        case replies
    }
} 

// MARK: - Post Like, View, Tag, Hashtag Models (Backend-Compatible)

struct Hashtag: Identifiable, Codable {
    let id: UUID
    let tag: String
}

struct PostHashtag: Codable {
    let postId: UUID
    let hashtagId: UUID
    
    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case hashtagId = "hashtag_id"
    }
} 

struct PaginatedPosts: Codable {
    let posts: [PostWithDetails]
    let nextCursor: String?
} 
