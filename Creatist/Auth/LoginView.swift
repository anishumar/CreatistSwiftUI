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
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 24) {
            Text("Login")
                .font(.largeTitle)
                .bold()
                .padding(.top, 40)
            
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .focused($focusedField, equals: .email)
                HStack {
                    if showPassword {
                        TextField("Password", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
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
                        .background(isLoading ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(isLoading)
            .padding(.top, 8)
            
            VStack(spacing: 12) {
                HStack {
                    Text("New user?")
                    Button(action: { navigationPath.append("signup") }) {
                        Text("Sign up now")
                            .foregroundColor(.accentColor)
                            .bold()
                    }
                }
                
                Button(action: { navigationPath.append("forgotPassword") }) {
                    Text("Forgot Password?")
                        .foregroundColor(.accentColor)
                        .font(.subheadline)
                }
            }
            .padding(.top, 16)
            
            Spacer()
            
            // Made with love in India footer
            HStack {
                Text("Made with")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                Text("in India")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            }
            .padding()
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
                case "signup":
                    SignupView()
                case "otp":
                    OTPView(email: email) {
                        isLoggedIn = true
                    }
                default:
                    EmptyView()
                }
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
