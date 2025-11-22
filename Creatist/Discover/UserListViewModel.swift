import Foundation
import SwiftUI

class UserListViewModel: ObservableObject {
    @Published var topRatedUsers: [User] = []
    @Published var nearbyUsers: [User] = []
    @Published var isLoading = false

    // Fetch users for a genre
    @MainActor
    func fetchUsers(for genre: UserGenre) async {
        isLoading = true
        async let topRated = Creatist.shared.fetchTopRatedUsers(for: genre)
        async let nearby = Creatist.shared.fetchNearbyUsers(for: genre)
        let (top, near) = await (topRated, nearby)
        self.topRatedUsers = top
        self.nearbyUsers = near
        isLoading = false
    }

    // Toggle follow/unfollow for a user
    @MainActor
    func toggleFollow(for user: User) async {
        guard let userId = user.id.uuidString as String? else { return }
        let isCurrentlyFollowing = user.isFollowing ?? false
        let success: Bool
        if isCurrentlyFollowing {
            success = await Creatist.shared.unfollowUser(userId: userId)
        } else {
            success = await Creatist.shared.followUser(userId: userId)
        }
        if success {
            // Update in topRatedUsers - replace entire user object since User is a struct
            if let idx = self.topRatedUsers.firstIndex(where: { $0.id == user.id }) {
                var updatedUser = self.topRatedUsers[idx]
                updatedUser.isFollowing = !isCurrentlyFollowing
                self.topRatedUsers[idx] = updatedUser
            }
            // Update in nearbyUsers - replace entire user object since User is a struct
            if let idx = self.nearbyUsers.firstIndex(where: { $0.id == user.id }) {
                var updatedUser = self.nearbyUsers[idx]
                updatedUser.isFollowing = !isCurrentlyFollowing
                self.nearbyUsers[idx] = updatedUser
            }
        }
    }
} 