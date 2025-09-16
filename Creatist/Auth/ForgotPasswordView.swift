import SwiftUI

struct ForgotPasswordView: View {
    var onSuccess: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var otp: String = ""
    @State private var isLoading: Bool = false
    @State private var isVerifyingOTP: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var showOTPStep: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Forgot Password")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 24)
                
                if !showOTPStep {
                    // Step 1: Email Input
                    VStack(spacing: 20) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("Enter your email to receive a verification code")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                    
                    if let successMessage = successMessage {
                        Text(successMessage)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    
                    Button(action: requestPasswordReset) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Send Reset Code")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isLoading || email.isEmpty ? Color.gray : Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isLoading || email.isEmpty)
                    .padding(.top, 8)
                } else {
                    // Step 2: OTP Input
                    VStack(spacing: 20) {
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("Enter Code")
                                .font(.title2)
                                .bold()
                            
                            Text("Sent to \(email)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        TextField("Enter verification code", text: $otp)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .multilineTextAlignment(.center)
                            .font(.title2)
                            .bold()
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                    
                    if let successMessage = successMessage {
                        Text(successMessage)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    
                    Button(action: verifyOTP) {
                        if isLoading || isVerifyingOTP {
                            ProgressView()
                        } else {
                            Text("Confirm")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isLoading || isVerifyingOTP || otp.isEmpty ? Color.gray : Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isLoading || isVerifyingOTP || otp.isEmpty)
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func requestPasswordReset() {
        errorMessage = nil
        successMessage = nil
        
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }
        
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return
        }
        
        // Prevent multiple submissions
        guard !isLoading else { return }
        
        isLoading = true
        Task {
            let result = await Creatist.shared.requestForgotPasswordOTP(email: email)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    successMessage = "Verification code sent to your email. Please check your inbox."
                    // Show OTP step instead of calling onSuccess immediately
                    showOTPStep = true
                case .failure(let error):
                    errorMessage = error
                }
            }
        }
    }
    
    func verifyOTP() {
        errorMessage = nil
        successMessage = nil
        
        guard !otp.isEmpty else {
            errorMessage = "Please enter the verification code."
            return
        }
        
        // Prevent multiple submissions
        guard !isVerifyingOTP else { return }
        
        isVerifyingOTP = true
        Task {
            let result = await Creatist.shared.verifyOTP(email: email, otp: otp)
            await MainActor.run {
                isVerifyingOTP = false
                switch result {
                case .success:
                    successMessage = "Email verified successfully!"
                    // Now call onSuccess to proceed to password reset
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onSuccess(email)
                    }
                case .failure(let error):
                    errorMessage = error
                }
            }
        }
    }
}
