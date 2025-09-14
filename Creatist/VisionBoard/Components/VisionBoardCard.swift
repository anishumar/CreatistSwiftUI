import SwiftUI
import Foundation

// MARK: - Cached AsyncImage Component
struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: Image
    let content: (Image) -> AnyView
    
    @State private var cachedImage: UIImage?
    @State private var isLoading = false
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> AnyView) {
        self.url = url
        self.placeholder = Image(systemName: "person.crop.circle.fill")
        self.content = content
    }
    
    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                content(Image(uiImage: cachedImage))
            } else if isLoading {
                ProgressView()
                    .frame(width: 50, height: 50)
            } else {
                placeholder
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        // Check if image is already cached
        if let cached = ImageCache.shared.getImage(for: url) {
            self.cachedImage = cached
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.cachedImage = image
                        self.isLoading = false
                        // Cache the image
                        ImageCache.shared.setImage(image, for: url)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Simple Image Cache
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // Limit to 100 images
    }
    
    func getImage(for url: URL) -> UIImage? {
        return cache.object(forKey: url.absoluteString as NSString)
    }
    
    func setImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

struct VisionBoardCard: View {
    let board: VisionBoard
    let index: Int // <-- Add this parameter
    @State private var assignedUsers: [User] = []
    @State private var isLoadingUsers = true
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var cacheManager = CacheManager.shared
    
    static let flatColors: [Color] = [
        Color(red: 0.32, green: 0.56, blue: 0.67), // Muted teal
        Color(red: 0.38, green: 0.45, blue: 0.82), // Muted blue
        Color(red: 0.56, green: 0.44, blue: 0.74), // Muted purple
        Color(red: 0.92, green: 0.54, blue: 0.44), // Muted orange
        Color(red: 0.44, green: 0.62, blue: 0.56), // Muted green
        Color(red: 0.52, green: 0.48, blue: 0.68), // Muted violet
        Color(red: 0.82, green: 0.32, blue: 0.38)  // Muted red
    ]
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text(board.name)
                    .font(.system(size: 20, weight: .semibold)) // Decreased font size
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                HStack(spacing: 4) {
                    ForEach(0..<min(assignedUsers.count, 4), id: \.self) { idx in
                        let user = assignedUsers[idx]
                        if let imageUrl = user.profileImageUrl, let url = URL(string: imageUrl) {
                            CachedAsyncImage(url: url) { image in
                                AnyView(
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                )
                            }
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 50, height: 50)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(daysRemainingText)")
                    .font(.system(size: 15, weight: .medium)) // Decreased font size
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
            }
        }
        .padding()
        .frame(height: 143)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(VisionBoardCard.flatColors[index % VisionBoardCard.flatColors.count])
        )
        .shadow(radius: 8)
        .onAppear {
            loadAssignedUsers()
        }
    }
    
    private func loadAssignedUsers() {
        // Check cache manager first
        if let cached = cacheManager.getVisionBoardUsers(board.id) {
            print("✅ VisionBoardCard: Loading users from cache for board: \(board.name)")
            self.assignedUsers = cached
            self.isLoadingUsers = false
            return
        }
        
        print("🌐 VisionBoardCard: Fetching users from network for board: \(board.name)")
        Task {
            isLoadingUsers = true
            let users = await Creatist.shared.fetchVisionBoardUsers(visionBoardId: board.id)
            await MainActor.run {
                print("✅ VisionBoardCard: Fetched \(users.count) users for board: \(board.name)")
                self.assignedUsers = users
                self.isLoadingUsers = false
                // Save to cache manager
                cacheManager.cacheVisionBoardUsers(users, for: board.id)
            }
        }
    }
    
    var daysRemainingText: String {
        let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let end = calendar.startOfDay(for: board.endDate)
            let days = calendar.dateComponents([.day], from: today, to: end).day ?? 0

            return days > 0 ? "\(days) day\(days == 1 ? "" : "s") to go" : "Ended"
    }
}

// MARK: - Color Hex Extension and Theme Palette
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        var r: Double = 0, g: Double = 0, b: Double = 0, a: Double = 1.0
        let length = hexSanitized.count
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    static let themeColors: [Color] = [
        Color(hex: "#8B3952")!,
        Color(hex: "#5A3B56")!,
        Color(hex: "#4C222C")!,
        Color(hex: "#745353")!,
        Color(hex: "#6D5073")!
    ]
    static func themeColor(at index: Int) -> Color {
        return themeColors[index % themeColors.count]
    }
} 
