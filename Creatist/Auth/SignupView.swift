import SwiftUI

struct SignupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showOTP: Bool = false
    @State private var otpEmail: String = ""
    @State private var isSignupComplete: Bool = false
    @State private var otp: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !isSignupComplete {
                    Text("Sign Up")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top, 24)
                    
                    TextField("First Name", text: $firstName)
                        .autocapitalization(.words)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    TextField("Last Name", text: $lastName)
                        .autocapitalization(.words)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                } else {
                    // Show verification step
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                        
                        Text("Verify Your Email")
                            .font(.title2)
                            .bold()
                        
                        Text("We've sent a verification code to")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(otpEmail)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.primary)
                        
                        Text("Please check your email and enter the code below to complete your registration.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                
                if isSignupComplete {
                    // OTP Input Field
                    TextField("Enter verification code", text: $otp)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .bold()
                }
                
                Button(action: isSignupComplete ? verifyOTP : signup) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(isSignupComplete ? "Verify & Complete Signup" : "Sign Up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(isLoading)
                .padding(.top, 8)
                
                // Google Sign-Up Button (only show on initial signup screen)
                if !isSignupComplete {
                    Button(action: signUpWithGoogle) {
                        HStack(spacing: 12) {
                            Image("Google")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Sign up with Google")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.21, green: 0.21, blue: 0.21)) // Dark gray #363636
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isSignupComplete {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSignupComplete = false
                                otp = ""
                                errorMessage = nil
                            }
                        }
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }
    
    func signup() {
        errorMessage = nil
        guard !firstName.isEmpty, !lastName.isEmpty, !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        isLoading = true
        Task {
            let user = User(id: UUID(), name: firstName + " " + lastName, email: email, password: password)
            let result = await Creatist.shared.signup(user)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    // For existing users who don't need verification
                    dismiss()
                case .requiresVerification:
                    // For new users who need OTP verification - transition to verification mode
                    otpEmail = email
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSignupComplete = true
                    }
                case .failure(let error):
                    errorMessage = error
                }
            }
        }
    }
    
    func verifyOTP() {
        errorMessage = nil
        guard !otp.isEmpty else {
            errorMessage = "Please enter the verification code."
            return
        }
        isLoading = true
        Task {
            let result = await Creatist.shared.verifyOTP(otp)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    dismiss() // On successful OTP verification, dismiss signup
                case .failure(let error):
                    errorMessage = error
                }
            }
        }
    }
    
    func signUpWithGoogle() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                // Get Google ID token
                let idToken = try await GoogleAuthHelper.shared.signIn()
                
                // Authenticate with backend (unified endpoint handles both sign-in and sign-up)
                let result = await Creatist.shared.googleAuth(idToken: idToken)
                
                await MainActor.run {
                    isLoading = false
                    switch result {
                    case .success:
                        dismiss() // Sign up successful, dismiss the view
                    case .failure(let error):
                        errorMessage = error
                    case .requiresVerification:
                        errorMessage = "Verification required"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Google sign-up failed: \(error.localizedDescription)"
                }
            }
        }
    }
} 
