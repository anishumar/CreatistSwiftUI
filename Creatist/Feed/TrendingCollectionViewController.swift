import UIKit

class TrendingCollectionViewController: UICollectionViewController {
    var posts: [PostWithDetails]
    var onPostSelected: ((PostWithDetails) -> Void)?
    var onLoadMore: (() -> Void)?

    init(posts: [PostWithDetails], onPostSelected: ((PostWithDetails) -> Void)? = nil, onLoadMore: (() -> Void)? = nil) {
        self.posts = posts
        self.onPostSelected = onPostSelected
        self.onLoadMore = onLoadMore
        let layout = UICollectionViewCompositionalLayout(section: TrendingCollectionViewController.getTrendingLayout())
        super.init(collectionViewLayout: layout)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(TrendingPostCell.self, forCellWithReuseIdentifier: "TrendingPostCell")
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return posts.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TrendingPostCell", for: indexPath) as! TrendingPostCell
        cell.configure(with: posts[indexPath.item])
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onPostSelected?(posts[indexPath.item])
    }
    
    // Infinite scrolling implementation
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let screenHeight = scrollView.frame.size.height
        
        // Load more when user scrolls to bottom (with some threshold)
        if offsetY > contentHeight - screenHeight - 100 {
            onLoadMore?()
        }
    }

    static func getTrendingLayout() -> NSCollectionLayoutSection {
        let item1 = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(0.6)
            )
        )
        item1.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        let item2 = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(0.4)
            )
        )
        item2.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        let rowGroup1 = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.5),
                heightDimension: .fractionalHeight(1)
            ),
            subitems: [item1, item2]
        )
        let rowGroup2 = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.5),
                heightDimension: .fractionalHeight(1.0)
            ),
            subitems: [item2, item1]
        )
        let gridGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(0.7)
            ),
            subitems: [rowGroup1, rowGroup2]
        )
        let landscapeItem = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(0.3)
            )
        )
        landscapeItem.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        let containerGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(600)
            ),
            subitems: [gridGroup, landscapeItem]
        )
        let section = NSCollectionLayoutSection(group: containerGroup)
        return section
    }
} 