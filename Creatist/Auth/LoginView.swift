//
//  LoginView.swift
//  Creatist
//
//  Created by Anish Umar on 06/07/25.
//

import Foundation
import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var resetEmail: String = ""
    @State private var navigationPath: [String] = []
    @State private var showSignupModal: Bool = false
    @State private var showEmailLogin: Bool = false  // Track if email login is selected
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                    
                    // Initial view: Show email and Google options
                    if !showEmailLogin {
                        // Continue with Email Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showEmailLogin = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Continue with Email")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                        
                        // Continue with Google Button
                        Button(action: signInWithGoogle) {
                            HStack(spacing: 12) {
                                Image("Google")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("Continue with Google")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.21, green: 0.21, blue: 0.21)) // Dark gray #363636
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                    } else {
                        // Email login form (shown after clicking "Continue with Email")
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .email)
                            .foregroundColor(.primary)
                            .accentColor(.accentColor)
                        
                        HStack {
                            if showPassword {
                                TextField("Password", text: $password)
                                    .textContentType(.password)
                                    .foregroundColor(.primary)
                            } else {
                                SecureField("Password", text: $password)
                                    .textContentType(.password)
                                    .foregroundColor(.primary)
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        .focused($focusedField, equals: .password)
                        
                        HStack {
                            Spacer()
                            Button(action: { navigationPath.append("forgotPassword") }) {
                                Text("Forgot Password?")
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                                    .bold()
                            }
                        }
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                        
                        Button(action: login) {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Login")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .disabled(isLoading)
                        .padding(.top, 8)
                    }
                    
                        HStack {
                            Text("New user?")
                                .foregroundColor(.primary)
                            Button(action: { showSignupModal = true }) {
                                Text("Sign up now")
                                    .foregroundColor(.primary)
                                    .bold()
                            }
                        }
                        .padding(.top, 16)
                        
                        // Made with love in India footer
                        HStack {
                            Text("Made with")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("in India")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal)
                    .padding(.top, 220) // Add top padding to account for fixed header
                }
                
                // Fixed header - always on top
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back,")
                        .font(.title2)
                        .foregroundColor(.primary)
                    Text("Creatist")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 160, alignment: .top)
                .padding(.horizontal)
                .padding(.top, 60)
                .background(Color(.systemBackground))
                .zIndex(1)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showEmailLogin {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showEmailLogin = false
                                email = ""
                                password = ""
                                errorMessage = nil
                                hideKeyboard()
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "forgotPassword":
                    ForgotPasswordView { email in
                        resetEmail = email
                        navigationPath.append("resetPassword")
                    }
                case "resetPassword":
                    ResetPasswordView(email: resetEmail) {
                        // Password reset successful - navigate back to login
                        navigationPath.removeAll()
                    }
                case "otp":
                    OTPView(email: email) {
                        isLoggedIn = true
                    }
                default:
                    EmptyView()
                }
            }
            .sheet(isPresented: $showSignupModal) {
                SignupView()
            }
        }
    }
    
    func login() {
        errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        isLoading = true
        Task {
            let result = await Creatist.shared.login(email: email, password: password)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    errorMessage = nil
                    isLoggedIn = true
                    // Start token monitoring after successful login
                    TokenMonitor.shared.startMonitoring()
                case .failure(let error):
                    errorMessage = error
                case .requiresVerification:
                    errorMessage = "Account not verified. Please verify your email with the OTP sent to you."
                    navigationPath.append("otp")
                }
            }
        }
    }
    
    func hideKeyboard() {
        focusedField = nil
    }
    
    func signInWithGoogle() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                // Get Google ID token
                let idToken = try await GoogleAuthHelper.shared.signIn()
                
                // Authenticate with backend
                let result = await Creatist.shared.googleAuth(idToken: idToken)
                
                await MainActor.run {
                    isLoading = false
                    switch result {
                    case .success:
                        errorMessage = nil
                        isLoggedIn = true
                        TokenMonitor.shared.startMonitoring()
                    case .failure(let error):
                        errorMessage = error
                    case .requiresVerification:
                        errorMessage = "Verification required"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Google sign-in failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
}

struct ContentView: View {
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
                }
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
}
