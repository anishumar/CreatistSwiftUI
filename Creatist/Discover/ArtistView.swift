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
            VStack(alignment: .center, spacing: 8) { // was 16, now 8 for less gap
                // Top: Profile image, name, rating
                HStack(alignment: .center, spacing: 16) {
                    if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable().aspectRatio(contentMode: .fill)
                                    .foregroundColor(Color(.tertiaryLabel))
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.title2).bold()
                            .foregroundColor(.primary)
                        if let rating = user.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(Color.yellow)
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
                HStack {
                    Spacer()
                    CompactFollowButton(userId: user.id, viewModel: viewModel)
                    Spacer()
                }
                .padding(.leading, 8)
                .padding(.bottom, 2) // add a small bottom padding for tightness
                // Capsule 2x2 grid for details
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            // Location
                            HStack(spacing: 6) {
                                Image(systemName: "location")
                                    .foregroundColor(.primary)
                                    .font(.caption)
                                Text(user.city ?? "-")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // Payment Mode (top right)
                            HStack(spacing: 6) {
                                Image(systemName: (user.paymentMode == .paid ? "creditcard.fill" : "gift.fill"))
                                    .foregroundColor(.primary)
                                    .font(.caption)
                                Text(user.paymentMode?.rawValue.capitalized ?? "-")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.bottom, 2)
                        HStack(spacing: 0) {
                            // Work Mode
                            HStack(spacing: 6) {
                                Image(systemName: "globe")
                                    .foregroundColor(.primary)
                                    .font(.caption)
                                Text(user.workMode?.rawValue ?? "-")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // Genre (first genre only for compactness)
                            HStack(spacing: 6) {
                                Image(systemName: "music.note.list")
                                    .foregroundColor(.primary)
                                    .font(.caption)
                                Text(user.genres?.first?.rawValue ?? "-")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(10)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 2)
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