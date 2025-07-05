import SwiftUI

struct TopNearbyView: View {
    let genre: UserGenre
    @StateObject var viewModel = UserListViewModel()
    @State private var showSeeAllTopRated = false
    @State private var showSeeAllNearby = false

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
                            HStack(spacing: 16) {
                                ForEach(viewModel.topRatedUsers, id: \ .id) { user in
                                    UserCard(userId: user.id, viewModel: viewModel)
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
                            HStack(spacing: 16) {
                                ForEach(viewModel.nearbyUsers, id: \ .id) { user in
                                    UserCard(userId: user.id, viewModel: viewModel)
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
        .navigationTitle("\(genre.rawValue.capitalized) Artists")
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
    var user: User? {
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId })
    }
    var body: some View {
        if let user = user {
            VStack(alignment: .leading, spacing: 8) {
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
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .padding(.trailing, 8)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.headline)
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
            .frame(width: 230, height: 230)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(radius: 2)
        }
    }
}
