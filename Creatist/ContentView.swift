//
//  ContentView.swift
//  Creatist
//
//  Created by Anish Umar on 04/07/25.
//

import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSignup: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
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
                SecureField("Password", text: $password)
                    .textContentType(.password)
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
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(isLoading)
            .padding(.top, 8)
            
            HStack {
                Text("New user?")
                Button(action: { showSignup = true }) {
                    Text("Sign up now")
                        .foregroundColor(.accentColor)
                        .bold()
                }
                .sheet(isPresented: $showSignup) {
                    SignupView()
                }
            }
            .padding(.top, 16)
            
            Spacer()
        }
        .padding()
        .onTapGesture {
            hideKeyboard()
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
            let success = await Creatist.shared.login(email: email, password: password)
            await MainActor.run {
                isLoading = false
                if !success {
                    errorMessage = "Invalid credentials or user not found."
                } else {
                    errorMessage = nil
                    isLoggedIn = true
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
