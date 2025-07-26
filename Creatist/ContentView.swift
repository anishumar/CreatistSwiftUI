//
//  ContentView.swift
//  Creatist
//
//  Created by Anish Umar on 04/07/25.
//

import SwiftUI

struct SplashWrapperView: View {
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            } else {
                // Real main app view
                MainAppContentView()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showSplash = false
                }
            }
        }
    }
}

// This is the real main view from Auth/LoginView.swift
struct MainAppContentView: View {
    @State private var isLoggedIn: Bool = false
    @State private var isLoading: Bool = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if isLoggedIn {
                HomeView(isLoggedIn: $isLoggedIn)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .onAppear {
            Task {
                if let autologin = await Creatist.shared.autologin(), autologin {
                    isLoggedIn = true
                    // Start token monitoring when user is logged in
                    TokenMonitor.shared.startMonitoring()
                }
                isLoading = false
            }
        }
        .onChange(of: isLoggedIn) { newValue in
            if newValue {
                // Start monitoring when user logs in
                TokenMonitor.shared.startMonitoring()
            } else {
                // Stop monitoring when user logs out
                TokenMonitor.shared.stopMonitoring()
            }
        }
    }
}

struct SplashWrapperView_Previews: PreviewProvider {
    static var previews: some View {
        SplashWrapperView()
    }
}




