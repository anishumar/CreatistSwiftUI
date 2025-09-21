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
    @State private var currentImageIndex: Int = 0
    @State private var timer: Timer?
    @FocusState private var focusedField: Field?
    
    private let backgroundImages = ["login1", "login2", "login3"]
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Dynamic Background Images with Carousel Effect
                TabView(selection: $currentImageIndex) {
                    ForEach(0..<backgroundImages.count, id: \.self) { index in
                        ZStack {
                            Image(backgroundImages[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 2)
                                .ignoresSafeArea()
                            
                            // Gradient fade overlay
                            VStack {
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(.systemBackground),
                                        Color.clear,
                                        Color.clear,
                                        Color(.systemBackground)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 200)
                                
                                Spacer()
                                
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.clear,
                                        Color.clear,
                                        Color(.systemBackground)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 200)
                            }
                            .ignoresSafeArea()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 1.0), value: currentImageIndex)
                
                // Semi-transparent overlay for better text readability
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(8)
                    .focused($focusedField, equals: .email)
                    .foregroundColor(.primary)
                    .accentColor(.accentColor)
                
                VStack(spacing: 8) {
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
                    .background(Color(.systemBackground).opacity(0.9))
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
                }
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .bold()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(8)
            }
            
            Button(action: login) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isLoading ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(isLoading)
            .padding(.top, 8)
            
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
            
            Spacer()
            
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
            .padding(.bottom, 20)
            }
            .padding()
            .onTapGesture {
                hideKeyboard()
            }
            .onAppear {
                startImageCarousel()
            }
            .onDisappear {
                stopImageCarousel()
            }
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
    
    func startImageCarousel() {
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                currentImageIndex = (currentImageIndex + 1) % backgroundImages.count
            }
        }
    }
    
    func stopImageCarousel() {
        timer?.invalidate()
        timer = nil
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
