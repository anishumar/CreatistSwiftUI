import SwiftUI

struct TopNearbyView: View {
    let genre: UserGenre
    @StateObject var viewModel = UserListViewModel()
    @State private var showSeeAllTopRated = false
    @State private var showSeeAllNearby = false
    @State private var selectedUserId: UUID? = nil

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    if !viewModel.topRatedUsers.isEmpty {
                        SectionHeader(title: "Top Rated") {
                            showSeeAllTopRated = true
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(Array(viewModel.topRatedUsers.enumerated()), id: \ .element.id) { idx, user in
                                    UserCard(userId: user.id, viewModel: viewModel, colorIndex: idx)
                                        .frame(width: 250, height: 260)
                                        .onTapGesture {
                                            selectedUserId = user.id
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    if !viewModel.nearbyUsers.isEmpty {
                        SectionHeader(title: "Nearby") {
                            showSeeAllNearby = true
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(Array(viewModel.nearbyUsers.enumerated()), id: \ .element.id) { idx, user in
                                    UserCard(userId: user.id, viewModel: viewModel, colorIndex: idx)
                                        .frame(width: 250, height: 260)
                                        .onTapGesture {
                                            selectedUserId = user.id
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    if viewModel.topRatedUsers.isEmpty && viewModel.nearbyUsers.isEmpty {
                        Text("No users found for \(genre.rawValue.capitalized)")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("\(genre.rawValue.capitalized)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchUsers(for: genre)
        }
        .onAppear {
            Task {
                await viewModel.fetchUsers(for: genre)
            }
        }
        .navigationDestination(isPresented: $showSeeAllTopRated) {
            SeeAllArtistsView(title: "Top Rated", users: viewModel.topRatedUsers, viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showSeeAllNearby) {
            SeeAllArtistsView(title: "Nearby", users: viewModel.nearbyUsers, viewModel: viewModel)
        }
        .navigationDestination(item: $selectedUserId) { userId in
            UserProfileView(userId: userId, viewModel: viewModel)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let seeAllAction: () -> Void
    var body: some View {
        HStack {
            Text(title)
                .font(.title2).bold()
            Spacer()
            Button(action: seeAllAction) {
                Text("See all")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal)
    }
}

struct UserCard: View {
    let userId: UUID
    @ObservedObject var viewModel: UserListViewModel
    let colorIndex: Int // <-- Add this parameter
    var user: User? {
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId })
    }
    var body: some View {
        if let user = user {
            VStack(spacing: 12) {
                // Profile image
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
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .padding(.top, 8)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
                // Name
                Text(user.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                // Info rows
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "location")
                        Text(user.city ?? "")
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "star.fill")
                        Text(String(format: "%.1f", user.rating ?? 0.0))
                    }
                    .font(.subheadline)
                    HStack {
                        Image(systemName: "globe")
                        Text(user.workMode?.rawValue ?? "")
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "doc.text")
                        Text("0") // Placeholder for projects
                    }
                    .font(.subheadline)
                    HStack {
                        Image(systemName: "music.note.list")
                        Text(user.genres?.map { $0.rawValue }.joined(separator: ", ") ?? "")
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                }
                // Follow button at the bottom
                CompactFollowButton(userId: user.id, viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: 234)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
        }
    }
}
