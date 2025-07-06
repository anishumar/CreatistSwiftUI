import Foundation

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
        if let response: ArtistsResponse = await NetworkManager.shared.get(url: url) {
            return response.artists
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
            let visionBoardData: [String: Any] = [
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
