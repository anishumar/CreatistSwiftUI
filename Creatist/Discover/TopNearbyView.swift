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
                            .padding(.leading, 12)
                            .padding(.trailing, 12)
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
                            .padding(.leading, 12)
                            .padding(.trailing, 12)
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
            .padding(.horizontal, 12)
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
    let colorIndex: Int
    
    var user: User? {
        viewModel.topRatedUsers.first(where: { $0.id == userId }) ??
        viewModel.nearbyUsers.first(where: { $0.id == userId })
    }
    
    var body: some View {
        if let user = user {
            ZStack(alignment: .bottom) {
                Color(.secondarySystemBackground)
                // Gradient overlay (use dynamic colors)
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color(.systemBackground).opacity(0.7)]),
                    startPoint: .top, endPoint: .bottom
                )
                // User image at the top center and name below
                VStack {
                    Spacer().frame(height: 16)
                    HStack {
                        Spacer()
                        if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Color.gray
                                }
                            }
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 2))
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 2))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    Spacer().frame(height: 10)
                    Text(user.name)
                        .font(.title3).bold()
                        .foregroundColor(Color.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                }
                // Bottom action and details overlay
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        CompactFollowButton(userId: user.id, viewModel: viewModel)
                            .frame(height: 36)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 2)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(Color.secondary)
                            Text(user.city ?? "")
                                .foregroundColor(Color.secondary)
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(Color.yellow)
                            Text(String(format: "%.1f", user.rating ?? 0.0))
                                .foregroundColor(Color.primary)
                        }
                        .font(.caption)
                        .lineLimit(1)
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(Color.secondary)
                            Text(user.workMode?.rawValue ?? "")
                                .foregroundColor(Color.secondary)
                            Spacer()
                            Image(systemName: "music.note.list")
                                .foregroundColor(Color.secondary)
                            Text(user.genres?.map { $0.rawValue }.joined(separator: ", ") ?? "")
                                .foregroundColor(Color.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .font(.caption)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
            }
            .frame(width: 250, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.primary.opacity(0.08), radius: 12, x: 0, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 28))
        }
    }
}
