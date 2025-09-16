import Foundation
import Combine

// Import all data models from DataModels.swift
// (No data model structs/enums should be defined here)

@MainActor
class Creatist {
    public static var shared: Creatist = .init()
    var user: User?
    // In-memory cache for vision board users
    var visionBoardUserCache: [UUID: [User]] = [:]
    
    private func _login(email: String, password: String) async -> (LoginResponse?, Int) {
        let credentials = Credential(email: email, password: password)
        guard let data = credentials.toData() else {
            return (nil, 0)
        }
        let (responseData, statusCode) = await NetworkManager.shared.authRequest(url: "/auth/signin", method: .POST, body: data)
        
        guard let data = responseData else {
            return (nil, statusCode)
        }
        
        do {
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            return (loginResponse, statusCode)
        } catch {
            print("Login decode error: \(error)")
            return (nil, statusCode)
        }
    }
    
    func clearUserCache() {
                visionBoardUserCache.removeAll()
            }
    
    func login(email: String, password: String) async -> LoginResult {
        let (loginResponse, statusCode) = await _login(email: email, password: password)
        
        switch statusCode {
        case 200:
            if loginResponse?.message == "success",
               let accessToken = loginResponse?.access_token,
               let refreshToken = loginResponse?.refresh_token {
                KeychainHelper.set(email, forKey: "email")
                KeychainHelper.set(password, forKey: "password")
                KeychainHelper.set(accessToken, forKey: "accessToken")
                KeychainHelper.set(refreshToken, forKey: "refreshToken")
                
                // Store token expiration time if provided
                if let expiresIn = loginResponse?.expires_in {
                    let expirationTime = Date().addingTimeInterval(TimeInterval(expiresIn))
                    KeychainHelper.set(String(expirationTime.timeIntervalSince1970), forKey: "tokenExpirationTime")
                    print("🔐 Login: Token expiration set to \(expirationTime)")
                }
                
                await self.fetch()
                return .success
            }
            return .failure("Login failed")
        case 401:
            return .failure("Invalid email or password")
        case 403:
            return .requiresVerification
        default:
            return .failure("Login failed")
        }
    }
    
    func autologin() async -> Bool? {
        let email = KeychainHelper.get("email")
        let password = KeychainHelper.get("password")
        guard let email, let password else {
            return false
        }
        let result = await login(email: email, password: password)
        switch result {
        case .success:
            return true
        case .failure, .requiresVerification:
            return false
        }
    }
    
    func signup(_ user: User) async -> SignupResult {
        guard let data = user.toData() else {
            return .failure("Invalid user data")
        }
        let (responseData, statusCode) = await NetworkManager.shared.authRequest(url: "/auth/signup", method: .POST, body: data)
        
        guard let data = responseData else {
            return .failure("Signup failed")
        }
        
        do {
            // Try to decode as new SignupResponse first
            if let signupResponse = try? JSONDecoder().decode(SignupResponse.self, from: data) {
                if signupResponse.requiresVerification {
                    // Store user credentials for later use
                    KeychainHelper.set(user.email, forKey: "email")
                    KeychainHelper.set(user.password, forKey: "password")
                    
                    // Store temp_id for OTP verification
                    if let tempId = signupResponse.temp_id {
                        KeychainHelper.set(tempId, forKey: "temp_id")
                    }
                    
                    // Send OTP after successful signup
                    let otpSent = await requestOTP()
                    if otpSent == true {
                        return .requiresVerification
                    } else {
                        return .failure("Failed to send OTP")
                    }
                } else {
                    // User already exists or other error
                    return .failure(signupResponse.message)
                }
            } else {
                // Fallback to old Response format
                let response = try JSONDecoder().decode(Response.self, from: data)
                if response.message == "success" {
                    KeychainHelper.set(user.email, forKey: "email")
                    KeychainHelper.set(user.password, forKey: "password")
                    
                    // For old backend, assume new users need verification
                    return .requiresVerification
                } else {
                    return .failure(response.message)
                }
            }
        } catch {
            print("Signup decode error: \(error)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            return .failure("Signup failed")
        }
    }
    
    func fetch() async {
        let user: User? = await NetworkManager.shared.get(url: "/auth/fetch")
        if let user {
            self.user = user
            // Check for user change and clear caches if needed
            await CacheManager.shared.onUserLogin()
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
        return await NetworkManager.shared.post<Bool>(url: "/auth/otp", body: data) ?? false
    }
    
    func requestForgotPasswordOTP(email: String) async -> ForgotPasswordResult {
        let forgotRequest = ForgotPasswordRequest(email: email)
        guard let data = try? JSONEncoder().encode(forgotRequest) else {
            return .failure("Invalid request data")
        }
        
        let (responseData, statusCode) = await NetworkManager.shared.authRequest(url: "/auth/forgot-password", method: .POST, body: data)
        
        guard let data = responseData else {
            return .failure("Request failed")
        }
        
        do {
            let response = try JSONDecoder().decode(ForgotPasswordResponse.self, from: data)
            if response.requiresVerification {
                // Store email and temp_id for password reset
                KeychainHelper.set(email, forKey: "reset_email")
                if let tempId = response.temp_id {
                    KeychainHelper.set(tempId, forKey: "reset_temp_id")
                }
                
                // OTP is already sent by the backend, no need to send again
                return .success
            } else {
                return .failure(response.message)
            }
        } catch {
            print("Forgot password decode error: \(error)")
            // Try to decode as error response
            if let errorResponse = try? JSONDecoder().decode(ForgotPasswordResponse.self, from: data) {
                return .failure(errorResponse.message)
            }
            return .failure("Request failed")
        }
    }
    
    func resetPassword(newPassword: String, otp: String) async -> ResetPasswordResult {
        let email = KeychainHelper.get("reset_email")
        guard let email else {
            return .failure("Email not found")
        }
        
        let resetRequest = ResetPasswordRequest(email: email, new_password: newPassword, otp: otp)
        guard let data = try? JSONEncoder().encode(resetRequest) else {
            return .failure("Invalid request data")
        }
        
        let (responseData, statusCode) = await NetworkManager.shared.authRequest(url: "/auth/reset-password", method: .POST, body: data)
        
        guard let data = responseData else {
            return .failure("Reset failed")
        }
        
        do {
            let response = try JSONDecoder().decode(ResetPasswordResponse.self, from: data)
            if response.success == true {
                // Clear reset data
                KeychainHelper.remove("reset_email")
                KeychainHelper.remove("reset_temp_id")
                return .success
            } else {
                return .failure(response.message)
            }
        } catch {
            print("Reset password decode error: \(error)")
            return .failure("Reset failed")
        }
    }
    
    func verifyOTP(_ otp: String) async -> OTPResult {
        let email = KeychainHelper.get("email")
        guard let email else {
            return .failure("Email not found")
        }
        
        // Check if this is a new user registration (has temp_id)
        let tempId = KeychainHelper.get("temp_id")
        let otpRequest = OTPRequest(email_address: email, otp: otp, temp_id: tempId)
        guard let data = try? JSONEncoder().encode(otpRequest) else {
            return .failure("Invalid OTP data")
        }
        
        let (responseData, statusCode) = await NetworkManager.shared.authRequest(url: "/auth/otp/verify", method: .POST, body: data)
        
        guard let data = responseData else {
            return .failure("OTP verification failed")
        }
        
        do {
            let response = try JSONDecoder().decode(Response.self, from: data)
            if response.message == "success" || response.message == "Registration completed successfully! You can now login." {
                // Clear temp_id after successful verification
                KeychainHelper.remove("temp_id")
                
                // After successful OTP verification, automatically attempt login
                let password = KeychainHelper.get("password")
                if let password = password {
                    let loginResult = await login(email: email, password: password)
                    switch loginResult {
                    case .success:
                        return .success
                    case .failure(let error):
                        return .failure("OTP verified but login failed: \(error)")
                    case .requiresVerification:
                        return .failure("OTP verification failed")
                    }
                } else {
                    return .failure("Password not found")
                }
            } else {
                return .failure(response.message)
            }
        } catch {
            print("OTP verification decode error: \(error)")
            return .failure("OTP verification failed")
        }
    }
    
    func verifyOTP(email: String, otp: String) async -> OTPResult {
        // For forgot password flow - verify OTP with email
        let otpRequest = OTPRequest(email_address: email, otp: otp, temp_id: nil)
        guard let data = try? JSONEncoder().encode(otpRequest) else {
            return .failure("Invalid OTP data")
        }
        
        let (responseData, statusCode) = await NetworkManager.shared.authRequest(url: "/auth/otp/verify", method: .POST, body: data)
        
        guard let data = responseData else {
            return .failure("OTP verification failed")
        }
        
        do {
            let response = try JSONDecoder().decode(Response.self, from: data)
            if response.message == "success" || response.message == "Registration completed successfully! You can now login." || response.message == "Email verified successfully" {
                return .success
            } else {
                return .failure(response.message)
            }
        } catch {
            print("OTP verification decode error: \(error)")
            return .failure("OTP verification failed")
        }
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
    
    func searchUsers(query: String) async -> [User] {
        // Fetch users from all genres and filter locally
        var allUsers: [User] = []
        
        // Get users from each genre
        for genre in UserGenre.allCases {
            let users = await fetchUsers(for: genre)
            allUsers.append(contentsOf: users)
        }
        
        // Remove duplicates based on user ID
        let uniqueUsers = Array(Set(allUsers.map { $0.id })).compactMap { userId in
            allUsers.first { $0.id == userId }
        }
        
        // Filter by search query
        let filteredUsers = uniqueUsers.filter { user in
            user.name.localizedCaseInsensitiveContains(query) ||
            (user.username?.localizedCaseInsensitiveContains(query) ?? false)
        }
        
        return filteredUsers
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
        let success = response?.message == "success"
        
        // Invalidate following feed cache since following list changed
        if success {
            CacheManager.shared.invalidateCache(for: .following)
        }
        
        return success
    }
    
    func unfollowUser(userId: String) async -> Bool {
        let success = await NetworkManager.shared.delete(url: "/v1/unfollow/\(userId)", body: nil)
        
        // Invalidate following feed cache since following list changed
        if success {
            CacheManager.shared.invalidateCache(for: .following)
        }
        
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
            guard let currentUser = self.user else {
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
                return false
            }
            let visionBoardId = visionBoardResponse.visionboard.id
            
            // Step 2: Create genres for the vision board
            var createdGenres: [Genre] = []
            for (index, genreCreate) in genres.enumerated() {
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
                    return false
                }
                createdGenres.append(genreResponse.genre)
            }
            
            // Step 3: Create assignments for each genre
            for (index, assignment) in assignments.enumerated() {
                // Find the corresponding genre for this assignment
                guard let genreIndex = createdGenres.firstIndex(where: { $0.name == assignment.genreName }) else {
                    return false
                }
                
                let genreId = createdGenres[genreIndex].id
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
                    return false
                }
            }
            
            return true
            
        } catch {
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
            return [] 
        }
        let url = "/v1/visionboard?created_by=\(user.id.uuidString)"
        
        if let response: VisionBoardsResponse = await NetworkManager.shared.get(url: url) {
            return response.visionboards
        }
        return []
    }

    // Fetch all vision boards where the user is a partner (not creator)
    func fetchPartnerVisionBoards() async -> [VisionBoard] {
        guard let user = self.user else { 
            return [] 
        }
        let url = "/v1/visionboard?partner_id=\(user.id.uuidString)"
        
        if let response: VisionBoardsResponse = await NetworkManager.shared.get(url: url) {
            return response.visionboards
        }
        return []
    }

    // Fetch all users assigned to a specific vision board
    func fetchVisionBoardUsers(visionBoardId: UUID) async -> [User] {
        let url = "/v1/visionboard/\(visionBoardId.uuidString.lowercased())/users"
        
        if let response: VisionBoardUsersResponse = await NetworkManager.shared.get(url: url) {
            return response.users
        }
        return []
    }

    // Update user profile via PATCH /v1/users
    func updateUserProfile(_ user: User) async -> Bool {
        guard let token = KeychainHelper.get("accessToken"),
              let url = URL(string: NetworkManager.baseURL + "/v1/users") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any?] = [
            "name": user.name,
            "username": user.username,
            "description": user.description,
            "age": user.age,
            "dob": user.dob,
            "genres": user.genres?.map { $0.rawValue },
            "payment_mode": user.paymentMode?.rawValue,
            "work_mode": user.workMode?.rawValue,
            "profile_image_url": user.profileImageUrl
        ]
        let filteredBody = body.compactMapValues { $0 }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: filteredBody) else { return false }
        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Failed to update user: \(String(data: data, encoding: .utf8) ?? "nil")")
                return false
            }
            // Optionally update Creatist.shared.user with the new data here
            return true
        } catch {
            print("Error updating user: \(error)")
            return false
        }
    }

    // MARK: - Drafts & Comments
    func fetchDrafts(forVisionBoardId visionboardId: UUID) async -> [Draft] {
        let url = "/v1/visionboard/\(visionboardId.uuidString)/drafts"
        if let response: [Draft] = await NetworkManager.shared.get(url: url) {
            return response
        }
        return []
    }

    func uploadDraft(for visionboardId: UUID, mediaUrl: String, mediaType: String, description: String? = nil) async -> Draft? {
        guard let user = self.user else { return nil }
        var body: [String: Any] = [
            "visionboard_id": visionboardId.uuidString, // <-- required by backend
            "user_id": user.id.uuidString,
            "media_url": mediaUrl,
            "media_type": mediaType
        ]
        if let description = description {
            body["description"] = description
        }
        let data = try? JSONSerialization.data(withJSONObject: body)
        let url = "/v1/visionboard/\(visionboardId.uuidString)/drafts"
        if let response: Draft = await NetworkManager.shared.post(url: url, body: data) {
            return response
        }
        return nil
    }

    func fetchDraftComments(forDraftId draftId: UUID) async -> [DraftComment] {
        let url = "/v1/visionboard/drafts/\(draftId.uuidString)/comments"
        if let response: [DraftComment] = await NetworkManager.shared.get(url: url) {
            return response
        }
        return []
    }

    func addDraftComment(draftId: UUID, comment: String) async -> DraftComment? {
        guard let user = self.user else { return nil }
        let body: [String: Any] = [
            "draft_id": draftId.uuidString, // <-- required by backend
            "user_id": user.id.uuidString,
            "comment": comment
        ]
        let data = try? JSONSerialization.data(withJSONObject: body)
        let url = "/v1/visionboard/drafts/\(draftId.uuidString)/comments"
        if let response: DraftComment = await NetworkManager.shared.post(url: url, body: data) {
            return response
        }
        return nil
    }

    // MARK: - Drafts & Comments (extended)
    func updateDraft(draftId: UUID, mediaUrl: String?, mediaType: String?, description: String?) async -> Draft? {
        var body: [String: Any] = [:]
        if let mediaUrl = mediaUrl { body["media_url"] = mediaUrl }
        if let mediaType = mediaType { body["media_type"] = mediaType }
        if let description = description { body["description"] = description }
        let data = try? JSONSerialization.data(withJSONObject: body)
        let url = "/v1/visionboard/drafts/\(draftId.uuidString)"
        if let response: Draft = await NetworkManager.shared.patch(url: url, body: data) {
            return response
        }
        return nil
    }

    func deleteDraft(draftId: UUID) async -> Bool {
        let url = "/v1/visionboard/drafts/\(draftId.uuidString)"
        return await NetworkManager.shared.delete(url: url, body: nil)
    }

    func updateDraftComment(commentId: UUID, comment: String) async -> DraftComment? {
        let body: [String: Any] = ["comment": comment]
        let data = try? JSONSerialization.data(withJSONObject: body)
        let url = "/v1/visionboard/draft-comments/\(commentId.uuidString)"
        if let response: DraftComment = await NetworkManager.shared.patch(url: url, body: data) {
            return response
        }
        return nil
    }

    func deleteDraftComment(commentId: UUID) async -> Bool {
        let url = "/v1/visionboard/draft-comments/\(commentId.uuidString)"
        return await NetworkManager.shared.delete(url: url, body: nil)
    }
}

// MARK: - Notification ViewModel

class NotificationViewModel: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    private var cancellables = Set<AnyCancellable>()
    
    func fetchNotifications() async {
        let accessToken = KeychainHelper.get("accessToken")
        guard let token = accessToken, !token.isEmpty else {
            await MainActor.run { self.errorMessage = "Not logged in. Please sign in again." }
            return
        }
        await MainActor.run { self.isLoading = true }
        defer { Task { await MainActor.run { self.isLoading = false } } }
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/notifications") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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
            await MainActor.run { self.notifications = notifications }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }
    
    func respond(to notification: NotificationItem, response: String, comment: String) async {
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/notifications/\(notification.id)/respond") else { return }
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
            guard let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { self.errorMessage = "Failed to respond to notification." }
                return
            }
            if let idx = self.notifications.firstIndex(where: { $0.id == notification.id }) {
                await MainActor.run { self.notifications[idx].status = response }
            }
        } catch {
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
        let accessToken = KeychainHelper.get("accessToken")
        guard let token = accessToken, !token.isEmpty else {
            await MainActor.run { self.errorMessage = "Not logged in. Please sign in again." }
            return
        }
        await MainActor.run { self.isLoading = true }
        defer { Task { await MainActor.run { self.isLoading = false } } }
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/invitations/user?status=pending") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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
            guard let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            // Update status locally
            if let idx = self.invitations.firstIndex(where: { $0.id == invitation.id }) {
                await MainActor.run { self.invitations[idx].status = response.lowercased() }
            }
        } catch {
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
                }
            }
            return genresWithAssignments
        } catch {
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
            return false
        }
    }

    // Fetch all genre names for a vision board
    func fetchGenresForVisionBoard(_ visionboardId: UUID) async -> [String] {
        guard let token = KeychainHelper.get("accessToken"), !token.isEmpty else { return [] }
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/\(visionboardId.uuidString.lowercased())/with-genres") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
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
            let result = try decoder.decode(GenresResponse.self, from: data)
            return result.visionboard.genres.map { $0.name }
        } catch {
            return []
        }
    }

    /// Builds the collaborators array for a visionboard by fetching all collaborators (with their roles) from the new endpoint.
    func buildCollaboratorsForVisionboard(visionboardId: UUID) async -> [PostCollaboratorCreate] {
        guard let token = KeychainHelper.get("accessToken"), !token.isEmpty else { return [] }
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/\(visionboardId.uuidString)/collaborators") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
            
            // Decode the raw response to get user_id and role
            struct CollaboratorResponse: Codable {
                let user_id: UUID
                let role: String
            }
            
            let collaboratorsResponse = try JSONDecoder().decode([CollaboratorResponse].self, from: data)
            
            // Map genre-based roles to expected post collaborator roles
            return collaboratorsResponse.map { collaborator in
                let mappedRole: String
                switch collaborator.role.lowercased() {
                case "author", "editor", "invited", "collaborator":
                    // These are already valid post collaborator roles
                    mappedRole = collaborator.role.lowercased()
                default:
                    // Map genre names (like "videographer", "actor", etc.) to "collaborator"
                    mappedRole = "collaborator"
                }
                
                return PostCollaboratorCreate(user_id: collaborator.user_id, role: mappedRole)
            }
        } catch {
            return []
        }
    }
}

// MARK: - Post Creation API Integration

struct PostMediaCreate: Codable {
    let url: String
    let type: String // "image" or "video"
    let order: Int
}

struct PostCollaboratorCreate: Codable {
    let user_id: UUID
    let role: String // "author", "editor", etc.
}

struct PostCreate: Codable {
    let caption: String?
    let media: [PostMediaCreate]
    let tags: [String]
    let status: String
    let shared_from_post_id: UUID?
    let visionboard_id: UUID?
}

@MainActor
extension Creatist {
    func createPost(
        caption: String?,
        media: [PostMediaCreate],
        tags: [String],
        status: String = "public",
        sharedFromPostId: UUID? = nil,
        visionboardId: UUID? = nil
    ) async -> UUID? {
        guard let token = KeychainHelper.get("accessToken") else { return nil }
        let post = PostCreate(
            caption: caption,
            media: media,
            tags: tags,
            status: status,
            shared_from_post_id: sharedFromPostId,
            visionboard_id: visionboardId
        )
        guard let data = try? JSONEncoder().encode(post) else { return nil }
        var request = URLRequest(url: URL(string: NetworkManager.baseURL + "/posts")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = data
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Failed to create post: \(String(data: data, encoding: .utf8) ?? "nil")")
                return nil
            }
            let result = try JSONDecoder().decode([String: String].self, from: data)
            return UUID(uuidString: result["post_id"] ?? "")
        } catch {
            print("Error creating post: \(error)")
            return nil
        }
    }

    /// Uploads media for a draft to Supabase Storage and returns the public URL or nil on failure.
    func uploadDraftMedia(data: Data, mediaType: String) async -> String? {
        let maxSize: Int = 25 * 1024 * 1024 // 25 MB
        if data.count > maxSize {
            print("[Creatist] Draft media file is too large (\(data.count) bytes). Max allowed is \(maxSize) bytes.")
            return nil
        }
        let supabaseUrl = EnvironmentConfig.shared.supabaseURL
        let supabaseBucket = "drafts"
        let ext = (mediaType == "video") ? ".mov" : ".jpg"
        let fileName = UUID().uuidString + ext
        let uploadPath = "\(supabaseBucket)/\(fileName)"
        let uploadUrlString = "\(supabaseUrl)/storage/v1/object/\(uploadPath)"
        guard let uploadUrl = URL(string: uploadUrlString) else { return nil }
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(EnvironmentConfig.shared.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(mediaType == "video" ? "video/quicktime" : "image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        do {
            let (respData, resp) = try await URLSession.shared.data(for: request)
            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 || httpResp.statusCode == 201 {
                let publicUrl = "\(supabaseUrl)/storage/v1/object/public/\(supabaseBucket)/\(fileName)"
                return publicUrl
            } else {
                print("[Creatist] Failed to upload draft media. Status: \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
        } catch {
            print("[Creatist] Upload draft media error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Uploads media for a post to Supabase Storage and returns the public URL or nil on failure.
    func uploadPostMedia(data: Data, mediaType: String, userId: UUID, postId: UUID) async -> String? {
        let maxSize: Int = 25 * 1024 * 1024 // 25 MB for self posts
        if data.count > maxSize {
            print("[Creatist] Post media file is too large (\(data.count) bytes). Max allowed is \(maxSize) bytes.")
            return nil
        }
        let supabaseUrl = EnvironmentConfig.shared.supabaseURL
        let ext = (mediaType == "video") ? ".mov" : ".jpg"
        let fileName = UUID().uuidString + ext
        let uploadPath = "posts/\(userId.uuidString)/\(postId.uuidString)/\(fileName)"
        let uploadUrlString = "\(supabaseUrl)/storage/v1/object/\(uploadPath)"
        guard let uploadUrl = URL(string: uploadUrlString) else { return nil }
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(EnvironmentConfig.shared.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(mediaType == "video" ? "video/quicktime" : "image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        do {
            let (respData, resp) = try await URLSession.shared.data(for: request)
            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 || httpResp.statusCode == 201 {
                let publicUrl = "\(supabaseUrl)/storage/v1/object/public/posts/\(userId.uuidString)/\(postId.uuidString)/\(fileName)"
                return publicUrl
            } else {
                print("[Creatist] Failed to upload post media. Status: \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
        } catch {
            print("[Creatist] Upload post media error: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Feed Fetching (Trending & Following)

extension Creatist {
    // Trending feed with pagination
    func fetchTrendingPosts(limit: Int = 10, cursor: String? = nil) async -> PaginatedPosts {
        var url = "/posts/trending?limit=\(limit)"
        
        if let cursor = cursor {
            // Send cursor as JSON object in URL parameter (URL-encoded)
            let cursorJson = "{\"cursor\":\"\(cursor)\"}"
            if let encodedCursor = cursorJson.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                url += "&cursor=\(encodedCursor)"
            }
        }
        
        if let response: PaginatedPosts = await NetworkManager.shared.get(url: url) {
            return response
        }
        
        return PaginatedPosts(posts: [], nextCursor: nil)
    }

    // Following feed with pagination
    func fetchFollowingFeed(limit: Int = 10, cursor: String? = nil) async -> PaginatedPosts {
        var url = "/posts/following?limit=\(limit)"
        
        if let cursor = cursor {
            // Send cursor as JSON object in URL parameter (URL-encoded)
            let cursorJson = "{\"cursor\":\"\(cursor)\"}"
            if let encodedCursor = cursorJson.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                url += "&cursor=\(encodedCursor)"
            }
        }
        
        if let response: PaginatedPosts = await NetworkManager.shared.get(url: url) {
            return response
        }
        
        return PaginatedPosts(posts: [], nextCursor: nil)
    }

    // Fetch a user by their UUID
    func fetchUserById(userId: UUID) async -> User? {
        let url = "/v1/users/\(userId.uuidString)"
        if let response: UserResponse = await NetworkManager.shared.get(url: url) {
            return response.user
        }
        return nil
    }

    // Like a post
    func likePost(postId: UUID) async -> Bool {
        let url = "/posts/\(postId.uuidString)/like"
        let response: Response? = await NetworkManager.shared.post(url: url, body: nil)
        return response?.message == "Liked"
    }

    // Unlike a post
    func unlikePost(postId: UUID) async -> Bool {
        let url = "/posts/\(postId.uuidString)/like"
        return await NetworkManager.shared.delete(url: url, body: nil)
    }

    // Add a comment
    func addComment(postId: UUID, content: String) async -> PostComment? {
        let url = "/posts/\(postId.uuidString)/comments"
        let comment = ["content": content]
        let data = try? JSONSerialization.data(withJSONObject: comment)
        return await NetworkManager.shared.post(url: url, body: data)
    }

    // Get comments
    func getComments(postId: UUID, limit: Int = 10, cursor: String? = nil) async -> [PostComment] {
        var url = "/posts/\(postId.uuidString)/comments?limit=\(limit)"
        if let cursor = cursor {
            url += "&cursor=\(cursor)"
        }
        if let comments: [PostComment] = await NetworkManager.shared.get(url: url) {
            return comments
        }
        return []
    }

    // Fetch all posts for a user
    func fetchUserPosts(userId: UUID) async -> [PostWithDetails] {
        // Check cache first
        if CacheManager.shared.isUserPostsCacheValid(for: userId),
           let cachedPosts = CacheManager.shared.getCachedUserPosts(for: userId) {
            return cachedPosts
        }
        
        // Fetch from API if cache is invalid or empty
        let url = "/posts/user/\(userId.uuidString)"
        if let posts: [PostWithDetails] = await NetworkManager.shared.get(url: url) {
            // Cache the fetched posts
            CacheManager.shared.cacheUserPosts(posts, for: userId)
            return posts
        }
        
        return []
    }
}
