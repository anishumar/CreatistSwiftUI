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