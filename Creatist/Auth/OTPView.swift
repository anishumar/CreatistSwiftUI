import SwiftUI

struct OTPView: View {
    let email: String
    var onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var otp: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Enter OTP")
                .font(.title2)
                .bold()
                .padding(.top, 40)
            Text("An OTP has been sent to \(email)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("OTP", text: $otp)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
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
            .disabled(isLoading)
            .padding(.top, 8)
            Spacer()
        }
        .padding()
    }
    
    func verifyOTP() {
        errorMessage = nil
        guard !otp.isEmpty else {
            errorMessage = "Please enter the OTP."
            return
        }
        isLoading = true
        Task {
            let result = await Creatist.shared.verifyOTP(otp)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    onSuccess()
                    dismiss()
                case .failure(let error):
                    errorMessage = error
                }
            }
        }
    }
} 