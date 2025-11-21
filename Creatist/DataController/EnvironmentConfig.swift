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
            return "http://3.110.162.229:8080"
        case .production:
            return "http://3.110.162.229:8080"
        }
    }
    
    var wsBaseURL: String {
        switch self {
        case .development:
            return "ws://localhost:8080"
        case .staging:
            return "ws://3.110.162.229:8080"
        case .production:
            return "ws://3.110.162.229:8080"
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
    
    var supabaseURL: String {
        switch currentEnvironment {
        case .development:
            return "https://wkmribpqhgdpklwovrov.supabase.co"
        case .staging:
            return "https://wkmribpqhgdpklwovrov.supabase.co"
        case .production:
            return "https://wkmribpqhgdpklwovrov.supabase.co"
        }
    }
    
    var supabaseAnonKey: String {
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndrbXJpYnBxaGdkcGtsd292cm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE3MDY1OTksImV4cCI6MjA2NzI4MjU5OX0.N2wWfCSbjHMjHgA-stYesbcC8GZMATXug1rFew0qQOk"
    }
    
    // Google OAuth Client ID for iOS
    // TODO: Replace with your actual Google OAuth Client ID from Google Cloud Console
    // Option 1: Set directly here (for quick setup)
    // Option 2: Set via Secrets.xcconfig and Build Settings (recommended for production)
    var googleClientID: String {
        // Method 1: Try to read from build configuration (Secrets.xcconfig)
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String, !clientID.isEmpty {
            return clientID
        }
        
        // Method 2: Try environment variable
        if let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"], !clientID.isEmpty {
            return clientID
        }
        
        // Method 3: Direct assignment (configured with your Client ID)
        return "408248869256-5mlgsuu1uhaju2q7km2lfvufttmo3c2r.apps.googleusercontent.com"
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
