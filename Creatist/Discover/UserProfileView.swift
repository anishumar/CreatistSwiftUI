import SwiftUI

struct UserProfileView: View {
    let userId: UUID
    @ObservedObject var viewModel: UserListViewModel
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var showDirectChat = false

    var user: User? {
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId })
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(red: 0.2, green: 0, blue: 0.1)]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if let user = user {
                        Spacer(minLength: 24)
                        // Profile image
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 110, height: 110)
                            if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else if phase.error != nil {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable().aspectRatio(contentMode: .fill)
                                            .foregroundColor(.gray)
                                    } else {
                                        ProgressView()
                                    }
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 16)

                        // Username & handle
                        Text(user.name)
                            .font(.title).bold()
                            .foregroundColor(.white)
                            .padding(.top, 12)
                        if let username = user.username {
                            Text("@\(username)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        // Stats
                        HStack(spacing: 24) {
                            StatView(number: Double(followersCount), label: "Followers")
                            StatView(number: Double(followingCount), label: "Following")
                            StatView(number: 0, label: "Projects")
                            StatView(number: user.rating ?? 0, label: "Rating", isDouble: true)
                        }
                        .padding(.top, 8)

                        // Bio/description
                        if let desc = user.description, !desc.isEmpty {
                            Text(desc)
                                .font(.body)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        } else {
                            Text(user.email)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }

                        // Info rows
                        VStack(spacing: 8) {
                            if let city = user.city, let country = user.country {
                                InfoRow(icon: "location", text: "\(city), \(country)")
                            }
                            if let workMode = user.workMode {
                                InfoRow(icon: "globe", text: workMode.rawValue)
                            }
                            if let paymentMode = user.paymentMode {
                                InfoRow(icon: paymentMode == .paid ? "creditcard.fill" : "gift.fill", text: paymentMode.rawValue.capitalized)
                            }
                            if let genres = user.genres, !genres.isEmpty {
                                InfoRow(icon: "music.note.list", text: genres.map { $0.rawValue }.joined(separator: ", "))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Action buttons
                        HStack(spacing: 24) {
                            ProfileFollowButton(userId: user.id, viewModel: viewModel)
                                .frame(maxWidth: .infinity)
                            Button(action: { showDirectChat = true }) {
                                Text("Message")
                                    .font(.headline.bold())
                                    .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(Color.white.opacity(0.18))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                    )
                                    .foregroundColor(.white)
                            }
                            .disabled(false)
                        }
                        .frame(maxWidth: 340)
                        .padding(.top, 40)
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    } else {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showDirectChat) {
            if let currentUser = Creatist.shared.user, let otherUser = user {
                let urlString = "ws://localhost:8080/ws/message/\(otherUser.id.uuidString)?token=\(KeychainHelper.get("accessToken") ?? "")"
                if let url = URL(string: urlString) {
                    ChatView(
                        manager: ChatWebSocketManager(
                            url: url,
                            token: KeychainHelper.get("accessToken") ?? "",
                            userId: currentUser.id.uuidString,
                            isGroupChat: false,
                            otherUserId: otherUser.id.uuidString
                        ),
                        currentUserId: currentUser.id.uuidString,
                        title: "Chat with \(otherUser.name)"
                    )
                } else {
                    Text("Invalid chat URL")
                }
            } else {
                Text("User not logged in")
            }
        }
        .task {
            if let user = user {
                followersCount = await Creatist.shared.fetchFollowersCount(for: user.id.uuidString)
                followingCount = await Creatist.shared.fetchFollowingCount(for: user.id.uuidString)
            }
        }
    }
}

// Helper views
struct StatView: View {
    let number: Double
    let label: String
    var isDouble: Bool = false
    var body: some View {
        VStack {
            if isDouble {
                Text(String(format: "%.1f", number))
                    .font(.headline)
                    .foregroundColor(.white)
            } else {
                Text("\(Int(number))")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
        }
    }
} 
