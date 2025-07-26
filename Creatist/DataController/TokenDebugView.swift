import SwiftUI

struct TokenDebugView: View {
    @State private var timeUntilExpiration: TimeInterval?
    @State private var isExpired: Bool = false
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔐 Token Status")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Text("Access Token:")
                Spacer()
                Text(KeychainHelper.get("accessToken") != nil ? "✅ Present" : "❌ Missing")
                    .foregroundColor(KeychainHelper.get("accessToken") != nil ? .green : .red)
            }
            
            HStack {
                Text("Refresh Token:")
                Spacer()
                Text(KeychainHelper.get("refreshToken") != nil ? "✅ Present" : "❌ Missing")
                    .foregroundColor(KeychainHelper.get("refreshToken") != nil ? .green : .red)
            }
            
            HStack {
                Text("Expiration Time:")
                Spacer()
                Text(KeychainHelper.get("tokenExpirationTime") != nil ? "✅ Set" : "❌ Not Set")
                    .foregroundColor(KeychainHelper.get("tokenExpirationTime") != nil ? .green : .red)
            }
            
            if let timeUntilExpiration = timeUntilExpiration {
                HStack {
                    Text("Time Until Expiry:")
                    Spacer()
                    Text(formatTimeInterval(timeUntilExpiration))
                        .foregroundColor(timeUntilExpiration > 300 ? .green : timeUntilExpiration > 60 ? .orange : .red)
                }
            }
            
            HStack {
                Text("Status:")
                Spacer()
                Text(isExpired ? "⚠️ Expired/Expiring Soon" : "✅ Valid")
                    .foregroundColor(isExpired ? .red : .green)
            }
            
            Button("🔄 Refresh Token Now") {
                Task {
                    _ = await NetworkManager.shared.refreshToken()
                    await MainActor.run {
                        updateTokenStatus()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(KeychainHelper.get("refreshToken") == nil)
            
            Button("🔄 Restart Monitor") {
                TokenMonitor.shared.startMonitoring()
                updateTokenStatus()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onAppear {
            updateTokenStatus()
            startRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }
    
    private func updateTokenStatus() {
        timeUntilExpiration = getTimeUntilTokenExpiration()
        isExpired = isTokenExpiredOrExpiringSoon()
    }
    
    private func getTimeUntilTokenExpiration() -> TimeInterval? {
        guard let expirationString = KeychainHelper.get("tokenExpirationTime") else { return nil }
        let expirationTime = Date(timeIntervalSince1970: Double(expirationString) ?? 0)
        
        return expirationTime.timeIntervalSinceNow
    }
    
    private func isTokenExpiredOrExpiringSoon(buffer: TimeInterval = 5 * 60) -> Bool {
        guard let expirationString = KeychainHelper.get("tokenExpirationTime") else { return true }
        let expirationTime = Date(timeIntervalSince1970: Double(expirationString) ?? 0)
        
        let timeUntilExpiry = expirationTime.timeIntervalSinceNow
        return timeUntilExpiry <= buffer
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTokenStatus()
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        if interval < 0 {
            return "Expired"
        }
        
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

#Preview {
    TokenDebugView()
} 