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
        VStack(spacing: 0) {
            if let user = user {
                VStack(spacing: 16) {
                    // User image
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
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .shadow(radius: 6)
                        .padding(.top, 32)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .foregroundColor(.gray)
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .shadow(radius: 6)
                            .padding(.top, 32)
                    }
                    // Username
                    Text(user.name)
                        .font(.title2).bold()
                        .padding(.top, 8)
                    // Stats row
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(followersCount)")
                                .font(.headline)
                            Text("Followers")
                                .font(.caption)
                        }
                        VStack {
                            Text("\(followingCount)")
                                .font(.headline)
                            Text("Following")
                                .font(.caption)
                        }
                        VStack {
                            Text("0") // Placeholder
                                .font(.headline)
                            Text("Projects")
                                .font(.caption)
                        }
                        VStack {
                            Text(String(format: "%.1f", user.rating ?? 0.0))
                                .font(.headline)
                            Text("Rating")
                                .font(.caption)
                        }
                    }
                    .padding(.top, 8)
                    // Bio/description (if available)
                    Text(user.email) // Placeholder for bio/description
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    // Info rows
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                            Text("\(user.city ?? ""), \(user.country ?? "")")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .foregroundColor(.purple)
                            Text(user.workMode?.rawValue ?? "")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            Image(systemName: user.paymentMode == .paid ? "creditcard.fill" : "gift.fill")
                                .foregroundColor(user.paymentMode == .paid ? .green : .orange)
                            Text(user.paymentMode?.rawValue.capitalized ?? "")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .foregroundColor(.pink)
                            Text(user.genres?.map { $0.rawValue }.joined(separator: ", ") ?? "")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    Spacer()
                    // Follow and Message buttons
                    HStack(spacing: 16) {
                        FollowButton(userId: user.id, viewModel: viewModel)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        Button(action: { showDirectChat = true }) {
                            Text("Message")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .cornerRadius(8)
                        }
                        .disabled(false)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .task {
                    followersCount = await Creatist.shared.fetchFollowersCount(for: user.id.uuidString)
                    followingCount = await Creatist.shared.fetchFollowingCount(for: user.id.uuidString)
                }
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .navigationTitle(user?.name ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
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
    }
} 
