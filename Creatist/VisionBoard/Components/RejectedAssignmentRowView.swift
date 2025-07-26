import SwiftUI
import Foundation

struct RejectedAssignmentRowView: View {
    let assignment: GenreAssignment
    let genre: GenreWithAssignments
    let board: VisionBoard
    let onReplace: () -> Void
    
    @State private var user: User? = nil
    @State private var isLoading = true
    static var userCache: [UUID: User] = [:] // Static cache for user info

    var body: some View {
        HStack {
            if isLoading {
                ProgressView().frame(width: 32, height: 32)
                Text("Loading...")
            } else if let user = user {
                if let imageUrl = user.profileImageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        if let _ = UIImage(named: "defaultAvatar") {
                            Image("defaultAvatar").resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "person.crop.circle.fill").foregroundColor(.gray)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    if let _ = UIImage(named: "defaultAvatar") {
                        Image("defaultAvatar")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    }
                }
                Text(user.name)
                    .font(.body)
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .resizable()
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                Text("Unknown")
            }
            Spacer()
            Text("Rejected")
                .foregroundColor(.red)
        }
        .onAppear {
            loadUser()
        }
    }
    
    private func loadUser() {
        if let cached = RejectedAssignmentRowView.userCache[assignment.userId] {
            self.user = cached
            self.isLoading = false
            return
        }
        Task {
            guard let token = KeychainHelper.get("accessToken"), !token.isEmpty else { return }
            guard let url = URL(string: NetworkManager.baseURL + "/v1/users/\(assignment.userId.uuidString)") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let userResponse = try decoder.decode(UserResponse.self, from: data)
                let user = userResponse.user
                RejectedAssignmentRowView.userCache[assignment.userId] = user
                await MainActor.run {
                    self.user = user
                    self.isLoading = false
                }
            } catch {
                print("[DEBUG] Error fetching user info for rejected assignment: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
} 