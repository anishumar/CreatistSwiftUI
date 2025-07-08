import Foundation
import Combine

// Import all data models from DataModels.swift
// (No data model structs/enums should be defined here)

@MainActor
class Creatist {
    public static var shared: Creatist = .init()
    var user: User?
    
    private func _login(email: String, password: String) async -> LoginResponse? {
        let credentials = Credential(email: email, password: password)
        guard let data = credentials.toData() else {
            return nil
        }
        await self.fetch()
        return await NetworkManager.shared.post(url: "/auth/signin", body: data)
    }
    
    func login(email: String, password: String) async -> Bool {
        let loginResponse: LoginResponse? = await _login(email: email, password: password)
        if loginResponse?.message == "success",
           let accessToken = loginResponse?.access_token,
           let refreshToken = loginResponse?.refresh_token {
            KeychainHelper.set(email, forKey: "email")
            KeychainHelper.set(password, forKey: "password")
            KeychainHelper.set(accessToken, forKey: "accessToken")
            KeychainHelper.set(refreshToken, forKey: "refreshToken")
            await self.fetch()
            return true
        }
        return false
    }
    
    func autologin() async -> Bool? {
        let email = KeychainHelper.get("email")
        let password = KeychainHelper.get("password")
        await self.fetch()
        guard let email, let password else {
            return false
        }
        let response = await _login(email: email, password: password)
        return response?.message == "success"
    }
    
    func signup(_ user: User) async -> Bool {
        guard let data = user.toData() else {
            return false
        }
        let response: Response? = await NetworkManager.shared.post(url: "/auth/signup", body: data)
        if response?.message == "success" {
            KeychainHelper.set(user.email, forKey: "email")
            KeychainHelper.set(user.password, forKey: "password")
        }
        return response?.message == "success"
    }
    
    func fetch() async {
        let user: User? = await NetworkManager.shared.get(url: "/auth/fetch")
        if let user {
            self.user = user
        }
    }
    
    func requestOTP() async -> Bool? {
        let email = KeychainHelper.get("email")
        guard let email else {
            return false
        }
        let otpRequest = OTPRequest(email_address: email, otp: nil)
        guard let data = try? JSONEncoder().encode(otpRequest) else {
            return false
        }
        return await NetworkManager.shared.post(url: "/auth/otp", body: data)
    }
    
    func verifyOTP(_ otp: String) async -> Bool? {
        let email = KeychainHelper.get("email")
        guard let email else {
            return false
        }
        let otpRequest = OTPRequest(email_address: email, otp: otp)
        guard let data = try? JSONEncoder().encode(otpRequest) else {
            return false
        }
        return await NetworkManager.shared.post(url: "/auth/otp/verify", body: data)
    }
    
    func fetchUsers(for genre: UserGenre) async -> [User] {
        let url = "/v1/users?genre=\(genre.rawValue)"
        
        // Try to decode as direct array first
        if let users: [User] = await NetworkManager.shared.get(url: url) {
            print("Fetched users for genre: \(genre.rawValue): \(users)")
            return users.filter { $0.genres?.contains(genre) == true }
        }
        
        // If that fails, try as wrapped response
        if let response: UsersResponse = await NetworkManager.shared.get(url: url) {
            let users = response.users ?? []
            print("Fetched users for genre: \(genre.rawValue): \(users)")
            return users.filter { $0.genres?.contains(genre) == true }
        }
        
        print("Fetched users for genre: \(genre.rawValue): nil")
        return []
    }
    
    func updateUserLocation(latitude: Double, longitude: Double) async -> Bool {
        let location = Location(latitude: latitude, longitude: longitude)
        guard let data = try? JSONEncoder().encode(location) else { return false }
        let response: Response? = await NetworkManager.shared.patch(url: "/v1/users/location", body: data)
        return response?.message == "success"
    }
    
    func fetchTopRatedUsers(for genre: UserGenre) async -> [User] {
        let url = "/v1/browse/top-rated/\(genre.rawValue)"
        if let response: ArtistsResponse = await NetworkManager.shared.get(url: url) {
            return response.artists
        }
        return []
    }

    func fetchNearbyUsers(for genre: UserGenre) async -> [User] {
        let url = "/v1/browse/near-by-artist/\(genre.rawValue)"
        if let response: ArtistsResponse = await NetworkManager.shared.get(url: url) {
            return response.artists
        }
        return []
    }
    
    func followUser(userId: String) async -> Bool {
        let response: Response? = await NetworkManager.shared.put(url: "/v1/follow/\(userId)", body: nil)
        return response?.message == "success"
    }
    
    func unfollowUser(userId: String) async -> Bool {
        let success = await NetworkManager.shared.delete(url: "/v1/unfollow/\(userId)", body: nil)
        return success
    }
    
    // Fetch followers count for any user
    func fetchFollowersCount(for userId: String) async -> Int {
        struct FollowersResponse: Codable { let message: String; let followers: [User] }
        let url = "/v1/followers/\(userId)"
        if let response: FollowersResponse = await NetworkManager.shared.get(url: url) {
            return response.followers.count
        }
        return 0
    }
    
    // Fetch following count for any user
    func fetchFollowingCount(for userId: String) async -> Int {
        struct FollowingResponse: Codable { let message: String; let following: [User] }
        let url = "/v1/following/\(userId)"
        if let response: FollowingResponse = await NetworkManager.shared.get(url: url) {
            return response.following.count
        }
        return 0
    }
    
    // Fetch users you are following for a given genre
    func fetchFollowingForGenre(userId: UUID, genre: UserGenre) async -> [User] {
        let url = "/v1/following/\(userId.uuidString)/\(genre.rawValue)"
        struct FollowingResponse: Codable { let message: String; let following: [User] }
        if let response: FollowingResponse = await NetworkManager.shared.get(url: url) {
            return response.following
        }
        return []
    }
    
    // Fetch followers list for any user
    func fetchFollowers(for userId: String) async -> [User] {
        struct FollowersResponse: Codable { let message: String; let followers: [User] }
        let url = "/v1/followers/\(userId)"
        if let response: FollowersResponse = await NetworkManager.shared.get(url: url) {
            return response.followers
        }
        return []
    }
    
    // Fetch following list for a user and genre (role)
    func fetchFollowing(for userId: UUID, genre: UserGenre) async -> [User] {
        let url = "/v1/following/\(userId.uuidString)/\(genre.rawValue)"
        struct FollowingResponse: Codable { let message: String; let following: [User] }
        if let response: FollowingResponse = await NetworkManager.shared.get(url: url) {
            return response.following
        }
        return []
    }
    
    // Helper to format Date as ISO8601 string
    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    // Create a vision board using the multi-step API process
    func createVisionBoard(
        name: String,
        description: String?,
        startDate: Date,
        endDate: Date,
        genres: [GenreCreate],
        assignments: [AssignmentCreate]
    ) async -> Bool {
        print("🚀 Creatist: Starting vision board creation...")
        print("🚀 Creatist: Name: \(name)")
        print("🚀 Creatist: Genres count: \(genres.count)")
        print("🚀 Creatist: Assignments count: \(assignments.count)")
        
        do {
            print("🚀 Starting vision board creation process...")
            print("📋 Input Data:")
            print("   Name: \(name)")
            print("   Description: \(description ?? "nil")")
            print("   Start Date: \(startDate)")
            print("   End Date: \(endDate)")
            print("   Genres Count: \(genres.count)")
            print("   Assignments Count: \(assignments.count)")
            
            // Step 1: Create the vision board
            print("📤 Step 1: Creating vision board...")
            guard let currentUser = self.user else {
                print("❌ No current user found for vision board creation")
                return false
            }
            let visionBoardData: [String: Any] = [
                "id": UUID().uuidString,
                "owner_id": currentUser.id.uuidString,
                "name": name,
                "description": description ?? "",
                "start_date": iso8601String(from: startDate),
                "end_date": iso8601String(from: endDate),
                "status": "Draft"
            ]
            let requestData = try JSONSerialization.data(withJSONObject: visionBoardData, options: [])
            print("   Request Data: \(String(data: requestData, encoding: .utf8) ?? "<invalid>")")
            guard let visionBoardResponse: VisionBoardResponse = await NetworkManager.shared.post(
                url: "/v1/visionboard/create",
                body: requestData
            ) else {
                print("❌ Failed to create vision board")
                return false
            }
            let visionBoardId = visionBoardResponse.visionboard.id
            print("✅ Step 1: Vision board created with ID: \(visionBoardId)")
            print("   Response: \(String(data: try JSONEncoder().encode(visionBoardResponse), encoding: .utf8) ?? "nil")")
            
            // Step 2: Create genres for the vision board
            print("📤 Step 2: Creating genres...")
            var createdGenres: [Genre] = []
            for (index, genreCreate) in genres.enumerated() {
                print("   Creating genre \(index + 1)/\(genres.count): \(genreCreate.name)")
                let genreData: [String: Any] = [
                    "name": genreCreate.name,
                    "description": genreCreate.description ?? "",
                    "min_required_people": genreCreate.minRequiredPeople,
                    "max_allowed_people": genreCreate.maxAllowedPeople ?? 0
                ]
                let genreRequestData = try JSONSerialization.data(withJSONObject: genreData, options: [])
                print("   Genre request data: \(String(data: genreRequestData, encoding: .utf8) ?? "<invalid>")")
                
                guard let genreResponse: GenreResponse = await NetworkManager.shared.post(
                    url: "/v1/visionboard/\(visionBoardId)/genres",
                    body: genreRequestData
                ) else {
                    print("❌ Failed to create genre: \(genreCreate.name)")
                    return false
                }
                createdGenres.append(genreResponse.genre)
                print("✅ Created genre: \(genreResponse.genre.name) with ID: \(genreResponse.genre.id)")
            }
            
            // Step 3: Create assignments for each genre
            print("📤 Step 3: Creating assignments...")
            for (index, assignment) in assignments.enumerated() {
                // Find the corresponding genre for this assignment
                guard let genreIndex = createdGenres.firstIndex(where: { $0.name == assignment.genreName }) else {
                    print("❌ No corresponding genre found for assignment \(index + 1) with genre: \(assignment.genreName)")
                    return false
                }
                
                let genreId = createdGenres[genreIndex].id
                print("   Creating assignment \(index + 1)/\(assignments.count) for user: \(assignment.userId) in genre: \(assignment.genreName) (ID: \(genreId))")
                let assignmentData: [String: Any] = [
                    "genre_id": genreId.uuidString,
                    "user_id": assignment.userId.uuidString,
                    "work_type": assignment.workType.rawValue,
                    "payment_type": assignment.paymentType.rawValue,
                    "payment_amount": assignment.paymentAmount ?? 0,
                    "currency": assignment.currency ?? "USD"
                ]
                let assignmentRequestData = try JSONSerialization.data(withJSONObject: assignmentData, options: [])
                print("   Assignment request data: \(String(data: assignmentRequestData, encoding: .utf8) ?? "<invalid>")")
                
                guard let assignmentResponse: AssignmentResponse = await NetworkManager.shared.post(
                    url: "/v1/visionboard/assignments",
                    body: assignmentRequestData
                ) else {
                    print("❌ Failed to create assignment for user: \(assignment.userId)")
                    return false
                }
                print("✅ Created assignment: \(assignmentResponse.assignment.id)")
            }
            
            print("🎉 Vision board creation completed successfully!")
            return true
            
        } catch {
            print("❌ Error creating vision board: \(error)")
            return false
        }
    }
    
    // Helper method to send notifications
    private func sendNotificationsToCreators(assignments: [AssignmentCreate]) async {
        // This is where you would implement notification logic
        // You could call a separate notification endpoint or use push notifications
        
        for assignment in assignments {
            // Example: Send push notification or email
            print("📧 Sending notification to user: \(assignment.userId)")
            
            // If you have a notification endpoint, call it here:
            // await sendNotification(to: assignment.userId, message: "You've been assigned to a new vision board!")
        }
    }
    
    // Legacy method for backward compatibility
    func createVisionBoard(_ request: VisionBoardCreateRequest) async -> Bool {
        // Convert the legacy request to the new format
        let genres = request.genres.map { genreRequest in
            GenreCreate(
                name: genreRequest.genre.rawValue,
                description: nil,
                minRequiredPeople: 1,
                maxAllowedPeople: nil
            )
        }
        
        let assignments = request.genres.flatMap { genreRequest in
            genreRequest.assignments.map { creatorRequest in
                AssignmentCreate(
                    userId: creatorRequest.userId,
                    workType: WorkType(rawValue: creatorRequest.workMode.rawValue) ?? .online,
                    paymentType: creatorRequest.paymentType,
                    paymentAmount: creatorRequest.paymentAmount,
                    currency: "USD",
                    genreName: genreRequest.genre.rawValue
                )
            }
        }
        
        return await createVisionBoard(
            name: request.name,
            description: request.description,
            startDate: request.startDate,
            endDate: request.endDate,
            genres: genres,
            assignments: assignments
        )
    }
    
    // Fetch all vision boards for the current user
    func fetchMyVisionBoards() async -> [VisionBoard] {
        guard let user = self.user else { 
            print("❌ No current user found for fetching vision boards")
            return [] 
        }
        print("🔍 Fetching vision boards created by user: \(user.id)")
        let url = "/v1/visionboard?created_by=\(user.id.uuidString)"
        print("🌐 NetworkManager: GET \(url)")
        
        if let response: VisionBoardsResponse = await NetworkManager.shared.get(url: url) {
            print("✅ Fetched \(response.visionboards.count) vision boards created by user")
            return response.visionboards
        }
        print("❌ Failed to fetch vision boards created by user")
        return []
    }

    // Fetch all vision boards where the user is a partner (not creator)
    func fetchPartnerVisionBoards() async -> [VisionBoard] {
        guard let user = self.user else { 
            print("❌ No current user found for fetching partner vision boards")
            return [] 
        }
        print("🔍 Fetching vision boards where user is partner: \(user.id)")
        let url = "/v1/visionboard?partner_id=\(user.id.uuidString)"
        print("🌐 NetworkManager: GET \(url)")
        
        if let response: VisionBoardsResponse = await NetworkManager.shared.get(url: url) {
            print("✅ Fetched \(response.visionboards.count) partner vision boards")
            return response.visionboards
        }
        print("❌ Failed to fetch partner vision boards")
        return []
    }

    // Fetch all users assigned to a specific vision board
    func fetchVisionBoardUsers(visionBoardId: UUID) async -> [User] {
        print("🔍 Fetching users for vision board: \(visionBoardId)")
        let url = "/v1/visionboard/\(visionBoardId.uuidString.lowercased())/users"
        print("🌐 NetworkManager: GET \(url)")
        
        if let response: VisionBoardUsersResponse = await NetworkManager.shared.get(url: url) {
            print("✅ Fetched \(response.users.count) users for vision board")
            return response.users
        }
        print("❌ Failed to fetch users for vision board")
        return []
    }
}

// MARK: - Notification ViewModel

class NotificationViewModel: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    private var cancellables = Set<AnyCancellable>()
    
    func fetchNotifications() async {
        print("[DEBUG] fetchNotifications called")
        let accessToken = KeychainHelper.get("accessToken")
        print("[DEBUG] Access token: \(accessToken ?? "nil")")
        guard let token = accessToken, !token.isEmpty else {
            print("[DEBUG] No access token found. User is not logged in.")
            await MainActor.run { self.errorMessage = "Not logged in. Please sign in again." }
            return
        }
        await MainActor.run { self.isLoading = true }
        defer { Task { await MainActor.run { self.isLoading = false } } }
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/notifications") else { print("[DEBUG] Invalid URL"); return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            print("[DEBUG] Notifications API response: \(String(data: data, encoding: .utf8) ?? "nil")")
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[DEBUG] HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                await MainActor.run { self.errorMessage = "Failed to fetch notifications." }
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                // Try fallback without fractional seconds
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected date string to be ISO8601-formatted.")
            }
            let notifications = try decoder.decode([NotificationItem].self, from: data)
            print("[DEBUG] Parsed notifications: \(notifications)")
            await MainActor.run { self.notifications = notifications }
        } catch {
            print("[DEBUG] Error fetching notifications: \(error)")
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }
    
    func respond(to notification: NotificationItem, response: String, comment: String) async {
        print("[DEBUG] respond called for notification id: \(notification.id), response: \(response), comment: \(comment)")
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/notifications/\(notification.id)/respond") else { print("[DEBUG] Invalid URL"); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "response": response,
            "comment": comment
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, httpResponse) = try await NetworkManager.shared.authorizedRequest(request)
            print("[DEBUG] Respond API response: \(String(data: data, encoding: .utf8) ?? "nil")")
            guard let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[DEBUG] HTTP error: \(httpResponse as? HTTPURLResponse)?.statusCode ?? -1)")
                await MainActor.run { self.errorMessage = "Failed to respond to notification." }
                return
            }
            if let idx = self.notifications.firstIndex(where: { $0.id == notification.id }) {
                await MainActor.run { self.notifications[idx].status = response }
            }
        } catch {
            print("[DEBUG] Error responding to notification: \(error)")
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }
}

class InvitationListViewModel: ObservableObject {
    @Published var invitations: [Invitation] = []
    @Published var visionBoards: [UUID: VisionBoard] = [:] // visionboard_id: VisionBoard
    @Published var genres: [UUID: GenreWithAssignments] = [:] // genre_id: GenreWithAssignments
    @Published var senders: [UUID: User] = [:] // sender_id: User
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func fetchInvitationsAndBoards() async {
        print("[DEBUG] fetchInvitationsAndBoards called")
        let accessToken = KeychainHelper.get("accessToken")
        print("[DEBUG] Access token: \(accessToken ?? "nil")")
        guard let token = accessToken, !token.isEmpty else {
            print("[DEBUG] No access token found. User is not logged in.")
            await MainActor.run { self.errorMessage = "Not logged in. Please sign in again." }
            return
        }
        await MainActor.run { self.isLoading = true }
        defer { Task { await MainActor.run { self.isLoading = false } } }
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/invitations/user?status=pending") else { print("[DEBUG] Invalid URL"); return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            print("[DEBUG] Invitations API response: \(String(data: data, encoding: .utf8) ?? "nil")")
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[DEBUG] HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                await MainActor.run { self.errorMessage = "Failed to fetch invitations." }
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected date string to be ISO8601-formatted.")
            }
            let result = try decoder.decode([String: [Invitation]].self, from: data)
            let invitations = result["invitations"] ?? []
            print("[DEBUG] Parsed invitations: \(invitations)")
            await MainActor.run { self.invitations = invitations }
            // Fetch vision boards and sender info for each invitation
            for invitation in invitations {
                await fetchSender(userId: invitation.senderId, token: token)
                if invitation.objectType == "visionboard" {
                    await fetchVisionBoard(visionboardId: invitation.objectId, token: token)
                } else if invitation.objectType == "genre" {
                    await fetchGenreAndVisionBoard(genreId: invitation.objectId, token: token)
                }
            }
        } catch {
            print("[DEBUG] Error fetching invitations: \(error)")
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    private func fetchSender(userId: UUID, token: String) async {
        guard senders[userId] == nil else { return }
        guard let url = URL(string: NetworkManager.baseURL + "/v1/users/\(userId.uuidString)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let user = try decoder.decode(User.self, from: data)
            await MainActor.run { self.senders[user.id] = user }
        } catch {
            print("[DEBUG] Error fetching sender: \(error)")
        }
    }

    private func fetchVisionBoard(visionboardId: UUID, token: String) async {
        guard visionBoards[visionboardId] == nil else { return } // Already fetched
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/\(visionboardId.uuidString)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            print("[DEBUG] VisionBoard API response: \(String(data: data, encoding: .utf8) ?? "nil")")
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected date string to be ISO8601-formatted.")
            }
            let result = try decoder.decode(VisionBoardResponse.self, from: data)
            let vb = result.visionboard
            await MainActor.run { self.visionBoards[vb.id] = vb }
        } catch {
            print("[DEBUG] Error fetching vision board: \(error)")
        }
    }

    private func fetchGenreAndVisionBoard(genreId: UUID, token: String) async {
        guard genres[genreId] == nil else { return }
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/genres/\(genreId.uuidString)/with-assignments") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            print("[DEBUG] GenreWithAssignments API response: \(String(data: data, encoding: .utf8) ?? "nil")")
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected date string to be ISO8601-formatted.")
            }
            let result = try decoder.decode(GenreWithAssignmentsResponse.self, from: data)
            let genre = result.genre
            await MainActor.run { self.genres[genre.id] = genre }
            await fetchVisionBoard(visionboardId: genre.visionboardId, token: token)
        } catch {
            print("[DEBUG] Error fetching genre/vision board: \(error)")
        }
    }

    func respondToInvitation(invitation: Invitation, response: String, data: [String: Any]? = nil) async {
        guard let token = KeychainHelper.get("accessToken"), !token.isEmpty else { return }
        let urlString = NetworkManager.baseURL + "/v1/visionboard/invitations/\(invitation.id)/respond?response=\(response.lowercased())"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let data = data {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["data": data])
        }
        do {
            let (data, httpResponse) = try await NetworkManager.shared.authorizedRequest(request)
            print("[DEBUG] Invitation respond API response: \(String(data: data, encoding: .utf8) ?? "nil")")
            guard let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            // Update status locally
            if let idx = self.invitations.firstIndex(where: { $0.id == invitation.id }) {
                await MainActor.run { self.invitations[idx].status = response.lowercased() }
            }
        } catch {
            print("[DEBUG] Error responding to invitation: \(error)")
        }
    }
}

// MARK: - Vision Board Detail Logic (moved from VisionDetailView)

extension Creatist {
    // Fetch genres and assignments for a vision board
    func fetchGenresAndAssignments(for board: VisionBoard) async -> [GenreWithAssignments] {
        guard let token = KeychainHelper.get("accessToken"), !token.isEmpty else { return [] }
        guard let genresUrl = URL(string: NetworkManager.baseURL + "/v1/visionboard/\(board.id.uuidString.lowercased())/with-genres") else { return [] }
        var genresRequest = URLRequest(url: genresUrl)
        genresRequest.httpMethod = "GET"
        genresRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (genresData, genresResponse) = try await NetworkManager.shared.authorizedRequest(genresRequest)
            guard let genresHttp = genresResponse as? HTTPURLResponse, genresHttp.statusCode == 200 else { return [] }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected date string to be ISO8601-formatted.")
            }
            struct GenresResponse: Codable { let visionboard: VisionBoardWithGenres }
            let result = try decoder.decode(GenresResponse.self, from: genresData)
            var genresWithAssignments: [GenreWithAssignments] = []
            for genre in result.visionboard.genres {
                guard let genreAssignmentsUrl = URL(string: NetworkManager.baseURL + "/v1/visionboard/genres/\(genre.id.uuidString)/with-assignments") else { continue }
                var genreAssignmentsRequest = URLRequest(url: genreAssignmentsUrl)
                genreAssignmentsRequest.httpMethod = "GET"
                genreAssignmentsRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                do {
                    let (assignmentsData, assignmentsResponse) = try await NetworkManager.shared.authorizedRequest(genreAssignmentsRequest)
                    guard let assignmentsHttp = assignmentsResponse as? HTTPURLResponse, assignmentsHttp.statusCode == 200 else { continue }
                    struct GenreWithAssignmentsResponse: Codable { let genre: GenreWithAssignments }
                    let assignmentsResult = try decoder.decode(GenreWithAssignmentsResponse.self, from: assignmentsData)
                    genresWithAssignments.append(assignmentsResult.genre)
                } catch {
                    print("[DEBUG] Error fetching assignments for genre \(genre.id): \(error)")
                }
            }
            return genresWithAssignments
        } catch {
            print("[DEBUG] Error fetching genres/assignments: \(error)")
            return []
        }
    }

    // Start a vision board
    func startVision(board: VisionBoard) async -> Bool {
        guard let token = KeychainHelper.get("accessToken"), !token.isEmpty else { return false }
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/\(board.id.uuidString.lowercased())") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let update = VisionBoardUpdate(status: .active)
        guard let body = try? JSONEncoder().encode(update) else { return false }
        request.httpBody = body
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return false }
            return true
        } catch {
            print("[DEBUG] Error starting vision: \(error)")
            return false
        }
    }

    // Remind a user (simulate network delay for now)
    func remindUser(assignment: GenreAssignment) async -> Bool {
        // TODO: Call backend notification endpoint to resend invite
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
        return true
    }

    // Add assignment and invite a user
    func addAssignmentAndInvite(genreId: UUID, user: User, board: VisionBoard) async -> Bool {
        guard let token = KeychainHelper.get("accessToken"), !token.isEmpty else { return false }
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/assignments") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Use default work/payment type for now
        let assignmentData: [String: Any] = [
            "genre_id": genreId.uuidString,
            "user_id": user.id.uuidString,
            "work_type": "Online",
            "payment_type": "Paid",
            "payment_amount": 0,
            "currency": "USD"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: assignmentData)
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return false }
            // (Assume backend sends invite on assignment creation)
            return true
        } catch {
            print("[DEBUG] Error adding assignment: \(error)")
            return false
        }
    }
}
