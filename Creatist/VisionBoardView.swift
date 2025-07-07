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
                                    NavigationLink(destination: board.status == .active ? AnyView(VisionInProgressView(board: board)) : AnyView(VisionDetailView(board: board))) {
                                        VisionBoardCard(board: board)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            } else {
                                ForEach(partnerBoards) { board in
                                    NavigationLink(destination: board.status == .active ? AnyView(VisionInProgressView(board: board)) : AnyView(VisionDetailView(board: board))) {
                                        VisionBoardCard(board: board)
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
                                        Task {
                                            await viewModel.respondToInvitation(invitation: invitation, response: "accepted")
                                            NotificationCenter.default.post(name: .didRespondToInvitation, object: nil)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    Button("Reject") {
                                        Task {
                                            await viewModel.respondToInvitation(invitation: invitation, response: "rejected")
                                            NotificationCenter.default.post(name: .didRespondToInvitation, object: nil)
                                        }
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

struct VisionDetailView: View {
    let board: VisionBoard
    @State private var genres: [GenreWithAssignments] = []
    @State private var isLoading = true
    @State private var showInProgress = false
    @State private var boardStatus: VisionBoardStatus
    @State private var isStarting = false
    @State private var showStartConfirm = false
    @State private var remindLoading: [UUID: Bool] = [:]
    @State private var remindSuccess: [UUID: Bool] = [:]

    init(board: VisionBoard) {
        self.board = board
        _boardStatus = State(initialValue: board.status)
    }

    var allAssignmentsAccepted: Bool {
        genres.flatMap { $0.assignments }.allSatisfy { $0.status == .accepted }
    }

    var isCreator: Bool {
        if let currentUserId = Creatist.shared.user?.id {
            return board.createdBy == currentUserId
        }
        return false
    }

    var canStart: Bool {
        allAssignmentsAccepted && isCreator && boardStatus != .active && boardStatus != .completed && boardStatus != .cancelled
    }

    var pendingAssignments: [GenreAssignment] {
        genres.flatMap { $0.assignments }.filter { $0.status == .pending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(board.name).font(.largeTitle).bold()
                if let desc = board.description, !desc.isEmpty { Text(desc) }
                HStack {
                    Text("Start: ")
                    Text(board.startDate, style: .date)
                    Spacer()
                    Text("End: ")
                    Text(board.endDate, style: .date)
                }.font(.caption)
                Divider()
                if !pendingAssignments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pending Users:").font(.headline)
                        ForEach(pendingAssignments, id: \.id) { assignment in
                            HStack {
                                AssignmentRowView(assignment: assignment)
                                Spacer()
                                if remindLoading[assignment.userId] == true {
                                    ProgressView().frame(width: 24, height: 24)
                                } else if remindSuccess[assignment.userId] == true {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                } else {
                                    Button("Remind") {
                                        remindUser(assignment: assignment)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                if isLoading {
                    ProgressView()
                } else {
                    ForEach(genres) { genre in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(genre.name).font(.headline)
                            ForEach(genre.assignments, id: \.id) { assignment in
                                AssignmentRowView(assignment: assignment)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Vision Board Detail")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isCreator && boardStatus != .active && boardStatus != .completed && boardStatus != .cancelled {
                    Button(action: { showStartConfirm = true }) {
                        if isStarting {
                            ProgressView()
                        } else {
                            Text("Start")
                        }
                    }
                    .disabled(!allAssignmentsAccepted)
                    .help(!allAssignmentsAccepted ? "All partners must accept their invitation before starting." : "")
                }
            }
        }
        .alert("Are you sure you want to start this vision board? This will notify all partners and begin the project.", isPresented: $showStartConfirm) {
            Button("Start", role: .destructive, action: startVision)
            Button("Cancel", role: .cancel) {}
        }
        .background(
            NavigationLink(destination: VisionInProgressView(board: board), isActive: $showInProgress) {
                EmptyView()
            }
            .hidden()
        )
        .onAppear {
            fetchGenresAndAssignments()
            NotificationCenter.default.addObserver(forName: .didRespondToInvitation, object: nil, queue: .main) { _ in
                fetchGenresAndAssignments()
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .didRespondToInvitation, object: nil)
        }
    }

    func fetchGenresAndAssignments() {
        Task {
            guard let token = KeychainHelper.get("accessToken"), !token.isEmpty else { return }
            guard let genresUrl = URL(string: NetworkManager.baseURL + "/v1/visionboard/\(board.id.uuidString.lowercased())/with-genres") else { return }
            var genresRequest = URLRequest(url: genresUrl)
            genresRequest.httpMethod = "GET"
            genresRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (genresData, genresResponse) = try await URLSession.shared.data(for: genresRequest)
                print("[DEBUG] Raw /with-genres response: \(String(data: genresData, encoding: .utf8) ?? "nil")")
                guard let genresHttp = genresResponse as? HTTPURLResponse, genresHttp.statusCode == 200 else { return }
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
                struct GenreBasic: Codable, Identifiable {
                    let id: UUID
                    let visionboardId: UUID
                    let name: String
                    let description: String?
                    let minRequiredPeople: Int
                    let maxAllowedPeople: Int?
                    let createdAt: Date
                    enum CodingKeys: String, CodingKey {
                        case id
                        case visionboardId = "visionboard_id"
                        case name
                        case description
                        case minRequiredPeople = "min_required_people"
                        case maxAllowedPeople = "max_allowed_people"
                        case createdAt = "created_at"
                    }
                }
                struct VisionBoardWithGenresResponse: Codable {
                    let message: String?
                    let visionboard: VisionBoardWithGenres
                }
                struct VisionBoardWithGenres: Codable, Identifiable {
                    let id: UUID
                    let name: String
                    let description: String?
                    let startDate: Date
                    let endDate: Date
                    let status: String
                    let createdAt: Date
                    let updatedAt: Date
                    let createdBy: UUID
                    let genres: [GenreBasic]
                    enum CodingKeys: String, CodingKey {
                        case id, name, description, status, genres
                        case startDate = "start_date"
                        case endDate = "end_date"
                        case createdAt = "created_at"
                        case updatedAt = "updated_at"
                        case createdBy = "created_by"
                    }
                }
                let result = try decoder.decode(VisionBoardWithGenresResponse.self, from: genresData)
                var genresWithAssignments: [GenreWithAssignments] = []
                for genre in result.visionboard.genres {
                    guard let genreAssignmentsUrl = URL(string: NetworkManager.baseURL + "/v1/visionboard/genres/\(genre.id.uuidString)/with-assignments") else { continue }
                    var genreAssignmentsRequest = URLRequest(url: genreAssignmentsUrl)
                    genreAssignmentsRequest.httpMethod = "GET"
                    genreAssignmentsRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    do {
                        let (assignmentsData, assignmentsResponse) = try await URLSession.shared.data(for: genreAssignmentsRequest)
                        guard let assignmentsHttp = assignmentsResponse as? HTTPURLResponse, assignmentsHttp.statusCode == 200 else { continue }
                        struct GenreWithAssignmentsResponse: Codable { let genre: GenreWithAssignments }
                        let assignmentsResult = try decoder.decode(GenreWithAssignmentsResponse.self, from: assignmentsData)
                        genresWithAssignments.append(assignmentsResult.genre)
                    } catch {
                        print("[DEBUG] Error fetching assignments for genre \(genre.id): \(error)")
                    }
                }
                await MainActor.run {
                    self.genres = genresWithAssignments
                    self.isLoading = false
                }
            } catch {
                print("[DEBUG] Error fetching genres/assignments: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    func startVision() {
        showStartConfirm = false
        Task {
            isStarting = true
            // PATCH visionboard status to Active
            guard let token = KeychainHelper.get("accessToken"), !token.isEmpty else { isStarting = false; return }
            guard let url = URL(string: NetworkManager.baseURL + "/v1/visionboard/\(board.id.uuidString.lowercased())") else { isStarting = false; return }
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let update = VisionBoardUpdate(status: .active)
            guard let body = try? JSONEncoder().encode(update) else { isStarting = false; return }
            request.httpBody = body
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { isStarting = false; return }
                await MainActor.run {
                    self.boardStatus = .active
                    self.showInProgress = true
                    self.isStarting = false
                }
            } catch {
                print("[DEBUG] Error starting vision: \(error)")
                await MainActor.run { self.isStarting = false }
            }
        }
    }

    func remindUser(assignment: GenreAssignment) {
        remindLoading[assignment.userId] = true
        remindSuccess[assignment.userId] = false
        Task {
            // TODO: Call backend notification endpoint to resend invite
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
            await MainActor.run {
                remindLoading[assignment.userId] = false
                remindSuccess[assignment.userId] = true
            }
        }
    }
}

struct VisionInProgressView: View {
    let board: VisionBoard
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 32) {
            Text("Vision In Progress!")
                .font(.largeTitle).bold()
            Text("\(board.name)")
                .font(.title2)
            Spacer()
        }
        .padding()
    }
}

struct UserResponse: Codable {
    let message: String?
    let user: User
}

struct AssignmentRowView: View {
    let assignment: GenreAssignment
    @State private var user: User? = nil
    @State private var isLoading = true
    static var userCache: [UUID: User] = [:] // Static cache for user info

    var statusColor: Color {
        switch assignment.status {
        case .accepted: return .green
        case .rejected: return .red
        default: return .orange
        }
    }

    var body: some View {
        HStack {
            if isLoading {
                ProgressView().frame(width: 32, height: 32)
                Text("Loading...")
            } else if let user = user {
                if let imageUrl = user.profileImageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill").foregroundColor(.gray)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                }
                Text(user.name)
                    .font(.body)
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .resizable()
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                Text("Unknown")
            }
            Spacer()
            Text(assignment.status.rawValue.capitalized)
                .foregroundColor(statusColor)
        }
        .onAppear {
            loadUser()
        }
    }

    private func loadUser() {
        if let cached = AssignmentRowView.userCache[assignment.userId] {
            self.user = cached
            self.isLoading = false
            return
        }
        Task {
            guard let token = KeychainHelper.get("accessToken"), !token.isEmpty else { return }
            guard let url = URL(string: NetworkManager.baseURL + "/v1/users/\(assignment.userId.uuidString)") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let userResponse = try decoder.decode(UserResponse.self, from: data)
                let user = userResponse.user
                AssignmentRowView.userCache[assignment.userId] = user
                await MainActor.run {
                    self.user = user
                    self.isLoading = false
                }
            } catch {
                print("[DEBUG] Error fetching user info for assignment: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct VisionBoardView_Previews: PreviewProvider {
    static var previews: some View {
        VisionBoardView()
    }
}
 