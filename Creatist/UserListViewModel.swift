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
        // Debug print for isFollowing
        print("Top Rated Users:")
        for user in self.topRatedUsers {
            print("\(user.name): isFollowing = \(user.isFollowing ?? false)")
        }
        print("Nearby Users:")
        for user in self.nearbyUsers {
            print("\(user.name): isFollowing = \(user.isFollowing ?? false)")
        }
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
            // Update in topRatedUsers
            if let idx = self.topRatedUsers.firstIndex(where: { $0.id == user.id }) {
                self.topRatedUsers[idx].isFollowing = !isCurrentlyFollowing
            }
            // Update in nearbyUsers
            if let idx = self.nearbyUsers.firstIndex(where: { $0.id == user.id }) {
                self.nearbyUsers[idx].isFollowing = !isCurrentlyFollowing
            }
        }
    }
} 