import SwiftUI
import Foundation
import PhotosUI

struct VisionInProgressView: View {
    let board: VisionBoard
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss
    @State private var showGroupChat = false
    @State private var groupChatManager: ChatWebSocketManager? = nil
    // Drafts section state
    @State private var drafts: [Draft] = []
    @State private var showDraftPicker = false
    @State private var selectedDraft: Draft? = nil
    @State private var showDraftPreview = false
    @State private var draftPickerItem: PhotosPickerItem? = nil
    @State private var isUploadingDraft = false
    @State private var draftUploadError: String? = nil
    // State for edit/delete
    @State private var showEditDraftSheet = false
    @State private var draftToDelete: Draft? = nil
    @State private var showDeleteDraftAlert = false
    // Multi-select state
    @State private var isSelectingDrafts = false
    @State private var selectedDrafts: Set<UUID> = []
    @State private var showCreatePostSheet = false
    @State private var boardGenres: [String] = []
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 32) {
            // Section 0: Vision Details with chevron
            VStack(spacing: 0) {
                HStack {
                    Text(board.name)
                        .font(.title).bold()
                        .foregroundColor(Color.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Button(action: { withAnimation { showDetails.toggle() } }) {
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                }
                if showDetails {
                    if let desc = board.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(Color.secondary)
                            .padding(.top, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 16) {
                        Text("Start: ")
                            .font(.caption).foregroundColor(Color.secondary)
                        Text(board.startDate, style: .date)
                            .font(.caption)
                            .foregroundColor(Color.primary)
                        Spacer(minLength: 12)
                        Text("End: ")
                            .font(.caption).foregroundColor(Color.secondary)
                        Text(board.endDate, style: .date)
                            .font(.caption)
                            .foregroundColor(Color.primary)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal)

            Button(action: {
                if let user = Creatist.shared.user {
                    let urlString = EnvironmentConfig.shared.wsURL(for: "/ws/visionboard/\(board.id.uuidString)/group-chat?token=\(KeychainHelper.get("accessToken") ?? "")")
                    if let url = URL(string: urlString) {
                        groupChatManager = ChatWebSocketManager(
                            url: url,
                            token: KeychainHelper.get("accessToken") ?? "",
                            userId: user.id.uuidString,
                            isGroupChat: true,
                            visionboardId: board.id.uuidString
                        )
                    }
                }
                showGroupChat = true
            }) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Chat with your collaborators")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)
            }
            .frame(width: 363, height: 100)
            // Section 1: Assign Tasks
            VStack {
                Spacer()
                Text("Assign Tasks")
                    .font(.title2).bold()
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
            .frame(width: 363, height: 210)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(10)
            // Section 2: Drafts
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Drafts")
                        .font(.headline)
                        .foregroundColor(Color.primary)
                    Spacer()
                    if isSelectingDrafts {
                        Button(action: {
                            withAnimation {
                                isSelectingDrafts = false
                                selectedDrafts.removeAll()
                            }
                        }) {
                            Text("Cancel")
                                .font(.subheadline).bold()
                                .foregroundColor(Color.primary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color(.systemGray5)))
                        }
                        .buttonStyle(.plain)
                        if !selectedDrafts.isEmpty {
                            Button(action: {
                                Task {
                                    isUploadingDraft = true
                                    let idsToDelete = selectedDrafts
                                    for draftId in idsToDelete {
                                        if await Creatist.shared.deleteDraft(draftId: draftId) {
                                            withAnimation { drafts.removeAll { $0.id == draftId } }
                                        }
                                    }
                                    isUploadingDraft = false
                                    withAnimation {
                                        isSelectingDrafts = false
                                        selectedDrafts.removeAll()
                                    }
                                }
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color(.systemGray4)))
                            }
                            .buttonStyle(.plain)
                            Button(action: {
                                showCreatePostSheet = true
                            }) {
                                Text("Post")
                                    .font(.subheadline).bold()
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color(.systemGray5)))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button(action: {
                            withAnimation {
                                isSelectingDrafts = true
                                selectedDrafts.removeAll()
                            }
                        }) {
                            Text("Select")
                                .font(.subheadline).bold()
                                .foregroundColor(Color.primary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color(.systemGray5)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        // Plus icon for adding draft
                        PhotosPicker(selection: $draftPickerItem, matching: .any(of: [.images, .videos])) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                Image(systemName: "plus")
                                    .font(.title)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .disabled(isUploadingDraft)
                        // Show uploading indicator
                        if isUploadingDraft {
                            ProgressView()
                        }
                        // Draft thumbnails
                        ForEach(drafts) { draft in
                            ZStack {
                                if isSelectingDrafts {
                                    Button(action: {
                                        if selectedDrafts.contains(draft.id) {
                                            selectedDrafts.remove(draft.id)
                                        } else {
                                            selectedDrafts.insert(draft.id)
                                        }
                                    }) {
                                        ZStack(alignment: .topTrailing) {
                                            if draft.mediaType == "video" {
                                                Image(systemName: "video.fill")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 100, height: 100)
                                                    .foregroundColor(.accentColor)
                                            } else {
                                                AsyncImage(url: URL(string: draft.mediaUrl)) { phase in
                                                    if let image = phase.image {
                                                        image.resizable().aspectRatio(contentMode: .fill)
                                                    } else if phase.error != nil {
                                                        Image(systemName: "doc")
                                                            .resizable().aspectRatio(contentMode: .fit)
                                                            .foregroundColor(Color(.tertiaryLabel))
                                                    } else {
                                                        ProgressView()
                                                    }
                                                }
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                            // Selection indicator overlay (inside image)
                                            Group {
                                                if selectedDrafts.contains(draft.id) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 22))
                                                        .foregroundColor(.accentColor)
                                                        .background(Color.white.clipShape(Circle()).frame(width: 24, height: 24))
                                                } else {
                                                    Image(systemName: "circle")
                                                        .font(.system(size: 22))
                                                        .foregroundColor(.white)
                                                        .background(Color.black.opacity(0.3).clipShape(Circle()).frame(width: 24, height: 24))
                                                }
                                            }
                                            .padding([.top, .trailing], 4)
                                            if selectedDrafts.contains(draft.id) {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.accentColor.opacity(0.4))
                                                    .frame(width: 100, height: 100)
                                            }
                                        }
                                    }
                                } else {
                                    Button(action: {
                                        selectedDraft = draft
                                        showDraftPreview = true
                                    }) {
                                        ZStack {
                                            if draft.mediaType == "video" {
                                                Image(systemName: "video.fill")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 100, height: 100)
                                                    .foregroundColor(.accentColor)
                                            } else {
                                                AsyncImage(url: URL(string: draft.mediaUrl)) { phase in
                                                    if let image = phase.image {
                                                        image.resizable().aspectRatio(contentMode: .fill)
                                                    } else if phase.error != nil {
                                                        Image(systemName: "doc")
                                                            .resizable().aspectRatio(contentMode: .fit)
                                                            .foregroundColor(Color(.tertiaryLabel))
                                                    } else {
                                                        ProgressView()
                                                    }
                                                }
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                        }
                                    }
                                    .contextMenu {
                                        Button("Edit") {
                                            selectedDraft = draft
                                            showEditDraftSheet = true
                                        }
                                        Button(role: .destructive) {
                                            draftToDelete = draft
                                            showDeleteDraftAlert = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .simultaneousGesture(LongPressGesture().onEnded { _ in
                                if !isSelectingDrafts {
                                    print("[DEBUG] Long-press triggered for draft \(draft.id)")
                                    withAnimation {
                                        isSelectingDrafts = true
                                        selectedDrafts = [draft.id]
                                    }
                                }
                            })
                        }
                    }
                    .padding(.vertical, 4)
                }
                if let error = draftUploadError {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
            Spacer()
            // Multi-select toolbar/floating button
        }
        .padding()
        .onAppear {
            Task {
                drafts = await Creatist.shared.fetchDrafts(forVisionBoardId: board.id)
            }
        }
        .onChange(of: draftPickerItem) { newItem in
            if let newItem {
                Task {
                    isUploadingDraft = true
                    draftUploadError = nil
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        var mediaType: String = "image"
                        if let type = newItem.supportedContentTypes.first, type.conforms(to: .movie) {
                            mediaType = "video"
                        }
                        if let publicUrl = await Creatist.shared.uploadDraftMedia(data: data, mediaType: mediaType) {
                            if let draft = await Creatist.shared.uploadDraft(for: board.id, mediaUrl: publicUrl, mediaType: mediaType) {
                                drafts.append(draft)
                            }
                        } else {
                            draftUploadError = "Failed to upload draft."
                        }
                    }
                    isUploadingDraft = false
                }
            }
        }
        .fullScreenCover(isPresented: $showGroupChat) {
            if let user = Creatist.shared.user {
                if let manager = groupChatManager {
                    ChatView(
                        manager: manager,
                        currentUserId: user.id.uuidString,
                        title: "Group Chat"
                    )
                } else {
                    ProgressView("Initializing chat...")
                        .onAppear {
                            let urlString = EnvironmentConfig.shared.wsURL(for: "/ws/visionboard/\(board.id.uuidString)/group-chat?token=\(KeychainHelper.get("accessToken") ?? "")")
                            if let url = URL(string: urlString) {
                                groupChatManager = ChatWebSocketManager(
                                    url: url,
                                    token: KeychainHelper.get("accessToken") ?? "",
                                    userId: user.id.uuidString,
                                    isGroupChat: true,
                                    visionboardId: board.id.uuidString
                                )
                            }
                        }
                }
            } else {
                ProgressView("Loading user...")
            }
        }
        // Draft preview sheet
        .sheet(item: $selectedDraft) { draft in
            DraftPreviewSheet(draft: draft)
        }
        .sheet(isPresented: $showEditDraftSheet) {
            if let draft = selectedDraft {
                EditDraftSheet(draft: draft) { updatedDraft in
                    if let idx = drafts.firstIndex(where: { $0.id == updatedDraft.id }) {
                        withAnimation { drafts[idx] = updatedDraft }
                    }
                    showEditDraftSheet = false
                }
            }
        }
        .alert("Delete Draft?", isPresented: $showDeleteDraftAlert, presenting: draftToDelete) { draft in
            Button("Delete", role: .destructive) {
                Task {
                    if await Creatist.shared.deleteDraft(draftId: draft.id) {
                        withAnimation { drafts.removeAll { $0.id == draft.id } }
                    }
                    showDeleteDraftAlert = false
                }
            }
            Button("Cancel", role: .cancel) { showDeleteDraftAlert = false }
        } message: { _ in
            Text("Are you sure you want to delete this draft?")
        }
        .sheet(isPresented: $showCreatePostSheet, onDismiss: {
            withAnimation {
                isSelectingDrafts = false
                selectedDrafts.removeAll()
            }
        }) {
            let selected = drafts.filter { selectedDrafts.contains($0.id) }
            CreatePostSheet(drafts: selected, genres: boardGenres) {
                showCreatePostSheet = false
            }
        }
        .onChange(of: showCreatePostSheet) { show in
            if show {
                Task {
                    boardGenres = await Creatist.shared.fetchGenresForVisionBoard(board.id)
                }
            }
        }
    }
}

// Draft preview and comments sheet
struct DraftPreviewSheet: View {
    let draft: Draft
    @Environment(\.dismiss) var dismiss
    @State private var comments: [DraftComment] = []
    @State private var newComment: String = ""
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var editingCommentId: UUID? = nil
    @State private var editingCommentText: String = ""
    @State private var commentToDelete: DraftComment? = nil
    @State private var showDeleteCommentAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if draft.mediaType == "video" {
                    Image(systemName: "video.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 240)
                        .foregroundColor(.accentColor)
                } else {
                    AsyncImage(url: URL(string: draft.mediaUrl)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        } else if phase.error != nil {
                            Image(systemName: "doc")
                                .resizable().aspectRatio(contentMode: .fit)
                                .foregroundColor(Color(.tertiaryLabel))
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxHeight: 240)
                }
                Divider()
                Text("Comments").font(.headline)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(comments) { comment in
                            HStack(alignment: .top) {
                                Text(comment.userId.uuidString.prefix(6))
                                    .font(.caption).bold().foregroundColor(.accentColor)
                                if editingCommentId == comment.id {
                                    TextField("Edit comment", text: $editingCommentText)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    Button("Save") {
                                        Task {
                                            isLoading = true
                                            if let updated = await Creatist.shared.updateDraftComment(commentId: comment.id, comment: editingCommentText) {
                                                if let idx = comments.firstIndex(where: { $0.id == updated.id }) {
                                                    withAnimation { comments[idx] = updated }
                                                }
                                                editingCommentId = nil
                                            }
                                            isLoading = false
                                        }
                                    }
                                    Button("Cancel") { editingCommentId = nil }
                                } else {
                                    Text(comment.comment)
                                        .font(.body)
                                        .foregroundColor(Color.primary)
                                    if comment.userId == Creatist.shared.user?.id {
                                        Menu {
                                            Button("Edit") {
                                                editingCommentId = comment.id
                                                editingCommentText = comment.comment
                                            }
                                            Button(role: .destructive) {
                                                commentToDelete = comment
                                                showDeleteCommentAlert = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis")
                                                .foregroundColor(Color(.tertiaryLabel))
                                        }
                                    }
                                }
                                Spacer()
                                Text(comment.createdAt, style: .time)
                                    .font(.caption2).foregroundColor(.gray)
                            }
                        }
                    }
                }
                HStack {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Send") {
                        Task {
                            isLoading = true
                            error = nil
                            if let comment = await Creatist.shared.addDraftComment(draftId: draft.id, comment: newComment) {
                                withAnimation { comments.append(comment) }
                                newComment = ""
                            } else {
                                error = "Failed to add comment."
                            }
                            isLoading = false
                        }
                    }.disabled(newComment.isEmpty || isLoading)
                }
                if let error = error {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
            .padding()
            .navigationTitle("Draft Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    comments = await Creatist.shared.fetchDraftComments(forDraftId: draft.id)
                }
            }
            .alert("Delete Comment?", isPresented: $showDeleteCommentAlert, presenting: commentToDelete) { comment in
                Button("Delete", role: .destructive) {
                    Task {
                        if await Creatist.shared.deleteDraftComment(commentId: comment.id) {
                            withAnimation { comments.removeAll { $0.id == comment.id } }
                        }
                        showDeleteCommentAlert = false
                    }
                }
                Button("Cancel", role: .cancel) { showDeleteCommentAlert = false }
            } message: { _ in
                Text("Are you sure you want to delete this comment?")
            }
        }
    }
}

// EditDraftSheet
struct EditDraftSheet: View {
    @State var draft: Draft
    var onSave: (Draft) -> Void
    @State private var newDescription: String = ""
    @State private var isSaving = false
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Description")) {
                    TextField("Description", text: $newDescription)
                }
                // Optionally add media replacement here
            }
            .navigationTitle("Edit Draft")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            if let updated = await Creatist.shared.updateDraft(draftId: draft.id, mediaUrl: nil, mediaType: nil, description: newDescription) {
                                onSave(updated)
                                dismiss()
                            }
                            isSaving = false
                        }
                    }.disabled(isSaving)
                }
            }
            .onAppear { newDescription = draft.description ?? "" }
        }
    }
}

// CreatePostSheet
struct CreatePostSheet: View {
    let drafts: [Draft]
    let genres: [String]
    var onPost: () -> Void
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var tags: String = ""
    @Environment(\.dismiss) var dismiss
    @State private var isPosting = false
    @State private var postError: String? = nil
    var collaborators: [UUID] {
        Array(Set(drafts.map { $0.userId }))
    }
    var mediaUrls: [String] {
        drafts.map { $0.mediaUrl }
    }
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Collaborators
                    if collaborators.count > 1 {
                        HStack(spacing: 12) {
                            ForEach(collaborators, id: \.self) { userId in
                                Circle().fill(Color.accentColor.opacity(0.2)).frame(width: 40, height: 40)
                                // TODO: Replace with user image if available
                                Text(userId.uuidString.prefix(6)).font(.caption)
                            }
                        }
                        Text("Collaborators").font(.caption).foregroundColor(.gray)
                    }
                    // Media preview
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(mediaUrls, id: \.self) { url in
                                AsyncImage(url: URL(string: url)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else if phase.error != nil {
                                        Image(systemName: "doc").resizable().aspectRatio(contentMode: .fit).foregroundColor(Color(.tertiaryLabel))
                                    } else {
                                        ProgressView()
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    // Title
                    TextField("Title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    // Description
                    TextField("Description", text: $description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    // Genres (from vision board)
                    if !genres.isEmpty {
                        Text("Genres: " + genres.joined(separator: ", "))
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    // Tags
                    TextField("Tags (comma separated)", text: $tags)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    if let postError = postError {
                        Text(postError).foregroundColor(.red).font(.caption)
                    }
                    if isPosting {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                }
                .padding()
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            isPosting = true
                            postError = nil
                            let newPostId = UUID()
                            guard let userId = Creatist.shared.user?.id else {
                                postError = "User not found"; isPosting = false; return
                            }
                            // 1. Upload all media to Supabase Storage (if not already in posts bucket)
                            var mediaArray: [PostMediaCreate] = []
                            for (idx, draft) in drafts.enumerated() {
                                let url = draft.mediaUrl
                                let isAlreadyInPostsBucket = url.contains("/storage/v1/object/public/posts/")
                                var finalUrl: String? = url
                                var mediaType: String? = draft.mediaType
                                if !isAlreadyInPostsBucket {
                                    do {
                                        let (data, _) = try await URLSession.shared.data(from: URL(string: url)!)
                                        if let uploadedUrl = await Creatist.shared.uploadPostMedia(data: data, mediaType: mediaType ?? "image", userId: userId, postId: newPostId) {
                                            finalUrl = uploadedUrl
                                        } else {
                                            postError = "Failed to upload media: \(url)"
                                            isPosting = false
                                            return
                                        }
                                    } catch {
                                        postError = "Upload error: \(error.localizedDescription)"
                                        isPosting = false
                                        return
                                    }
                                }
                                guard let mediaType = mediaType, let finalUrl = finalUrl else {
                                    postError = "Missing media type or URL"
                                    isPosting = false
                                    return
                                }
                                mediaArray.append(PostMediaCreate(url: finalUrl, type: mediaType, order: idx))
                            }
                            // 2. Build collaborators array
                            let visionboardId = drafts.first?.visionboardId
                            var collaboratorsArray: [PostCollaboratorCreate] = []
                            if let visionboardId = visionboardId {
                                collaboratorsArray = await Creatist.shared.buildCollaboratorsForVisionboard(visionboardId: visionboardId)
                            }
                            let isCollaborative = !collaboratorsArray.isEmpty
                            // 3. Build tags array
                            let tagsArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                            // 4. Call createPost
                            let postId = await Creatist.shared.createPost(
                                caption: title.isEmpty ? nil : title,
                                media: mediaArray,
                                tags: tagsArray,
                                status: "public",
                                sharedFromPostId: nil,
                                visionboardId: visionboardId
                            )
                            if let postId = postId {
                                isPosting = false
                                onPost()
                                dismiss()
                            } else {
                                postError = "Failed to create post."
                                isPosting = false
                            }
                        }
                    }.disabled(title.isEmpty || mediaUrls.isEmpty || isPosting)
                }
            }
        }
    }
} 