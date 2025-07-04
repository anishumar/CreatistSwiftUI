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

    private func request<T: Codable>(url: String = "", method: String, body: Data? = nil, queryParameters: [String: Any]? = nil) async -> T? {
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

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            print("Sending request to \(urlString) with body: \(String(data: body, encoding: .utf8) ?? "<nil>")")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Only add Authorization header if not calling OTP or signup endpoints
        if !urlString.contains("/auth/otp") && !urlString.contains("/auth/signup") {
            if let accessToken = KeychainHelper.get("accessToken") {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
        }

        do {
            logger.debug("Preparing request: method=\(method, privacy: .public), url=\(url, privacy: .public), queryParameters=\(String(describing: queryParameters), privacy: .public), body=\(String(describing: body?.count), privacy: .public)")
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let response = response as? HTTPURLResponse else {
                logger.error("Response is not HTTPURLResponse.")
                return nil
            }

            logger.debug("Response fetched, url=\(url, privacy: .public), status=\(response.statusCode, privacy: .public)")

            guard response.statusCode == 200 else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            return try decoder.decode(T.self, from: data)

        } catch {
            logger.error("Request error for URL: \(url.absoluteString, privacy: .public), error: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
} 