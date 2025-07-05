import SwiftUI

struct FollowButton: View {
    let userId: UUID
    @ObservedObject var viewModel: UserListViewModel
    @State private var isLoading = false
    var user: User? {
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId })
    }
    // Don't show follow button if viewing own profile
    private var isOwnProfile: Bool {
        user?.id == Creatist.shared.user?.id
    }
    
    var body: some View {
        if let user = user, !isOwnProfile {
            Button(action: {
                Task {
                    isLoading = true
                    await viewModel.toggleFollow(for: user)
                    isLoading = false
                }
            }) {
                HStack(spacing: 4) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: (user.isFollowing ?? false) ? "person.fill.badge.minus" : "person.badge.plus")
                            .font(.caption)
                    }
                    Text((user.isFollowing ?? false) ? "Unfollow" : "Follow")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((user.isFollowing ?? false) ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                .foregroundColor((user.isFollowing ?? false) ? .red : .blue)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke((user.isFollowing ?? false) ? Color.red.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(isLoading)
        }
    }
} 