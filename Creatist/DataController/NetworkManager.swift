import Foundation
import OSLog

private let logger: Logger = .init(subsystem: "com.None.NetworkManager", category: "Network")

// Production logging
private func log(_ message: String, level: ProductionLogger.LogLevel = .info) {
    ProductionLogger.log(message, level: level)
}
private let endpoint = EnvironmentConfig.shared.apiBaseURL

enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH
}

struct TokenRefreshRequest: Codable {
    let refresh_token: String
}

struct TokenRefreshResponse: Codable {
    let message: String
    let access_token: String
    let token_type: String?
    let expires_in: Int?
}

// MARK: - Token Monitor
class TokenMonitor: ObservableObject {
    static let shared = TokenMonitor()
    private var refreshTimer: Timer?
    private let refreshBuffer: TimeInterval = 5 * 60 // 5 minutes before expiry
    
    private init() {}
    
    func startMonitoring() {
        stopMonitoring()
        
        guard let expirationTime = getTokenExpirationTime() else {
            return
        }
        
        let timeUntilRefresh = expirationTime.timeIntervalSinceNow - refreshBuffer
        
        if timeUntilRefresh > 0 {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: timeUntilRefresh, repeats: false) { [weak self] _ in
                Task {
                    await self?.refreshTokenIfNeeded()
                }
            }
        } else {
            Task {
                await refreshTokenIfNeeded()
            }
        }
    }
    
    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func refreshTokenIfNeeded() async {
        guard let expirationTime = getTokenExpirationTime() else { return }
        
        let timeUntilExpiry = expirationTime.timeIntervalSinceNow
        
        if timeUntilExpiry <= refreshBuffer {
            let success = await NetworkManager.shared.refreshToken()
            if success {
                await MainActor.run {
                    startMonitoring()
                }
            }
        }
    }
    
    private func getTokenExpirationTime() -> Date? {
        guard let expirationString = KeychainHelper.get("tokenExpirationTime") else { return nil }
        let expirationTime = Date(timeIntervalSince1970: Double(expirationString) ?? 0)
        return expirationTime
    }
    
    // MARK: - Public Helper Methods
    

}

actor NetworkManager {
    // MARK: Public
    public static let shared: NetworkManager = .init()
    public static let baseURL = endpoint

    // MARK: Internal
    func get<T: Codable>(url: String, queryParameters: [String: Any]? = nil) async -> T? {
        log("🌐 NetworkManager: GET \(url)")
        if let queryParameters = queryParameters {
            log("🌐 NetworkManager: Query parameters: \(queryParameters)")
        }
        
        let result: T? = await request(url: url, method: "GET", queryParameters: queryParameters)
        
        if let result = result {
            log("🌐 NetworkManager: GET \(url) - SUCCESS")
        } else {
            log("🌐 NetworkManager: GET \(url) - FAILED", level: .error)
        }
        
        return result
    }

    func post<T: Codable>(url: String, body: Data?) async -> T? {
        log("🌐 NetworkManager: POST \(url)")
        log("🌐 NetworkManager: Body: \(String(data: body ?? Data(), encoding: .utf8) ?? "nil")")
        
        let result: T? = await request(url: url, method: "POST", body: body)
        
        if let result {
            log("🌐 NetworkManager: POST \(url) - SUCCESS")
        } else {
            log("🌐 NetworkManager: POST \(url) - FAILED", level: .error)
        }
        
        return result
    }

    func put<T: Codable>(url: String, body: Data?) async -> T? {
        return await request(url: url, method: "PUT", body: body)
    }

    func delete(url: String, body: Data?) async -> Bool {
        let result: Bool? = await request(url: url, method: "DELETE", body: body)
        return result != nil
    }

    func patch<T: Codable>(url: String, body: Data?) async -> T? {
        return await request(url: url, method: "PATCH", body: body)
    }
    
    // MARK: - Token Management
    
    /// Check if the current access token is expired or will expire within the buffer time
    private func isTokenExpiredOrExpiringSoon(buffer: TimeInterval = 5 * 60) async -> Bool {
        guard let expirationString = KeychainHelper.get("tokenExpirationTime") else { return true }
        let expirationTime = Date(timeIntervalSince1970: Double(expirationString) ?? 0)
        
        let timeUntilExpiry = expirationTime.timeIntervalSinceNow
        return timeUntilExpiry <= buffer
    }

    // MARK: Private
    private var delimiter: String = "\n"

    private func request<T: Codable>(url: String = "", method: String, body: Data? = nil, queryParameters: [String: Any]? = nil, retryOn401: Bool = true) async -> T? {
        var urlString = "\(EnvironmentConfig.shared.apiBaseURL)\(url)"

        if let queryParameters, !queryParameters.isEmpty {
            var urlComponents = URLComponents(string: urlString)
            urlComponents?.queryItems = queryParameters.map {
                return URLQueryItem(name: $0.key, value: "\($0.value)")
            }
            urlString = urlComponents?.url?.absoluteString ?? urlString
        }

        guard let url = URL(string: urlString) else {
            fatalError("error")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        if let body {
            urlRequest.httpBody = body
            print("Sending request to \(urlString) with body: \(String(data: body, encoding: .utf8) ?? "<nil>")")
        }

        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Only add Authorization header and attempt refresh for authenticated endpoints
        // Exclude unauthenticated auth endpoints like otp, signup, and signin
        if !urlString.contains("/auth/otp") && !urlString.contains("/auth/signup") && !urlString.contains("/auth/signin") {
            // Proactively refresh token if it's expired or expiring soon
            if await isTokenExpiredOrExpiringSoon() {
                let refreshed = await refreshToken()
                if !refreshed {
                    return nil
                }
            }
            
            if let accessToken = KeychainHelper.get("accessToken") {
                urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }

            if httpResponse.statusCode != 200 {
                // HTTP error - status code not 200
            }

            if httpResponse.statusCode == 401 && retryOn401 {
                // Try to refresh token
                let refreshed = await refreshToken()
                if refreshed {
                    // Retry the original request ONCE
                    return await request(url: urlString.replacingOccurrences(of: endpoint, with: ""), method: method, body: body, queryParameters: queryParameters, retryOn401: false)
                } else {
                    // Log out user, clear tokens, redirect to login
                    KeychainHelper.remove("accessToken")
                    KeychainHelper.remove("refreshToken")
                    KeychainHelper.remove("tokenExpirationTime")
                    print("Token refresh failed. Logging out user.")
                    return nil
                }
            }

            guard httpResponse.statusCode == 200 else {
                return nil
            }

            let decoder = JSONDecoder()
            
            // Try multiple date decoding strategies
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try ISO8601 first
                if let date = ISO8601DateFormatter().date(from: dateString) {
                    return date
                }
                
                // Try with milliseconds
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                // Try without milliseconds
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                // Try just date
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date string does not match expected format: \(dateString)")
            }

            do {
                let result = try decoder.decode(T.self, from: data)
                return result
            } catch {
                return nil
            }

        } catch {
            logger.error("Request error for URL: \(urlString, privacy: .public), error: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func refreshToken() async -> Bool {
        guard let refreshToken = KeychainHelper.get("refreshToken") else { return false }
        guard let url = URL(string: EnvironmentConfig.shared.apiBaseURL + "/auth/refresh") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let refreshBody = TokenRefreshRequest(refresh_token: refreshToken)
        guard let body = try? JSONEncoder().encode(refreshBody) else { return false }
        request.httpBody = body
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return false }
            let result = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
            KeychainHelper.set(result.access_token, forKey: "accessToken")
            
            // Store new expiration time if provided
            if let expiresIn = result.expires_in {
                let expirationTime = Date().addingTimeInterval(TimeInterval(expiresIn))
                KeychainHelper.set(String(expirationTime.timeIntervalSince1970), forKey: "tokenExpirationTime")
                print("Token refreshed successfully. New expiration: \(expirationTime)")
            } else {
                print("Token refreshed successfully.")
            }
            
            return true
        } catch {
            print("Token refresh error: \(error)")
            return false
        }
    }

    func patch(url: String, body: Data?) async -> Response? {
        guard let url = URL(string: EnvironmentConfig.shared.apiBaseURL + url) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainHelper.get("accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try? JSONDecoder().decode(Response.self, from: data)
        } catch {
            print("PATCH error: \(error)")
            return nil
        }
    }

    /// Makes an authorized REST request, auto-refreshing the access token on 401.
    func authorizedRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var req = request
        if req.value(forHTTPHeaderField: "Authorization") == nil {
            req.setValue("Bearer \(KeychainHelper.get("accessToken") ?? "")", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            // Try to refresh token
            let refreshed = await NetworkManager.shared.refreshToken()
            if refreshed {
                var retryReq = request
                retryReq.setValue("Bearer \(KeychainHelper.get("accessToken") ?? "")", forHTTPHeaderField: "Authorization")
                return try await URLSession.shared.data(for: retryReq)
            } else {
                throw URLError(.userAuthenticationRequired)
            }
        }
        return (data, response)
    }
} 
