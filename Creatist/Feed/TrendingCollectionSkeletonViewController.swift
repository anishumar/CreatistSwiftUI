import UIKit

class TrendingCollectionSkeletonViewController: UICollectionViewController {
    
    init() {
        let layout = UICollectionViewCompositionalLayout(section: TrendingCollectionSkeletonViewController.getSkeletonLayout())
        super.init(collectionViewLayout: layout)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(TrendingPostSkeletonCell.self, forCellWithReuseIdentifier: "TrendingPostSkeletonCell")
        collectionView.backgroundColor = .clear
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 6 // Show 6 skeleton items
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TrendingPostSkeletonCell", for: indexPath) as! TrendingPostSkeletonCell
        return cell
    }
    
    static func getSkeletonLayout() -> NSCollectionLayoutSection {
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

class TrendingPostSkeletonCell: UICollectionViewCell {
    private let skeletonView = UIView()
    private let cornerRadius: CGFloat = 8
    private let cellPadding: CGFloat = 2
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSkeletonView()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupSkeletonView() {
        contentView.addSubview(skeletonView)
        skeletonView.translatesAutoresizingMaskIntoConstraints = false
        skeletonView.backgroundColor = UIColor.systemGray5
        skeletonView.layer.cornerRadius = cornerRadius
        skeletonView.layer.masksToBounds = true
        
        contentView.layer.cornerRadius = cornerRadius
        contentView.layer.masksToBounds = false
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.08
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.layer.shadowRadius = 8
        
        NSLayoutConstraint.activate([
            skeletonView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: cellPadding),
            skeletonView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: cellPadding),
            skeletonView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -cellPadding),
            skeletonView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -cellPadding)
        ])
        
        startShimmerAnimation()
    }
    
    private func startShimmerAnimation() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemGray5.cgColor,
            UIColor.systemGray4.cgColor,
            UIColor.systemGray5.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.frame = bounds
        
        skeletonView.layer.addSublayer(gradientLayer)
        
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1, -0.5, 0]
        animation.toValue = [1, 1.5, 2]
        animation.duration = 1.5
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "shimmer")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let gradientLayer = skeletonView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = skeletonView.bounds
        }
    }
}
