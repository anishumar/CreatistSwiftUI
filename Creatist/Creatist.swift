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
}
