import SwiftUI

struct DetailedUserCardNoFollowCompact: View {
    let user: User
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
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
                    .frame(width: 45, height: 45)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 45, height: 45)
                        .clipShape(Circle())
                        .foregroundColor(Color(.tertiaryLabel))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let rating = user.rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .foregroundColor(Color.yellow)
                                .font(.caption2)
                            Text(String(format: "%.1f", rating))
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                    }
                }
                Spacer()
            }
            // 2x2 grid pill for details
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground).opacity(0.7))
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Location
                        HStack(spacing: 6) {
                            Image(systemName: "location")
                                .foregroundColor(.primary)
                                .font(.caption2)
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
                                .font(.caption2)
                            Text(user.paymentMode?.rawValue.capitalized ?? "-")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.bottom, 2)
                    HStack(spacing: 0) {
                        // Mode of Work (bottom left)
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .foregroundColor(.primary)
                                .font(.caption2)
                            Text(user.workMode?.rawValue ?? "-")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Genre (bottom right, first genre only)
                        HStack(spacing: 6) {
                            Image(systemName: "music.note.list")
                                .foregroundColor(.primary)
                                .font(.caption2)
                            Text(user.genres?.first?.rawValue ?? "-")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 14)
    }
} 