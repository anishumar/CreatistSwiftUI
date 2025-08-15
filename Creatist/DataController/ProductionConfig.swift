import Foundation

struct ProductionConfig {
    // Production-specific settings
    static let isProduction = !isDebug
    
    // Debug flag - will be false in release builds
    static let isDebug: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    // App Store and TestFlight specific configurations
    struct AppStore {
        static let bundleIdentifier = "com.creatist.app"
        static let appName = "Creatist"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // Analytics and monitoring (for production)
    struct Analytics {
        static let enabled = isProduction
        // Add your analytics service keys here
        // static let mixpanelToken = "your_mixpanel_token"
        // static let crashlyticsEnabled = true
    }
    
    // Performance settings
    struct Performance {
        static let enableCaching = true
        static let maxCacheSize = 50 * 1024 * 1024 // 50MB
        static let requestTimeout: TimeInterval = 30.0
        static let imageCacheTimeout: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    }
    
    // Security settings
    struct Security {
        static let enableCertificatePinning = isProduction
        static let enableNetworkSecurity = isProduction
        static let requireSecureConnection = isProduction
    }
    
    // Feature flags
    struct Features {
        static let enablePushNotifications = true
        static let enableBackgroundRefresh = true
        static let enableLocationServices = true
        static let enableCameraAccess = true
        static let enablePhotoLibraryAccess = true
    }
}

// Production-ready logging
struct ProductionLogger {
    static func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        print("[\(level.rawValue.uppercased())] \(message)")
        #else
        // In production, only log errors and warnings
        if level == .error || level == .warning {
            print("[\(level.rawValue.uppercased())] \(message)")
        }
        #endif
    }
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
}
