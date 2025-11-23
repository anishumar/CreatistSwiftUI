import SwiftUI

struct PhoneOTPView: View {
    let phoneNumber: String
    var onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var otp: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var resendCooldown: Int = 0
    @State private var resendTimer: Timer?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Enter OTP")
                .font(.title2)
                .bold()
                .padding(.top, 40)
            
            Text("An OTP has been sent to")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(phoneNumber)
                .font(.subheadline)
                .bold()
                .foregroundColor(.primary)
            
            TextField("Enter 6-digit code", text: $otp)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .multilineTextAlignment(.center)
                .font(.title2)
                .bold()
                .onChange(of: otp) { oldValue, newValue in
                    // Limit to 6 digits
                    if newValue.count > 6 {
                        otp = String(newValue.prefix(6))
                    }
                }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
            
            Button(action: verifyOTP) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Verify OTP")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(isLoading || otp.count != 6)
            .padding(.top, 8)
            
            HStack {
                Text("Didn't receive code?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: resendOTP) {
                    Text(resendCooldown > 0 ? "Resend in \(resendCooldown)s" : "Resend")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .bold()
                }
                .disabled(resendCooldown > 0)
            }
            .padding(.top, 16)
            
            Spacer()
        }
        .padding()
        .onAppear {
            startResendCooldown()
        }
        .onDisappear {
            resendTimer?.invalidate()
        }
    }
    
    func verifyOTP() {
        errorMessage = nil
        guard otp.count == 6 else {
            errorMessage = "Please enter the 6-digit OTP."
            return
        }
        isLoading = true
        
        Task {
            let result = await Creatist.shared.phoneAuth(phoneNumber: phoneNumber, otp: otp)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    onSuccess()
                    dismiss()
                case .failure(let error):
                    errorMessage = error
                case .requiresVerification:
                    errorMessage = "Verification required"
                }
            }
        }
    }
    
    func resendOTP() {
        isLoading = true
        Task {
            let (success, errorMsg) = await Creatist.shared.requestPhoneOTP(phoneNumber: phoneNumber)
            await MainActor.run {
                isLoading = false
                if success {
                    errorMessage = nil
                    otp = ""
                    startResendCooldown()
                } else {
                    errorMessage = errorMsg ?? "Failed to resend OTP. Please try again."
                }
            }
        }
    }
    
    func startResendCooldown() {
        resendCooldown = 60 // 60 seconds cooldown
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if resendCooldown > 0 {
                resendCooldown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

