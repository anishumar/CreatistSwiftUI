import SwiftUI

struct SeeAllArtistsView: View {
    let title: String
    let users: [User]
    @ObservedObject var viewModel: UserListViewModel
    @State private var selectedUserId: UUID? = nil
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(users, id: \.id) { user in
                    NavigationLink(destination: UserProfileView(userId: user.id, viewModel: viewModel), tag: user.id, selection: $selectedUserId) {
                        ExpandedUserCard(userId: user.id, viewModel: viewModel)
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
                VStack(alignment: .leading, spacing: 6) {
                    if let city = user.city {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(city)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    if let workMode = user.workMode {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.purple)
                                .font(.caption)
                            Text(workMode.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    if let paymentMode = user.paymentMode {
                        HStack {
                            Image(systemName: paymentMode == .paid ? "creditcard.fill" : "gift.fill")
                                .foregroundColor(paymentMode == .paid ? .green : .orange)
                                .font(.caption)
                            Text(paymentMode.rawValue.capitalized)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    if let genres = user.genres, !genres.isEmpty {
                        HStack {
                            Image(systemName: "music.note.list")
                                .foregroundColor(.pink)
                                .font(.caption)
                            Text(genres.map { $0.rawValue }.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding()
            .frame(width: 363, height: 220)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.regularMaterial)
                    // White gradient shine at the top
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05), .clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
            .padding(.horizontal)
        }
    }
} 