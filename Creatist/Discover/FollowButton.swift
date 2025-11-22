import SwiftUI

// Large, pill-shaped follow button for user profile
struct ProfileFollowButton: View {
    let userId: UUID
    @ObservedObject var viewModel: UserListViewModel
    var providedUser: User? = nil
    var onFollowStatusChanged: ((Bool) -> Void)? = nil
    @State private var isLoading = false
    @State private var localFollowStatus: Bool? = nil
    
    var user: User? {
        providedUser ??
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId })
    }
    
    var isFollowing: Bool {
        localFollowStatus ?? user?.isFollowing ?? false
    }
    
    private var isOwnProfile: Bool {
        user?.id == Creatist.shared.user?.id
    }
    var body: some View {
        if let user = user, !isOwnProfile {
            Button(action: {
                Task {
                    isLoading = true
                    let wasFollowing = isFollowing
                    await viewModel.toggleFollow(for: user)
                    // Update local state immediately
                    localFollowStatus = !wasFollowing
                    // Notify parent view of status change
                    onFollowStatusChanged?(!wasFollowing)
                    isLoading = false
                }
            }) {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.headline.bold())
                }
                .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                        if !isFollowing {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.accentColor.opacity(0.28))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .foregroundColor(.white)
            }
            .disabled(isLoading)
            .onAppear {
                // Initialize local state from user
                if localFollowStatus == nil {
                    localFollowStatus = user.isFollowing
                }
            }
        }
    }
}

// Compact, frosted follow button for cards
struct CompactFollowButton: View {
    let userId: UUID
    @ObservedObject var viewModel: UserListViewModel
    @State private var isLoading = false
    var user: User? {
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId })
    }
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
                    }
                    Text((user.isFollowing ?? false) ? "Following" : "Follow")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor((user.isFollowing ?? false) ? Color.gray : Color.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                // Remove .foregroundColor(.primary) to allow per-text coloring
            }
            .disabled(isLoading)
        }
    }
}

// Deprecated: Use ProfileFollowButton or CompactFollowButton instead
@available(*, deprecated, message: "Use ProfileFollowButton or CompactFollowButton instead.")
struct FollowButton: View {
    let userId: UUID
    @ObservedObject var viewModel: UserListViewModel
    var compact: Bool = false
    @State private var isLoading = false
    var user: User? {
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId })
    }
    private var isOwnProfile: Bool {
        user?.id == Creatist.shared.user?.id
    }
    var body: some View {
        if compact {
            CompactFollowButton(userId: userId, viewModel: viewModel)
        } else {
            ProfileFollowButton(userId: userId, viewModel: viewModel)
        }
    }
} 