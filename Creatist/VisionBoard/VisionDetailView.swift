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
                if let desc = board.description, !desc.isEmpty { Text(desc) }
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
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(genre.name.capitalized).font(.headline)
                                Spacer()
                                if let userId = Creatist.shared.user?.id, genre.assignments.contains(where: { $0.status == .pending }) && board.createdBy == userId {
                                    Button(action: {
                                        showAddUserSheetForGenre = IdentifiableUUID(id: genre.id)
                                        Task {
                                            isLoadingFollowing = true
                                            let alreadyAssigned = Set(genre.assignments.map { $0.userId })
                                            let allFollowing = await Creatist.shared.fetchFollowing(for: userId, genre: UserGenre(rawValue: genre.name) ?? .editor)
                                            following = allFollowing.filter { !alreadyAssigned.contains($0.id) }
                                            isLoadingFollowing = false
                                        }
                                    }) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            ForEach(genre.assignments.filter { $0.status != .rejected }, id: \ .id) { assignment in
                                HStack {
                                    AssignmentRowView(assignment: assignment)
                                    Spacer()
                                    if assignment.status == .pending {
                                        if remindLoading[assignment.userId] == true {
                                            ProgressView().frame(width: 24, height: 24)
                                        } else if remindSuccess[assignment.userId] == true {
                                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                        } else {
                                            Button(action: {
                                                Task {
                                                    remindLoading[assignment.userId] = true
                                                    remindSuccess[assignment.userId] = false
                                                    let _ = await Creatist.shared.remindUser(assignment: assignment)
                                                    remindLoading[assignment.userId] = false
                                                    remindSuccess[assignment.userId] = true
                                                }
                                            }) {
                                                Image(systemName: "bell")
                                                    .font(.system(size: 20, weight: .regular))
                                                    .foregroundColor(.gray)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
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
        }
        .alert("Are you sure you want to start this vision board? This will notify all partners and begin the project.", isPresented: $showStartConfirm) {
            Button("Start", role: .destructive) {
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
            Button("Cancel", role: .cancel) {}
        }
        .background(
            NavigationLink(destination: VisionInProgressView(board: board), isActive: $showInProgress) {
                EmptyView()
            }
            .hidden()
        )
        .onAppear {
            Task {
                isLoading = true
                genres = await Creatist.shared.fetchGenresAndAssignments(for: board)
                isLoading = false
            }
            NotificationCenter.default.addObserver(forName: .didRespondToInvitation, object: nil, queue: .main) { _ in
                Task {
                    isLoading = true
                    genres = await Creatist.shared.fetchGenresAndAssignments(for: board)
                    isLoading = false
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .didRespondToInvitation, object: nil)
        }
        .sheet(item: $showAddUserSheetForGenre) { identifiable in
            let genreId = identifiable.id
            AddUserSheet(followers: following, onSelect: { user in
                showAddUserSheetForGenre = nil
                Task {
                    let _ = await Creatist.shared.addAssignmentAndInvite(genreId: genreId, user: user, board: board)
                    isLoading = true
                    genres = await Creatist.shared.fetchGenresAndAssignments(for: board)
                    isLoading = false
                }
            }, onCancel: { showAddUserSheetForGenre = nil })
        }
    }
}

// Paste the full VisionDetailView struct here, as extracted from VisionBoardView.swift
// (Omitted here for brevity, but will include the full struct and its methods) 

// In VisionDetailView, replace:
// - fetchGenresAndAssignments() with: genres = await Creatist.shared.fetchGenresAndAssignments(for: board)
// - startVision() with: let success = await Creatist.shared.startVision(board: board)
// - remindUser(assignment:) with: let _ = await Creatist.shared.remindUser(assignment: assignment)
// - addAssignmentAndInvite(for: user:) with: let _ = await Creatist.shared.addAssignmentAndInvite(genreId: genreId, user: user, board: board)
// Remove the old local methods. 