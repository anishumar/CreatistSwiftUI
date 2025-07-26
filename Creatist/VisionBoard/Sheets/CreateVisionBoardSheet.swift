import SwiftUI

struct CreateVisionBoardSheet: View {
    @Binding var isPresented: Bool

    @State private var visionName = ""
    @State private var visionDescription = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400)
    @State private var showGenreSheet = false
    @State private var selectedGenre: UserGenre? = nil
    @State private var selectedGenres: [UserGenre] = []
    @State private var showCreatorPickerForGenre: UserGenre? = nil
    @State private var followingUsers: [User] = []
    @State private var selectedCreators: [UserGenre: [User]] = [:]
    @State private var isLoadingCreators = false
    @State private var manageSheetGenre: UserGenre? = nil
    @State private var manageSheetCreator: User? = nil
    @State private var creatorDetails: [String: CreatorAssignmentDetails] = [:] // key: "genre-creatorId"
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vision Details")) {
                    TextField("Vision Name", text: $visionName)
                    TextField("Description", text: $visionDescription)
                }
                Section(header: Text("Timeline")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date",   selection: $endDate,   displayedComponents: .date)
                }
                ForEach(selectedGenres, id: \ .self) { genre in
                    Section(header:
                        HStack {
                            Text(genre.rawValue.capitalized)
                            Spacer()
                            Button(action: {
                                // Remove genre and its creators
                                selectedGenres.removeAll { $0 == genre }
                                selectedCreators[genre] = nil
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    ) {
                        // List of creators for this genre
                        if let creators = selectedCreators[genre], !creators.isEmpty {
                            ForEach(creators, id: \ .id) { creator in
                                HStack {
                                    if let urlString = creator.profileImageUrl, let url = URL(string: urlString) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().aspectRatio(contentMode: .fill)
                                            } else if phase.error != nil {
                                                Image(systemName: "person.crop.circle.fill")
                                                    .resizable().aspectRatio(contentMode: .fill)
                                                    .foregroundColor(.gray)
                                            } else {
                                                ProgressView()
                                            }
                                        }
                                        .frame(width: 28, height: 28)
                                        .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .frame(width: 28, height: 28)
                                            .clipShape(Circle())
                                            .foregroundColor(.gray)
                                    }
                                    Text(creator.name)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Button(action: {
                                        manageSheetGenre = genre
                                        manageSheetCreator = creator
                                    }) {
                                        Text("Manage")
                                            .font(.caption)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    Button(action: {
                                        // Remove this creator from the genre
                                        selectedCreators[genre]?.removeAll { $0.id == creator.id }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                        }
                        // Add Creator and Manage All buttons
                        HStack {
                            Button(action: {
                                Task {
                                    isLoadingCreators = true
                                    if let userId = Creatist.shared.user?.id {
                                        followingUsers = await Creatist.shared.fetchFollowingForGenre(userId: userId, genre: genre)
                                    } else {
                                        followingUsers = []
                                    }
                                    isLoadingCreators = false
                                    showCreatorPickerForGenre = genre
                                }
                            }) {
                                Text(isLoadingCreators && showCreatorPickerForGenre == genre ? "Loading..." : "Add Creator")
                            }
                            Spacer()
                            // Button(action: { /* Manage all logic */ }) {
                            //     Text("Manage All")
                            //         .font(.caption)
                            // }
                        }
                    }
                }
                // Add Roles button always at the bottom
                Section {
                    Button(action: { showGenreSheet = true }) {
                        HStack {
                            Text("Add Roles")
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.pink)
                        }
                    }
                    .confirmationDialog("Select a Role", isPresented: $showGenreSheet, titleVisibility: .visible) {
                        ForEach(UserGenre.allCases, id: \ .self) { genre in
                            Button(genre.rawValue.capitalized) {
                                selectedGenre = genre
                                if !selectedGenres.contains(genre) {
                                    selectedGenres.append(genre)
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("New Vision")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("OK") { isPresented = false }
            } message: {
                Text("Vision board created successfully!")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            isLoading = true
                            
                            print("🔍 DEBUG: Starting vision board creation...")
                            print("🔍 DEBUG: Vision Name: \(visionName)")
                            print("🔍 DEBUG: Selected Genres: \(selectedGenres.map { $0.rawValue })")
                            print("🔍 DEBUG: Selected Creators: \(selectedCreators)")
                            
                            // Convert to new API format
                            let genres: [GenreCreate] = selectedGenres.map { genre in
                                GenreCreate(
                                    name: genre.rawValue,
                                    description: nil,
                                    minRequiredPeople: 1,
                                    maxAllowedPeople: nil
                                )
                            }
                            
                                    // Create assignments with genre information
        var assignments: [AssignmentCreate] = []
        for (genreIndex, genre) in selectedGenres.enumerated() {
            let creators = selectedCreators[genre] ?? []
            for creator in creators {
                let key = "\(genre.rawValue)-\(creator.id.uuidString)"
                let details = creatorDetails[key] ?? CreatorAssignmentDetails()
                let paymentAmount: Decimal? =
                    (details.paymentType == .paid && !details.paymentAmount.isEmpty) ? Decimal(string: details.paymentAmount) : nil
                
                let assignment = AssignmentCreate(
                    userId: creator.id,
                    workType: WorkType(rawValue: details.workMode.rawValue) ?? .online,
                    paymentType: details.paymentType,
                    paymentAmount: paymentAmount,
                    currency: "USD",
                    genreName: genre.rawValue
                )
                assignments.append(assignment)
            }
        }
                            
                            print("🔍 DEBUG: Genres to create: \(genres.count)")
                            print("🔍 DEBUG: Assignments to create: \(assignments.count)")
                            
                            let success = await Creatist.shared.createVisionBoard(
                                name: visionName,
                                description: visionDescription.isEmpty ? nil : visionDescription,
                                startDate: startDate,
                                endDate: endDate,
                                genres: genres,
                                assignments: assignments
                            )
                            
                            print("🔍 DEBUG: createVisionBoard returned: \(success)")
                            
                            await MainActor.run {
                                isLoading = false
                                if success {
                                    showSuccess = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        isPresented = false
                                    }
                                } else {
                                    errorMessage = "Failed to create vision board."
                                    showError = true
                                }
                            }
                        }
                    }
                    .disabled(visionName.isEmpty || selectedGenres.isEmpty || isLoading)
                }
            }
            .sheet(isPresented: Binding<Bool>(
                get: { manageSheetGenre != nil && manageSheetCreator != nil },
                set: { if !$0 { manageSheetGenre = nil; manageSheetCreator = nil } }
            )) {
                if let genre = manageSheetGenre, let creator = manageSheetCreator {
                    ManageCreatorSheet(
                        genre: genre,
                        creator: creator,
                        details: creatorDetails["\(genre.rawValue)-\(creator.id.uuidString)"] ?? CreatorAssignmentDetails(),
                        onSave: { details in
                            creatorDetails["\(genre.rawValue)-\(creator.id.uuidString)"] = details
                            manageSheetGenre = nil
                            manageSheetCreator = nil
                        },
                        onCancel: {
                            manageSheetGenre = nil
                            manageSheetCreator = nil
                        }
                    )
                }
            }
            .sheet(item: $showCreatorPickerForGenre) { genre in
                CreatorPickerSheet(
                    genre: genre,
                    users: followingUsers,
                    selected: selectedCreators[genre] ?? [], // Pass selected creators for this genre
                    onSelect: { user in
                        if selectedCreators[genre] == nil {
                            selectedCreators[genre] = []
                        }
                        // Prevent duplicates
                        if !(selectedCreators[genre]?.contains(where: { $0.id == user.id }) ?? false) {
                            selectedCreators[genre]?.append(user)
                        }
                        showCreatorPickerForGenre = nil
                    },
                    onCancel: { showCreatorPickerForGenre = nil }
                )
            }
        }
    }
}

// Model for creator assignment details
struct CreatorAssignmentDetails {
    var workMode: WorkMode = .online
    var paymentType: PaymentType = .unpaid
    var paymentAmount: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(86400)
    var requiredEquipments: String = ""
}

// Sheet for managing a creator's assignment details
struct ManageCreatorSheet: View {
    let genre: UserGenre
    let creator: User
    @State var details: CreatorAssignmentDetails
    var onSave: (CreatorAssignmentDetails) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Work Mode")) {
                    Picker("Mode", selection: $details.workMode) {
                        ForEach(WorkMode.allCases, id: \ .self) { mode in
                            Text(mode.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("Payment")) {
                    Picker("Type", selection: $details.paymentType) {
                        ForEach(PaymentType.allCases, id: \ .self) { type in
                            Text(type.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    if details.paymentType == .paid {
                        TextField("Amount", text: $details.paymentAmount)
                            .keyboardType(.decimalPad)
                    }
                }
                Section(header: Text("Timeline")) {
                    DatePicker("Start Date", selection: $details.startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $details.endDate, displayedComponents: .date)
                }
                Section(header: Text("Required Equipments")) {
                    TextField("List equipments (comma separated)", text: $details.requiredEquipments)
                }
            }
            .navigationTitle("Manage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(details) }
                }
            }
        }
    }
} 