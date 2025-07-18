import SwiftUI

struct SeeAllArtistsView: View {
    let title: String
    let users: [User]
    @ObservedObject var viewModel: UserListViewModel
    @State private var selectedUserId: UUID? = nil
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(Array(users.enumerated()), id: \.element.id) { idx, user in
                    NavigationLink(destination: UserProfileView(userId: user.id, viewModel: viewModel), tag: user.id, selection: $selectedUserId) {
                        ExpandedUserCard(userId: user.id, viewModel: viewModel, colorIndex: idx)
                    }
                    .buttonStyle(PlainButtonStyle())
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
    let colorIndex: Int
    var user: User? {
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId })
    }
    var body: some View {
        if let user = user {
            VStack(alignment: .center, spacing: 16) {
                // Top: Profile image, name, rating
                HStack(alignment: .center, spacing: 16) {
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
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .foregroundColor(.gray)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.title2).bold()
                            .foregroundColor(.primary)
                        if let rating = user.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // 2x2 Grid for details
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 10) {
                    // City
                    if let city = user.city {
                        HStack(spacing: 6) {
                            Image(systemName: "location")
                                .foregroundColor(.primary)
                                .font(.caption)
                            Text(city)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Spacer(minLength: 0)
                    }
                    // Work Mode
                    if let workMode = user.workMode {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .foregroundColor(.primary)
                                .font(.caption)
                            Text(workMode.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Spacer(minLength: 0)
                    }
                    // Payment Mode
                    if let paymentMode = user.paymentMode {
                        HStack(spacing: 6) {
                            Image(systemName: paymentMode == .paid ? "creditcard.fill" : "gift.fill")
                                .foregroundColor(.primary)
                                .font(.caption)
                            Text(paymentMode.rawValue.capitalized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Spacer(minLength: 0)
                    }
                    // Genres
                    if let genres = user.genres, !genres.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "music.note.list")
                                .foregroundColor(.primary)
                                .font(.caption)
                            Text(genres.map { $0.rawValue }.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    } else {
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                // Follow button beneath grid
                HStack {
                    Spacer()
                    CompactFollowButton(userId: user.id, viewModel: viewModel)
                    Spacer()
                }
            }
            .padding()
            .frame(width: 363, height: 210)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
            .padding(.horizontal)
        }
    }
} 