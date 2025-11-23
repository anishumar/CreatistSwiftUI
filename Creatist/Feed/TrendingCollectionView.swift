import SwiftUI

struct TrendingCollectionView: UIViewControllerRepresentable {
    var posts: [PostWithDetails]
    var onPostSelected: (PostWithDetails) -> Void
    var onLoadMore: (() -> Void)?

    func makeUIViewController(context: Context) -> TrendingCollectionViewController {
        TrendingCollectionViewController(posts: posts, onPostSelected: onPostSelected, onLoadMore: onLoadMore)
    }

    func updateUIViewController(_ uiViewController: TrendingCollectionViewController, context: Context) {
        uiViewController.posts = posts
        uiViewController.collectionView.reloadData()
    }
}

struct TrendingCollectionSkeletonView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> TrendingCollectionSkeletonViewController {
        TrendingCollectionSkeletonViewController()
    }

    func updateUIViewController(_ uiViewController: TrendingCollectionSkeletonViewController, context: Context) {
        // No updates needed for skeleton view
    }
} 