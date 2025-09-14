import SwiftUI

struct CacheSettingsView: View {
    @StateObject private var cacheManager = CacheManager.shared
    @State private var showingClearCacheAlert = false
    @State private var showingClearAllAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Cache Statistics")) {
                    CacheStatsRow(
                        title: "Trending Posts",
                        count: cacheManager.getCacheStats().trendingPostsCount,
                        isValid: cacheManager.getCacheStats().isTrendingCacheValid
                    )
                    
                    CacheStatsRow(
                        title: "Following Posts",
                        count: cacheManager.getCacheStats().followingPostsCount,
                        isValid: cacheManager.getCacheStats().isFollowingCacheValid
                    )
                    
                    CacheStatsRow(
                        title: "Cached Users",
                        count: cacheManager.getCacheStats().usersCount,
                        isValid: true
                    )
                    
                    CacheStatsRow(
                        title: "My Vision Boards",
                        count: cacheManager.getCacheStats().myVisionBoardsCount,
                        isValid: true
                    )
                    
                    CacheStatsRow(
                        title: "Partner Vision Boards",
                        count: cacheManager.getCacheStats().partnerVisionBoardsCount,
                        isValid: true
                    )
                    
                    CacheStatsRow(
                        title: "Vision Board Users",
                        count: cacheManager.getCacheStats().visionBoardUsersCount,
                        isValid: true
                    )
                    
                    CacheStatsRow(
                        title: "Cached Images",
                        count: cacheManager.getImageCacheStats().count,
                        isValid: true
                    )
                    
                    HStack {
                        Text("Total Cached Items")
                            .font(.headline)
                        Spacer()
                        Text("\(cacheManager.getCacheStats().totalCachedItems)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Cache Management")) {
                    Button("Clear Trending Cache") {
                        cacheManager.invalidateCache(for: .trending)
                    }
                    .foregroundColor(.orange)
                    
                    Button("Clear Following Cache") {
                        cacheManager.invalidateCache(for: .following)
                    }
                    .foregroundColor(.orange)
                    
                    Button("Clear User Cache") {
                        cacheManager.invalidateCache(for: "users")
                    }
                    .foregroundColor(.orange)
                    
                    Button("Clear VisionBoard Cache") {
                        cacheManager.invalidateCache(for: "my_vision_boards")
                        cacheManager.invalidateCache(for: "partner_vision_boards")
                        cacheManager.invalidateCache(for: "vision_board_users")
                    }
                    .foregroundColor(.orange)
                    
                    Button("Clear All Caches") {
                        showingClearAllAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("Cache Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cache Expiration: 5 minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Max Posts Cached: 100 per feed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Max Users Cached: 200")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Storage: UserDefaults (persistent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Last Updated")) {
                    if let lastTrending = cacheManager.getCacheStats().lastTrendingFetch {
                        HStack {
                            Text("Trending Feed")
                            Spacer()
                            Text(lastTrending, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let lastFollowing = cacheManager.getCacheStats().lastFollowingFetch {
                        HStack {
                            Text("Following Feed")
                            Spacer()
                            Text(lastFollowing, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Cache Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Clear All Caches", isPresented: $showingClearAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    cacheManager.invalidateAllCaches()
                }
            } message: {
                Text("This will clear all cached posts and user data. The app will need to reload data from the server.")
            }
        }
    }
}

struct CacheStatsRow: View {
    let title: String
    let count: Int
    let isValid: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text("\(count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(isValid ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(isValid ? "Valid" : "Expired")
                    .font(.caption)
                    .foregroundColor(isValid ? .green : .red)
            }
        }
    }
}

#Preview {
    CacheSettingsView()
}
