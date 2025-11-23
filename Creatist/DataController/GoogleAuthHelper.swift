import Foundation
import GoogleSignIn
import UIKit

/// Helper class for Google Sign-In functionality
@MainActor
class GoogleAuthHelper {
    static let shared = GoogleAuthHelper()
    
    private init() {}
    
    /// Configure Google Sign-In with the client ID
    /// Call this in your app's initialization (e.g., AppDelegate or App struct)
    func configure(clientID: String) {
        guard !clientID.isEmpty else {
            print("⚠️ GoogleAuthHelper: Client ID is empty. Please set GOOGLE_CLIENT_ID in Secrets.xcconfig")
            return
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        print("✅ GoogleAuthHelper: Google Sign-In configured successfully")
    }
    
    /// Sign in with Google
    /// Returns the Google ID token that should be sent to your backend
    func signIn() async throws -> String {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw GoogleAuthError.noRootViewController
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleAuthError.noIdToken
        }
        
        return idToken
    }
    
    /// Sign out from Google
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
    
    /// Check if user is currently signed in with Google
    var isSignedIn: Bool {
        return GIDSignIn.sharedInstance.currentUser != nil
    }
}

enum GoogleAuthError: LocalizedError {
    case noRootViewController
    case noIdToken
    case signInFailed
    
    var errorDescription: String? {
        switch self {
        case .noRootViewController:
            return "Unable to find root view controller"
        case .noIdToken:
            return "Google sign-in succeeded but no ID token was received"
        case .signInFailed:
            return "Google sign-in failed"
        }
    }
}

