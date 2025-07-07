import SwiftUI

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

struct NotificationPanelView: View {
    @ObservedObject var viewModel: NotificationViewModel
    @State private var commentText: [UUID: String] = [:]

    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.notifications.isEmpty {
                    Text("No notifications.").foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.notifications) { notification in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                iconForType(notification.objectType, notification.eventType)
                                Text(notification.message).font(.headline)
                            }
                            Text("Type: \(notification.objectType.capitalized), Event: \(notification.eventType.capitalized)").font(.caption)
                            Text("Status: \(notification.status.capitalized)").font(.caption)
                            if let created = notification.createdAt as Date? {
                                Text("Received: \(created, style: .date)").font(.caption2)
                            }
                            if notification.status == "unread" {
                                HStack {
                                    Button("Accept") {
                                        Task {
                                            await viewModel.respond(to: notification, response: "Accepted", comment: commentText[notification.id] ?? "")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    Button("Reject") {
                                        Task {
                                            await viewModel.respond(to: notification, response: "Rejected", comment: commentText[notification.id] ?? "")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                TextField("Comment (optional)", text: Binding(
                                    get: { commentText[notification.id] ?? "" },
                                    set: { commentText[notification.id] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            } else {
                                Text("Responded: \(notification.status)").foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 8)
                        .onTapGesture {
                            handleNotificationClick(notification)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .onAppear {
                Task { await viewModel.fetchNotifications() }
            }
        }
    }

    func iconForType(_ objectType: String, _ eventType: String) -> some View {
        let iconName: String
        switch objectType {
        case "visionboard": iconName = "rectangle.stack"
        case "message": iconName = "envelope"
        case "showcase": iconName = "star"
        default: iconName = "bell"
        }
        return Image(systemName: iconName).foregroundColor(.blue)
    }

    func handleNotificationClick(_ notification: NotificationItem) {
        // TODO: Route based on objectType/objectId
        // Example:
        // if notification.objectType == "visionboard" { ... }
    }
}

struct InvitationPanelView: View {
    @ObservedObject var viewModel: InvitationListViewModel
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.invitations.isEmpty {
                    Text("No pending invitations.").foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.invitations) { invitation in
                        let vb: VisionBoard? = {
                            if invitation.objectType == "visionboard" {
                                return viewModel.visionBoards[invitation.objectId]
                            } else if invitation.objectType == "genre" {
                                if let genre = viewModel.genres[invitation.objectId] {
                                    return viewModel.visionBoards[genre.visionboardId]
                                }
                            }
                            return nil
                        }()
                        let genreName: String? = {
                            if invitation.objectType == "genre" {
                                return viewModel.genres[invitation.objectId]?.name
                            }
                            return nil
                        }()
                        let sender = viewModel.senders[invitation.senderId]
                        VStack(alignment: .leading, spacing: 8) {
                            if let vb = vb {
                                Text(vb.name).font(.headline)
                                if let desc = vb.description, !desc.isEmpty {
                                    Text(desc).font(.subheadline)
                                }
                                HStack {
                                    Text("Start: ")
                                    Text(vb.startDate, style: .date)
                                    Spacer()
                                    Text("End: ")
                                    Text(vb.endDate, style: .date)
                                }.font(.caption)
                            } else {
                                Text("-").font(.headline)
                            }
                            if let genreName = genreName {
                                Text("Genre: \(genreName)").font(.caption)
                            }
                            if let sender = sender {
                                Text("From: \(sender.name)").font(.caption)
                                if let genres = sender.genres, !genres.isEmpty {
                                    Text("Sender Genre: \(genres.map { $0.rawValue.capitalized }.joined(separator: ", "))").font(.caption)
                                }
                                if let rating = sender.rating {
                                    Text("Sender Rating: \(String(format: "%.1f", rating))").font(.caption)
                                }
                            }
                            if let workType = invitation.data?["work_type"]?.value as? String {
                                Text("Work Type: \(workType)").font(.caption)
                            }
                            if let payment = invitation.data?["payment_amount"]?.value as? String {
                                Text("Payment: $\(payment)").font(.caption)
                            }
                            Text("Status: \(invitation.status.capitalized)").font(.caption2)
                            if invitation.status.lowercased() == "pending" {
                                HStack {
                                    Button("Accept") {
                                        Task { await viewModel.respondToInvitation(invitation: invitation, response: "accepted") }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    Button("Reject") {
                                        Task { await viewModel.respondToInvitation(invitation: invitation, response: "rejected") }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 1)
                    }
                }
            }
            .navigationTitle("Invitations")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .onAppear {
                Task { await viewModel.fetchInvitationsAndBoards() }
            }
        }
    }
}

struct VisionBoardView_Previews: PreviewProvider {
    static var previews: some View {
        VisionBoardView()
    }
}
 