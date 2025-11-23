//
//  CreatistApp.swift
//  Creatist
//
//  Created by Anish Umar on 04/07/25.
//

import SwiftUI

@main
struct CreatistApp: App {
    init() {
        // Configure Google Sign-In
        let googleClientID = EnvironmentConfig.shared.googleClientID
        if !googleClientID.isEmpty {
            GoogleAuthHelper.shared.configure(clientID: googleClientID)
        } else {
            print("⚠️ Google Sign-In not configured: GOOGLE_CLIENT_ID not set")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            SplashWrapperView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Restart token monitoring when app becomes active
                    if KeychainHelper.get("accessToken") != nil {
                        TokenMonitor.shared.startMonitoring()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Stop monitoring when app goes to background
                    TokenMonitor.shared.stopMonitoring()
                }
        }
    }
}
