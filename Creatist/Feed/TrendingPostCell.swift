import UIKit

class TrendingPostCell: UICollectionViewCell {
    let imageView = UIImageView()
    // Removed likeLabel
    private var imageTask: URLSessionDataTask?
    private let cornerRadius: CGFloat = 8
    private let cellPadding: CGFloat = 2

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = cornerRadius
        contentView.layer.cornerRadius = cornerRadius
        contentView.layer.masksToBounds = false
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.08
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.layer.shadowRadius = 8
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: cellPadding),
            imageView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: cellPadding),
            imageView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -cellPadding),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -cellPadding)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        imageView.backgroundColor = .darkGray
        imageTask?.cancel()
        imageTask = nil
    }

    func configure(with post: PostWithDetails) {
        imageView.image = nil
        imageView.backgroundColor = .darkGray
        imageTask?.cancel()
        imageTask = nil
        if let urlString = post.media.first?.url, let url = URL(string: urlString) {
            imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self, let data = data, let image = UIImage(data: data), error == nil else { return }
                DispatchQueue.main.async {
                    self.imageView.image = image
                    self.imageView.backgroundColor = .clear
                }
            }
            imageTask?.resume()
        }
    }
} 