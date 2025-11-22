import SwiftUI

struct FollowersListView: View {
    let userId: String
    @State private var followers: [User] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Loading followers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await loadFollowers()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if followers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Followers")
                            .font(.headline)
                        Text("This user doesn't have any followers yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(followers, id: \.id) { user in
                            NavigationLink(destination: UserProfileView(userId: user.id, viewModel: UserListViewModel())) {
                                UserRowView(user: user)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Followers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadFollowers()
        }
    }
    
    func loadFollowers() async {
        isLoading = true
        errorMessage = nil
        let fetchedFollowers = await Creatist.shared.fetchFollowers(for: userId)
        await MainActor.run {
            followers = fetchedFollowers
            isLoading = false
            if followers.isEmpty && errorMessage == nil {
                // Empty list is valid, not an error
            }
        }
    }
}

struct FollowingListView: View {
    let userId: String
    @State private var following: [User] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Loading following...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await loadFollowing()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if following.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Not Following Anyone")
                            .font(.headline)
                        Text("This user is not following anyone yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(following, id: \.id) { user in
                            NavigationLink(destination: UserProfileView(userId: user.id, viewModel: UserListViewModel())) {
                                UserRowView(user: user)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadFollowing()
        }
    }
    
    func loadFollowing() async {
        isLoading = true
        errorMessage = nil
        let fetchedFollowing = await Creatist.shared.fetchFollowingList(for: userId)
        await MainActor.run {
            following = fetchedFollowing
            isLoading = false
            if following.isEmpty && errorMessage == nil {
                // Empty list is valid, not an error
            }
        }
    }
}

struct UserRowView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .foregroundColor(Color(.tertiaryLabel))
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                if let username = user.username {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

