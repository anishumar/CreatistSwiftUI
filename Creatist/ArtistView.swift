import SwiftUI

struct SeeAllArtistsView: View {
    let title: String
    let users: [User]
    @ObservedObject var viewModel: UserListViewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(users, id: \.id) { user in
                    ExpandedUserCard(userId: user.id, viewModel: viewModel)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExpandedUserCard: View {
    let userId: UUID
    @ObservedObject var viewModel: UserListViewModel
    var user: User? {
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId })
    }
    var body: some View {
        if let user = user {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable().aspectRatio(contentMode: .fill)
                                    .foregroundColor(.gray)
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .padding(.trailing, 12)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .foregroundColor(.gray)
                            .padding(.trailing, 12)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(user.name)
                            .font(.title2).bold()
                        if let rating = user.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    Spacer()
                    FollowButton(userId: user.id, viewModel: viewModel)
                }
                if let distance = user.distance {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(String(format: "%.1f km away", distance))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                if let city = user.city, let country = user.country {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("\(city), \(country)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                } else if let city = user.city {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                if let workMode = user.workMode {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .foregroundColor(.purple)
                            .font(.caption)
                        Text(workMode.rawValue)
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
                if let paymentMode = user.paymentMode {
                    HStack(spacing: 4) {
                        Image(systemName: paymentMode == .paid ? "creditcard.fill" : "gift.fill")
                            .foregroundColor(paymentMode == .paid ? .green : .orange)
                            .font(.caption)
                        Text(paymentMode.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(paymentMode == .paid ? .green : .orange)
                    }
                }
                if let genres = user.genres, !genres.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .foregroundColor(.pink)
                            .font(.caption)
                        Text(genres.map { $0.rawValue }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.pink)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(20)
            .shadow(radius: 4)
            .padding(.horizontal)
        }
    }
} 