import SwiftUI

struct ResetPasswordView: View {
    let email: String
    var onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showNewPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSuccessMessage: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 20) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("Create New Password")
                        .font(.title2)
                        .bold()
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    // New Password Field
                    HStack {
                        if showNewPassword {
                            TextField("New Password", text: $newPassword)
                                .textContentType(.newPassword)
                        } else {
                            SecureField("New Password", text: $newPassword)
                                .textContentType(.newPassword)
                        }
                        
                        Button(action: { showNewPassword.toggle() }) {
                            Image(systemName: showNewPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .disabled(showSuccessMessage)
                    
                    // Confirm Password Field
                    HStack {
                        if showConfirmPassword {
                            TextField("Confirm New Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                        } else {
                            SecureField("Confirm New Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                        }
                        
                        Button(action: { showConfirmPassword.toggle() }) {
                            Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .disabled(showSuccessMessage)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                
                if showSuccessMessage {
                    Text("Password reset successfully! You can now login with your new password.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Button(action: resetPassword) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(showSuccessMessage ? "Password Reset!" : "Reset Password")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(showSuccessMessage || isLoading ? Color.gray : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(isLoading || showSuccessMessage)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func resetPassword() {
        errorMessage = nil
        guard !newPassword.isEmpty else {
            errorMessage = "Please enter a new password."
            return
        }
        guard !confirmPassword.isEmpty else {
            errorMessage = "Please confirm your new password."
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters long."
            return
        }
        
        isLoading = true
        Task {
            // OTP is already verified in previous step, backend doesn't need it
            let result = await Creatist.shared.resetPassword(newPassword: newPassword, otp: "")
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    showSuccessMessage = true
                    // Call onSuccess after showing success message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        onSuccess()
                    }
                case .failure(let error):
                    errorMessage = error
                }
            }
        }
    }
}
