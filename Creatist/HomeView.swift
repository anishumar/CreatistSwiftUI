import SwiftUI

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    var body: some View {
        TabView {
            VisionBoardView()
                .tabItem {
                    Label("VisionBoard", systemImage: "person.2")
                }
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "newspaper")
                }
            ProfileView(isLoggedIn: $isLoggedIn)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
    }
}

struct VisionBoardView: View {
    var body: some View {
        Text("VisionBoard")
    }
}

struct FeedView: View {
    var body: some View {
        Text("Feed")
    }
}

struct ProfileView: View {
    @Binding var isLoggedIn: Bool
    var body: some View {
        VStack {
            Text("Profile")
                .font(.largeTitle)
                .padding()
            Spacer()
            Button(action: logout) {
                Text("Log Out")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .padding(.bottom, 40)
        }
    }
    func logout() {
        KeychainHelper.remove("email")
        KeychainHelper.remove("password")
        KeychainHelper.remove("accessToken")
        isLoggedIn = false
    }
} 