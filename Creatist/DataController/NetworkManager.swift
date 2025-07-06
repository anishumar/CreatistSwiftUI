import Foundation
import OSLog

private let logger: Logger = .init(subsystem: "com.None.NetworkManager", category: "Network")
private let endpoint = "http://localhost:8080"

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

actor NetworkManager {
    // MARK: Public
    public static let shared: NetworkManager = .init()

    // MARK: Internal
    func get<T: Codable>(url: String, queryParameters: [String: Any]? = nil) async -> T? {
        return await request(url: url, method: "GET", queryParameters: queryParameters)
    }

    func post<T: Codable>(url: String, body: Data?) async -> T? {
        return await request(url: url, method: "POST", body: body)
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

    // MARK: Private
    private var delimiter: String = "\n"

    private func request<T: Codable>(url: String = "", method: String, body: Data? = nil, queryParameters: [String: Any]? = nil, retryOn401: Bool = true) async -> T? {
        var urlString = "\(endpoint)\(url)"

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
        // Only add Authorization header if not calling OTP or signup endpoints
        if !urlString.contains("/auth/otp") && !urlString.contains("/auth/signup") {
            if let accessToken = KeychainHelper.get("accessToken") {
                urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
        }

        do {
            logger.debug("Preparing request: method=\(method, privacy: .public), url=\(url, privacy: .public), queryParameters=\(String(describing: queryParameters), privacy: .public), body=\(String(describing: body?.count), privacy: .public)")
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let response = response as? HTTPURLResponse else {
                logger.error("Response is not HTTPURLResponse.")
                return nil
            }

            logger.debug("Response fetched, url=\(url, privacy: .public), status=\(response.statusCode, privacy: .public)")

            if response.statusCode == 401 && retryOn401 {
                // Try to refresh token
                let refreshed = await refreshToken()
                if refreshed {
                    // Retry the original request ONCE
                    return await request(url: urlString.replacingOccurrences(of: endpoint, with: ""), method: method, body: body, queryParameters: queryParameters, retryOn401: false)
                } else {
                    // Log out user, clear tokens, redirect to login
                    KeychainHelper.remove("accessToken")
                    KeychainHelper.remove("refreshToken")
                    print("Token refresh failed. Logging out user.")
                    return nil
                }
            }

            guard response.statusCode == 200 else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            return try decoder.decode(T.self, from: data)

        } catch {
            logger.error("Request error for URL: \(urlString, privacy: .public), error: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func refreshToken() async -> Bool {
        guard let refreshToken = KeychainHelper.get("refreshToken") else { return false }
        guard let url = URL(string: endpoint + "/auth/refresh") else { return false }
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
            print("Token refreshed successfully.")
            return true
        } catch {
            print("Token refresh error: \(error)")
            return false
        }
    }

    func patch(url: String, body: Data?) async -> Response? {
        guard let url = URL(string: endpoint + url) else { return nil }
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
} 