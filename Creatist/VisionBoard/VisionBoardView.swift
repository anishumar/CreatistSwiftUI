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
    @StateObject private var cacheManager = CacheManager.shared
    @State private var pendingInvitationCount: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Always show title and segment control
                VStack(alignment: .leading, spacing: 10) {
                    Text("VisionBoard")
                        .font(.largeTitle).bold()
                        .padding(.top, 18)
                        .padding(.horizontal, 18)
                    Picker("Project Type", selection: $selectedTab) {
                        Text("My Projects").tag(0)
                        Text("Partner Projects").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                }
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
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .toolbar {
                if selectedTab == 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { 
                        showInvitations = true
                        Task { await fetchPendingInvitationCount() }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: pendingInvitationCount > 0 ? "tray.fill" : "tray")
                                .font(.system(size: 20))
                            if pendingInvitationCount > 0 {
                                Text("\(pendingInvitationCount > 99 ? "99+" : "\(pendingInvitationCount)")")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .padding(.horizontal, pendingInvitationCount > 9 ? 4 : 2)
                                    .background(
                                        Circle()
                                            .fill(Color.red)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 1.5)
                                    )
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet, onDismiss: reloadBoards) {
                CreateVisionBoardSheet(isPresented: $showCreateSheet)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationPanelView(viewModel: notificationVM)
            }
            .sheet(isPresented: $showInvitations, onDismiss: {
                Task { await fetchPendingInvitationCount() }
            }) {
                InvitationPanelView(viewModel: invitationVM)
            }
            .onAppear {
                // Load cached data for both tabs immediately
                loadCachedDataForTab(0) // My Projects
                loadCachedDataForTab(1) // Partner Projects
                
                // Then fetch fresh data
                reloadBoards()
                
                // Fetch pending invitation count
                Task { await fetchPendingInvitationCount() }
                
                NotificationCenter.default.addObserver(forName: .didRespondToInvitation, object: nil, queue: .main) { _ in
                    reloadBoards()
                    Task { await fetchPendingInvitationCount() }
                }
            }
            .onChange(of: selectedTab) { newTab in
                loadCachedDataForTab(newTab)
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: .didRespondToInvitation, object: nil)
            }
        }
    }

    func reloadBoards() {
        print("🔄 VisionBoardView: Reloading boards...")
        isLoading = true
        
        // Load cached data for current tab first
        loadCachedDataForTab(selectedTab)
        
        // Fetch fresh data in background
        Task {
            print("🔄 VisionBoardView: Fetching fresh data...")
            let my = await Creatist.shared.fetchMyVisionBoards()
            let partner = await Creatist.shared.fetchPartnerVisionBoards()
            
            await MainActor.run {
                print("🔄 VisionBoardView: Updating UI with \(my.count) my boards and \(partner.count) partner boards")
                self.myBoards = my
                self.partnerBoards = partner
                self.isLoading = false
                
                // Cache the fresh data
                cacheManager.cacheMyVisionBoards(my)
                cacheManager.cachePartnerVisionBoards(partner)
            }
        }
    }
    
    func loadCachedDataForTab(_ tab: Int) {
        print("🔄 VisionBoardView: Loading cached data for tab \(tab) (0=My, 1=Partner)")
        
        if tab == 0 {
            // My Projects tab
            let cachedMyBoards = cacheManager.getMyVisionBoards()
            print("📊 VisionBoardView: Cache check - My Projects: \(cachedMyBoards.count) boards, Current: \(myBoards.count)")
            if !cachedMyBoards.isEmpty {
                print("✅ VisionBoardView: Loading My Projects from cache - \(cachedMyBoards.count) boards")
                myBoards = cachedMyBoards
                isLoading = false
            } else if myBoards.isEmpty {
                print("⚠️ VisionBoardView: No cached My Projects data available and no current data")
                // Only show loading if we don't have any data at all
            } else {
                print("ℹ️ VisionBoardView: Using existing My Projects data - \(myBoards.count) boards")
            }
        } else {
            // Partner Projects tab
            let cachedPartnerBoards = cacheManager.getPartnerVisionBoards()
            print("📊 VisionBoardView: Cache check - Partner Projects: \(cachedPartnerBoards.count) boards, Current: \(partnerBoards.count)")
            if !cachedPartnerBoards.isEmpty {
                print("✅ VisionBoardView: Loading Partner Projects from cache - \(cachedPartnerBoards.count) boards")
                partnerBoards = cachedPartnerBoards
                isLoading = false
            } else if partnerBoards.isEmpty {
                print("⚠️ VisionBoardView: No cached Partner Projects data available and no current data")
                // Only show loading if we don't have any data at all
            } else {
                print("ℹ️ VisionBoardView: Using existing Partner Projects data - \(partnerBoards.count) boards")
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
    
    func fetchPendingInvitationCount() async {
        let accessToken = KeychainHelper.get("accessToken")
        guard let token = accessToken, !token.isEmpty else {
            await MainActor.run { self.pendingInvitationCount = 0 }
            return
        }
        
        guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/invitations/user?status=pending") else {
            await MainActor.run { self.pendingInvitationCount = 0 }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { self.pendingInvitationCount = 0 }
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected date string to be ISO8601-formatted.")
            }
            
            // Decode the response which is a dictionary with "invitations" key
            let result = try decoder.decode([String: [Invitation]].self, from: data)
            let invitations = result["invitations"] ?? []
            
            // Count only pending invitations (filter by status)
            let pendingCount = invitations.filter { $0.status.lowercased() == "pending" }.count
            
            await MainActor.run {
                self.pendingInvitationCount = pendingCount
            }
        } catch {
            print("[VisionBoardView] Error fetching pending invitation count: \(error.localizedDescription)")
            await MainActor.run { self.pendingInvitationCount = 0 }
        }
    }
}

struct VisionBoardView_Previews: PreviewProvider {
    static var previews: some View {
        VisionBoardView()
    }
}
