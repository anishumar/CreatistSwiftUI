import Foundation
import SwiftUI

// MARK: - Cache Manager
class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    // MARK: - Cache Keys
    private enum CacheKeys {
        static let trendingPosts = "trending_posts"
        static let followingPosts = "following_posts"
        static let users = "cached_users"
        static let lastFetchTime = "last_fetch_time"
        static let cacheExpiration = "cache_expiration"
    }
    
    // MARK: - Cache Configuration
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    private let maxCacheSize = 100 // Maximum number of posts to cache
    private let maxUserCacheSize = 200 // Maximum number of users to cache
    
    // MARK: - In-Memory Caches
    @Published private var trendingPostsCache: [PostWithDetails] = []
    @Published private var followingPostsCache: [PostWithDetails] = []
    @Published private var userCache: [UUID: User] = [:]
    
    // MARK: - Cache Metadata
    private var lastFetchTimes: [String: Date] = [:]
    private var cacheExpirationTimes: [String: Date] = [:]
    
    private init() {
        loadCachedData()
    }
    
    // MARK: - Public Methods
    
    // MARK: Posts Caching
    func getTrendingPosts() -> [PostWithDetails] {
        if isCacheValid(for: CacheKeys.trendingPosts) {
            return trendingPostsCache
        }
        return []
    }
    
    func getFollowingPosts() -> [PostWithDetails] {
        if isCacheValid(for: CacheKeys.followingPosts) {
            return followingPostsCache
        }
        return []
    }
    
    func cacheTrendingPosts(_ posts: [PostWithDetails], append: Bool = false) {
        if append {
            trendingPostsCache.append(contentsOf: posts)
        } else {
            trendingPostsCache = posts
        }
        
        // Limit cache size
        if trendingPostsCache.count > maxCacheSize {
            trendingPostsCache = Array(trendingPostsCache.prefix(maxCacheSize))
        }
        
        updateCacheMetadata(for: CacheKeys.trendingPosts)
        saveCachedData()
    }
    
    func cacheFollowingPosts(_ posts: [PostWithDetails], append: Bool = false) {
        if append {
            followingPostsCache.append(contentsOf: posts)
        } else {
            followingPostsCache = posts
        }
        
        // Limit cache size
        if followingPostsCache.count > maxCacheSize {
            followingPostsCache = Array(followingPostsCache.prefix(maxCacheSize))
        }
        
        updateCacheMetadata(for: CacheKeys.followingPosts)
        saveCachedData()
    }
    
    // MARK: User Caching
    func getUser(_ userId: UUID) -> User? {
        return userCache[userId]
    }
    
    func cacheUser(_ user: User) {
        userCache[user.id] = user
        
        // Limit user cache size
        if userCache.count > maxUserCacheSize {
            let keysToRemove = Array(userCache.keys.prefix(userCache.count - maxUserCacheSize))
            keysToRemove.forEach { userCache.removeValue(forKey: $0) }
        }
        
        saveCachedData()
    }
    
    func cacheUsers(_ users: [User]) {
        for user in users {
            userCache[user.id] = user
        }
        
        // Limit user cache size
        if userCache.count > maxUserCacheSize {
            let keysToRemove = Array(userCache.keys.prefix(userCache.count - maxUserCacheSize))
            keysToRemove.forEach { userCache.removeValue(forKey: $0) }
        }
        
        saveCachedData()
    }
    
    // MARK: Cache Management
    func isCacheValid(for key: String) -> Bool {
        guard let expirationTime = cacheExpirationTimes[key] else { return false }
        return Date() < expirationTime
    }
    
    func invalidateCache(for key: String) {
        switch key {
        case CacheKeys.trendingPosts:
            trendingPostsCache.removeAll()
        case CacheKeys.followingPosts:
            followingPostsCache.removeAll()
        case CacheKeys.users:
            userCache.removeAll()
        default:
            break
        }
        
        lastFetchTimes.removeValue(forKey: key)
        cacheExpirationTimes.removeValue(forKey: key)
        saveCachedData()
    }
    
    func invalidateAllCaches() {
        trendingPostsCache.removeAll()
        followingPostsCache.removeAll()
        userCache.removeAll()
        lastFetchTimes.removeAll()
        cacheExpirationTimes.removeAll()
        saveCachedData()
    }
    
    func clearExpiredCaches() {
        let now = Date()
        let expiredKeys = cacheExpirationTimes.compactMap { key, expirationTime in
            now >= expirationTime ? key : nil
        }
        
        for key in expiredKeys {
            invalidateCache(for: key)
        }
    }
    
    // MARK: Cache Statistics
    func getCacheStats() -> CacheStats {
        return CacheStats(
            trendingPostsCount: trendingPostsCache.count,
            followingPostsCount: followingPostsCache.count,
            usersCount: userCache.count,
            lastTrendingFetch: lastFetchTimes[CacheKeys.trendingPosts],
            lastFollowingFetch: lastFetchTimes[CacheKeys.followingPosts]
        )
    }
    
    // MARK: Private Methods
    
    private func updateCacheMetadata(for key: String) {
        let now = Date()
        lastFetchTimes[key] = now
        cacheExpirationTimes[key] = now.addingTimeInterval(cacheExpirationTime)
    }
    
    private func saveCachedData() {
        Task {
            await MainActor.run {
                // Save to UserDefaults for persistence
                if let trendingData = try? JSONEncoder().encode(trendingPostsCache) {
                    UserDefaults.standard.set(trendingData, forKey: CacheKeys.trendingPosts)
                }
                
                if let followingData = try? JSONEncoder().encode(followingPostsCache) {
                    UserDefaults.standard.set(followingData, forKey: CacheKeys.followingPosts)
                }
                
                if let usersData = try? JSONEncoder().encode(userCache) {
                    UserDefaults.standard.set(usersData, forKey: CacheKeys.users)
                }
                
                if let metadataData = try? JSONEncoder().encode(lastFetchTimes) {
                    UserDefaults.standard.set(metadataData, forKey: CacheKeys.lastFetchTime)
                }
                
                if let expirationData = try? JSONEncoder().encode(cacheExpirationTimes) {
                    UserDefaults.standard.set(expirationData, forKey: CacheKeys.cacheExpiration)
                }
            }
        }
    }
    
    private func loadCachedData() {
        // Load trending posts
        if let trendingData = UserDefaults.standard.data(forKey: CacheKeys.trendingPosts),
           let posts = try? JSONDecoder().decode([PostWithDetails].self, from: trendingData) {
            trendingPostsCache = posts
        }
        
        // Load following posts
        if let followingData = UserDefaults.standard.data(forKey: CacheKeys.followingPosts),
           let posts = try? JSONDecoder().decode([PostWithDetails].self, from: followingData) {
            followingPostsCache = posts
        }
        
        // Load users
        if let usersData = UserDefaults.standard.data(forKey: CacheKeys.users),
           let users = try? JSONDecoder().decode([UUID: User].self, from: usersData) {
            userCache = users
        }
        
        // Load metadata
        if let metadataData = UserDefaults.standard.data(forKey: CacheKeys.lastFetchTime),
           let metadata = try? JSONDecoder().decode([String: Date].self, from: metadataData) {
            lastFetchTimes = metadata
        }
        
        if let expirationData = UserDefaults.standard.data(forKey: CacheKeys.cacheExpiration),
           let expiration = try? JSONDecoder().decode([String: Date].self, from: expirationData) {
            cacheExpirationTimes = expiration
        }
        
        // Clear expired caches on startup
        clearExpiredCaches()
    }
}

// MARK: - Cache Statistics Model
struct CacheStats {
    let trendingPostsCount: Int
    let followingPostsCount: Int
    let usersCount: Int
    let lastTrendingFetch: Date?
    let lastFollowingFetch: Date?
    
    var totalCachedItems: Int {
        return trendingPostsCount + followingPostsCount + usersCount
    }
    
    var isTrendingCacheValid: Bool {
        guard let lastFetch = lastTrendingFetch else { return false }
        return Date().timeIntervalSince(lastFetch) < 300 // 5 minutes
    }
    
    var isFollowingCacheValid: Bool {
        guard let lastFetch = lastFollowingFetch else { return false }
        return Date().timeIntervalSince(lastFetch) < 300 // 5 minutes
    }
}

// MARK: - Cache Manager Extensions
extension CacheManager {
    
    // MARK: Smart Caching for Posts
    func getCachedPosts(for feedType: FeedType) -> [PostWithDetails] {
        switch feedType {
        case .trending:
            return getTrendingPosts()
        case .following:
            return getFollowingPosts()
        }
    }
    
    func cachePosts(_ posts: [PostWithDetails], for feedType: FeedType, append: Bool = false) {
        switch feedType {
        case .trending:
            cacheTrendingPosts(posts, append: append)
        case .following:
            cacheFollowingPosts(posts, append: append)
        }
    }
    
    func isCacheValid(for feedType: FeedType) -> Bool {
        switch feedType {
        case .trending:
            return isCacheValid(for: CacheKeys.trendingPosts)
        case .following:
            return isCacheValid(for: CacheKeys.followingPosts)
        }
    }
    
    func invalidateCache(for feedType: FeedType) {
        switch feedType {
        case .trending:
            invalidateCache(for: CacheKeys.trendingPosts)
        case .following:
            invalidateCache(for: CacheKeys.followingPosts)
        }
    }
}

// MARK: - Feed Type Enum
enum FeedType: String, CaseIterable {
    case trending = "trending"
    case following = "following"
}
