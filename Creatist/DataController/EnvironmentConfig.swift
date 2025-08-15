import Foundation

enum AppEnvironment: String, CaseIterable {
    case development = "development"
    case staging = "staging"
    case production = "production"
    
    var apiBaseURL: String {
        switch self {
        case .development:
            return "http://localhost:8080"
        case .staging:
            return "https://web-production-5d44.up.railway.app"
        case .production:
            return "https://web-production-5d44.up.railway.app"
        }
    }
    
    var wsBaseURL: String {
        switch self {
        case .development:
            return "ws://localhost:8080"
        case .staging:
            return "wss://web-production-5d44.up.railway.app"
        case .production:
            return "wss://web-production-5d44.up.railway.app"
        }
    }
}

class EnvironmentConfig {
    static let shared = EnvironmentConfig()
    
    private let environmentKey = "APP_ENVIRONMENT"
    
    var currentEnvironment: AppEnvironment {
        get {
            // In debug builds, always use development (localhost)
            #if DEBUG
            return .development
            #else
            // In release builds, check if user has manually set an environment
            if let stored = UserDefaults.standard.string(forKey: environmentKey),
               let env = AppEnvironment(rawValue: stored) {
                return env
            }
            // Default to production for release builds
            return .production
            #endif
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: environmentKey)
        }
    }
    
    var apiBaseURL: String {
        let url = currentEnvironment.apiBaseURL
        #if DEBUG
        print("🔧 EnvironmentConfig: Using API URL: \(url) (Debug Mode)")
        #else
        print("🚀 EnvironmentConfig: Using API URL: \(url) (Release Mode)")
        #endif
        return url
    }
    
    var wsBaseURL: String {
        let url = currentEnvironment.wsBaseURL
        #if DEBUG
        print("🔧 EnvironmentConfig: Using WebSocket URL: \(url) (Debug Mode)")
        #else
        print("🚀 EnvironmentConfig: Using WebSocket URL: \(url) (Release Mode)")
        #endif
        return url
    }
    
    // Helper method to get WebSocket URL for specific endpoints
    func wsURL(for endpoint: String) -> String {
        return "\(wsBaseURL)\(endpoint)"
    }
    
    // Helper method to get API URL for specific endpoints
    func apiURL(for endpoint: String) -> String {
        return "\(apiBaseURL)\(endpoint)"
    }
}
