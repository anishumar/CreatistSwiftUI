import SwiftUI

extension Notification.Name {
    static let didRespondToInvitation = Notification.Name("didRespondToInvitation")
}

struct VisionBoardView: View {
    @State private var showCreateSheet = false
    @State private var selectedTab = 0 // 0: My Projects, 1: Partner Projects
    @State private var myBoards: [VisionBoard] = []
    @State private var partnerBoards: [VisionBoard] = []
    @State private var isLoading = false
    @State private var showNotifications = false
    @State private var showInvitations = false
    @StateObject private var notificationVM = NotificationViewModel()
    @StateObject private var invitationVM = InvitationListViewModel()
    @State private var selectedBoard: VisionBoard? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                                ForEach(Array(myBoards.enumerated()), id: \.element.id) { idx, board in
                                    NavigationLink(destination: destinationView(for: board)) {
                                        VisionBoardCard(board: board, index: idx)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            } else {
                                ForEach(Array(partnerBoards.enumerated()), id: \.element.id) { idx, board in
                                    NavigationLink(destination: destinationView(for: board)) {
                                        VisionBoardCard(board: board, index: idx)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .navigationTitle("VisionBoard")
                    .navigationBarTitleDisplayMode(.large)
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNotifications = true }) {
                        Image(systemName: "bell")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showInvitations = true }) {
                        Image(systemName: "envelope.open")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet, onDismiss: reloadBoards) {
                CreateVisionBoardSheet(isPresented: $showCreateSheet)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationPanelView(viewModel: notificationVM)
            }
            .sheet(isPresented: $showInvitations) {
                InvitationPanelView(viewModel: invitationVM)
            }
            .onAppear {
                reloadBoards()
                NotificationCenter.default.addObserver(forName: .didRespondToInvitation, object: nil, queue: .main) { _ in
                    reloadBoards()
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: .didRespondToInvitation, object: nil)
            }
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

    private func destinationView(for board: VisionBoard) -> AnyView {
        if board.status == .active {
            return AnyView(VisionInProgressView(board: board))
        } else {
            return AnyView(VisionDetailView(board: board))
        }
    }
}

struct VisionBoardView_Previews: PreviewProvider {
    static var previews: some View {
        VisionBoardView()
    }
}
 