import SwiftUI
import Foundation

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
    @State private var showAddUserSheetForGenre: IdentifiableUUID? = nil
    @State private var showReplaceUserSheetForGenre: IdentifiableUUID? = nil
    @State private var following: [User] = []
    @State private var isLoadingFollowing = false

    init(board: VisionBoard) {
        self.board = board
        _boardStatus = State(initialValue: board.status)
    }

    var activeAssignments: [GenreAssignment] {
        genres.flatMap { genre in
            genre.assignments.filter { $0.status != .rejected }
        }
    }
    
    var anyAssignmentAccepted: Bool {
        activeAssignments.contains { $0.status == .accepted }
    }
    
    var hasPendingOrRejected: Bool {
        activeAssignments.contains { $0.status == .pending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(board.name).font(.largeTitle).bold()
                if let desc = board.description, !desc.isEmpty { 
                    Text(desc) 
                }
                HStack {
                    Text("Start: ")
                    Text(board.startDate, style: .date)
                    Spacer()
                    Text("End: ")
                    Text(board.endDate, style: .date)
                }.font(.caption)
                Divider()
                if isLoading {
                    ProgressView()
                } else {
                    ForEach(genres) { genre in
                        genreSection(for: genre)
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
                startButton
            }
        }
        .alert("Are you sure you want to start this vision board? This will notify all partners and begin the project.", isPresented: $showStartConfirm) {
            Button("Start", role: .destructive) {
                startVisionBoard()
            }
            Button("Cancel", role: .cancel) {}
        }
        .background(
            NavigationLink(destination: VisionInProgressView(board: board), isActive: $showInProgress) {
                EmptyView()
            }
            .hidden()
        )
        .onAppear {
            loadGenres()
            NotificationCenter.default.addObserver(forName: .didRespondToInvitation, object: nil, queue: .main) { _ in
                loadGenres()
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .didRespondToInvitation, object: nil)
        }
        .sheet(item: $showAddUserSheetForGenre) { identifiable in
            addUserSheet(for: identifiable.id)
        }
        .sheet(item: $showReplaceUserSheetForGenre) { identifiable in
            replaceUserSheet(for: identifiable.id)
        }
    }
    
    @ViewBuilder
    private func genreSection(for genre: GenreWithAssignments) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(genre.name.capitalized).font(.headline)
                Spacer()
                if shouldShowAddButton() {
                    addButton(for: genre)
                }
            }
            
            // Active assignments
            ForEach(genre.assignments.filter { $0.status != .rejected }, id: \.id) { assignment in
                assignmentRow(for: assignment)
            }
            
            // Rejected assignments
            if !genre.assignments.filter({ $0.status == .rejected }).isEmpty {
                ForEach(genre.assignments.filter { $0.status == .rejected }, id: \.id) { assignment in
                    rejectedAssignmentRow(for: assignment, in: genre)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func assignmentRow(for assignment: GenreAssignment) -> some View {
        HStack {
            AssignmentRowView(assignment: assignment, board: board)
            Spacer()
            if assignment.status == .pending && assignment.userId != Creatist.shared.user?.id {
                remindButton(for: assignment)
            }
        }
    }
    
    @ViewBuilder
    private func rejectedAssignmentRow(for assignment: GenreAssignment, in genre: GenreWithAssignments) -> some View {
        RejectedAssignmentRowView(assignment: assignment, genre: genre, board: board, onReplace: {
            showReplaceUserSheetForGenre = IdentifiableUUID(id: genre.id)
            loadFollowing(for: genre)
        })
    }
    
    @ViewBuilder
    private func addButton(for genre: GenreWithAssignments) -> some View {
        Button(action: {
            showAddUserSheetForGenre = IdentifiableUUID(id: genre.id)
            loadFollowing(for: genre)
        }) {
            Image(systemName: "plus.circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.gray)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func remindButton(for assignment: GenreAssignment) -> some View {
        if remindLoading[assignment.userId] == true {
            ProgressView().frame(width: 24, height: 24)
        } else if remindSuccess[assignment.userId] == true {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        } else {
            Button(action: {
                remindUser(assignment: assignment)
            }) {
                Image(systemName: "bell")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var startButton: some View {
        if let userId = Creatist.shared.user?.id, board.createdBy == userId && boardStatus != .active && boardStatus != .completed && boardStatus != .cancelled {
            Button(action: { showStartConfirm = true }) {
                if isStarting {
                    ProgressView()
                } else {
                    Text("Start")
                }
            }
            .disabled(!anyAssignmentAccepted)
            .help(!anyAssignmentAccepted ? "At least one partner must accept their invitation before starting." : "")
        }
    }
    
    @ViewBuilder
    private func addUserSheet(for genreId: UUID) -> some View {
        if let genre = genres.first(where: { $0.id == genreId }) {
            let assignedUserIds = genre.assignments.map { $0.userId }
            AddUserSheet(
                genre: UserGenre(rawValue: genre.name) ?? .editor,
                assignedUserIds: assignedUserIds,
                onSelect: { user in
                    showAddUserSheetForGenre = nil
                    addUserToGenre(user: user, genreId: genreId)
                },
                onCancel: { showAddUserSheetForGenre = nil }
            )
        }
    }
    
    @ViewBuilder
    private func replaceUserSheet(for genreId: UUID) -> some View {
        if let genre = genres.first(where: { $0.id == genreId }) {
            let assignedUserIds = genre.assignments.map { $0.userId }
            AddUserSheet(
                genre: UserGenre(rawValue: genre.name) ?? .editor,
                assignedUserIds: assignedUserIds,
                onSelect: { user in
                    showReplaceUserSheetForGenre = nil
                    addUserToGenre(user: user, genreId: genreId)
                },
                onCancel: { showReplaceUserSheetForGenre = nil }
            )
        }
    }
    
    // Helper functions
    private func shouldShowAddButton() -> Bool {
        guard let userId = Creatist.shared.user?.id else { return false }
        return board.createdBy == userId
    }
    
    private func shouldShowReplaceButton() -> Bool {
        guard let userId = Creatist.shared.user?.id else { return false }
        return board.createdBy == userId
    }
    
    private func loadFollowing(for genre: GenreWithAssignments) {
        Task {
            isLoadingFollowing = true
            if let userId = Creatist.shared.user?.id {
                let alreadyAssigned = Set(genre.assignments.map { $0.userId })
                let allFollowing = await Creatist.shared.fetchFollowing(for: userId, genre: UserGenre(rawValue: genre.name) ?? .editor)
                following = allFollowing.filter { !alreadyAssigned.contains($0.id) }
            }
            isLoadingFollowing = false
        }
    }
    
    private func loadGenres() {
        Task {
            isLoading = true
            genres = await Creatist.shared.fetchGenresAndAssignments(for: board)
            isLoading = false
        }
    }
    
    private func startVisionBoard() {
        Task {
            isStarting = true
            let success = await Creatist.shared.startVision(board: board)
            if success {
                boardStatus = .active
                showInProgress = true
            }
            isStarting = false
        }
    }
    
    private func remindUser(assignment: GenreAssignment) {
        Task {
            remindLoading[assignment.userId] = true
            remindSuccess[assignment.userId] = false
            let _ = await Creatist.shared.remindUser(assignment: assignment)
            remindLoading[assignment.userId] = false
            remindSuccess[assignment.userId] = true
        }
    }
    
    private func addUserToGenre(user: User, genreId: UUID) {
        Task {
            let _ = await Creatist.shared.addAssignmentAndInvite(genreId: genreId, user: user, board: board)
            isLoading = true
            genres = await Creatist.shared.fetchGenresAndAssignments(for: board)
            isLoading = false
        }
    }
} 