import SwiftUI

struct PhoneVerificationView: View {
    let phoneNumber: String
    let onVerified: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var otp: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Verify Phone Number")
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
                        Text("Verify & Update")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(isLoading || otp.count != 6)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Verify Phone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
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
            let (success, errorMsg) = await Creatist.shared.verifyPhoneUpdate(phoneNumber: phoneNumber, otp: otp)
            await MainActor.run {
                isLoading = false
                if success {
                    onVerified()
                    dismiss()
                } else {
                    errorMessage = errorMsg ?? "Invalid OTP. Please try again."
                }
            }
        }
    }
}

