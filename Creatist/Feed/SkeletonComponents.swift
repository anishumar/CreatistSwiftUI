import SwiftUI

// MARK: - Skeleton Loading Components

struct SkeletonView: View {
    @State private var isAnimating = false
    let width: CGFloat?
    let height: CGFloat?
    let cornerRadius: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat? = nil, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1), Color.gray.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .opacity(isAnimating ? 0.3 : 0.7)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Feed Post Skeleton

struct FeedPostSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info skeleton
            HStack(spacing: 8) {
                SkeletonView(width: 36, height: 36, cornerRadius: 18)
                SkeletonView(width: 120, height: 16, cornerRadius: 4)
                Spacer()
            }
            
            // Media skeleton
            SkeletonView(width: nil, height: 320, cornerRadius: 12)
            
            // Action buttons skeleton
            HStack(spacing: 24) {
                SkeletonView(width: 60, height: 20, cornerRadius: 4)
                SkeletonView(width: 60, height: 20, cornerRadius: 4)
                SkeletonView(width: 40, height: 20, cornerRadius: 4)
                Spacer()
            }
            
            // Caption skeleton
            VStack(alignment: .leading, spacing: 4) {
                SkeletonView(width: nil, height: 20, cornerRadius: 4)
                SkeletonView(width: 200, height: 20, cornerRadius: 4)
            }
            
            // Tags skeleton
            HStack(spacing: 8) {
                SkeletonView(width: 60, height: 16, cornerRadius: 8)
                SkeletonView(width: 80, height: 16, cornerRadius: 8)
                SkeletonView(width: 70, height: 16, cornerRadius: 8)
                Spacer()
            }
            
            // Time skeleton
            SkeletonView(width: 80, height: 12, cornerRadius: 4)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }
}

// MARK: - Trending Post Skeleton

struct TrendingPostSkeleton: View {
    var body: some View {
        SkeletonView(cornerRadius: 8)
            .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Feed Loading View

struct FeedLoadingView: View {
    let isTrending: Bool
    
    var body: some View {
        if isTrending {
            // Trending skeleton layout
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4)
                ], spacing: 4) {
                    ForEach(0..<6, id: \.self) { _ in
                        TrendingPostSkeleton()
                    }
                }
                .padding(.horizontal, 12)
            }
        } else {
            // Following feed skeleton
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        FeedPostSkeleton()
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

// MARK: - Trending Collection Skeleton

struct TrendingCollectionSkeleton: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ], spacing: 4) {
                ForEach(0..<6, id: \.self) { _ in
                    TrendingPostSkeleton()
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

// MARK: - User Profile Project Skeleton

struct UserProfileProjectSkeleton: View {
    var body: some View {
        SkeletonView(cornerRadius: 12)
            .frame(height: 140)
    }
}

struct UserProfileProjectsSkeleton: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(0..<6, id: \.self) { _ in
                UserProfileProjectSkeleton()
            }
        }
        .padding(.horizontal, 12)
    }
}
