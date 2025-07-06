import SwiftUI

struct VisionBoardView: View {
    @State private var showCreateSheet = false
    @State private var selectedTab = 0 // 0: My Projects, 1: Partner Projects
    @State private var myBoards: [VisionBoard] = []
    @State private var partnerBoards: [VisionBoard] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack {
                Text("VisionBoard")
                    .font(.largeTitle).bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading)
                    .padding(.top)
                Picker("Project Type", selection: $selectedTab) {
                    Text("My Projects").tag(0)
                    Text("Partner Projects").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding([.horizontal, .bottom])
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            if selectedTab == 0 {
                                ForEach(myBoards) { board in
                                    VisionBoardCard(board: board)
                                }
                            } else {
                                ForEach(partnerBoards) { board in
                                    VisionBoardCard(board: board)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet, onDismiss: reloadBoards) {
                CreateVisionBoardSheet(isPresented: $showCreateSheet)
            }
            .onAppear(perform: reloadBoards)
        }
    }

    func reloadBoards() {
        print("🔄 VisionBoardView: Reloading boards...")
        isLoading = true
        Task {
            print("🔄 VisionBoardView: Fetching my vision boards...")
            let my = await Creatist.shared.fetchMyVisionBoards()
            print("🔄 VisionBoardView: Fetching partner vision boards...")
            let partner = await Creatist.shared.fetchPartnerVisionBoards()
            await MainActor.run {
                print("🔄 VisionBoardView: Updating UI with \(my.count) my boards and \(partner.count) partner boards")
                self.myBoards = my
                self.partnerBoards = partner
                self.isLoading = false
            }
        }
    }
}

struct VisionBoardCard: View {
    let board: VisionBoard
    @State private var assignedUsers: [User] = []
    @State private var isLoadingUsers = true
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text(board.name)
                    .font(.title2).bold()
                    .foregroundColor(.white)
                HStack(spacing: -12) {
                    if isLoadingUsers {
                        // Show loading placeholders
                        ForEach(0..<4, id: \.self) { idx in
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .padding(.trailing, 4)
                        }
                    } else {
                        // Show real user images
                        ForEach(0..<min(assignedUsers.count, 4), id: \.self) { idx in
                            let user = assignedUsers[idx]
                            if let imageUrl = user.profileImageUrl, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.crop.circle.fill")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .frame(width: 44, height: 44)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .padding(.trailing, 4)
                            } else {
                                // Fallback to system image if no profile image
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 44, height: 44)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .padding(.trailing, 4)
                            }
                        }
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(daysRemainingText)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(radius: 8)
        .onAppear {
            loadAssignedUsers()
        }
    }
    
    private func loadAssignedUsers() {
        Task {
            print("🔄 VisionBoardCard: Loading users for board: \(board.name) (ID: \(board.id))")
            isLoadingUsers = true
            let users = await Creatist.shared.fetchVisionBoardUsers(visionBoardId: board.id)
            await MainActor.run {
                print("🔄 VisionBoardCard: Loaded \(users.count) users for board: \(board.name)")
                for (index, user) in users.enumerated() {
                    print("   User \(index + 1): \(user.name) - Profile Image: \(user.profileImageUrl ?? "nil")")
                }
                self.assignedUsers = users
                self.isLoadingUsers = false
            }
        }
    }
    
    var daysRemainingText: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: board.endDate).day ?? 0
        return days > 0 ? "\(days) days to go" : "Ended"
    }
}

struct VisionBoardView_Previews: PreviewProvider {
    static var previews: some View {
        VisionBoardView()
    }
}
 