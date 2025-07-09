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

    var body: some View {
        VStack(spacing: 32) {
            // Section 0: Group Chat
            Text("Vision In Progress!")
                .font(.largeTitle).bold()
            Text("\(board.name)")
                .font(.title2)
            Button(action: {
                if let user = Creatist.shared.user {
                    let urlString = "ws://localhost:8080/ws/visionboard/\(board.id.uuidString)/group-chat?token=\(KeychainHelper.get("accessToken") ?? "")"
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
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Open Group Chat")
                }
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)
            }
            // Section 1: (Task manager placeholder)
            // ...
            // Section 2: Drafts
            VStack(alignment: .leading, spacing: 8) {
                Text("Drafts")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        // Plus icon for adding draft
                        PhotosPicker(selection: $draftPickerItem, matching: .any(of: [.images, .videos])) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 56, height: 56)
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
                                Button(action: {
                                    selectedDraft = draft
                                    showDraftPreview = true
                                }) {
                                    ZStack {
                                        if draft.mediaType == "video" {
                                            Image(systemName: "video.fill")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 56, height: 56)
                                                .foregroundColor(.accentColor)
                                        } else {
                                            AsyncImage(url: URL(string: draft.mediaUrl)) { phase in
                                                if let image = phase.image {
                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                } else if phase.error != nil {
                                                    Image(systemName: "doc")
                                                        .resizable().aspectRatio(contentMode: .fit)
                                                        .foregroundColor(.gray)
                                                } else {
                                                    ProgressView()
                                                }
                                            }
                                            .frame(width: 56, height: 56)
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
                    }
                    .padding(.vertical, 4)
                }
                if let error = draftUploadError {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
            Spacer()
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
                        let fileName: String
                        var mediaType: String = "image"
                        if let type = newItem.supportedContentTypes.first, type.conforms(to: .movie) {
                            fileName = UUID().uuidString + ".mov"
                            mediaType = "video"
                        } else {
                            fileName = UUID().uuidString + ".jpg"
                        }
                        let supabaseUrl = "https://wkmribpqhgdpklwovrov.supabase.co"
                        let supabaseBucket = "drafts" // use the dedicated drafts bucket
                        let uploadPath = "\(supabaseBucket)/\(fileName)"
                        let uploadUrlString = "\(supabaseUrl)/storage/v1/object/\(uploadPath)"
                        var request = URLRequest(url: URL(string: uploadUrlString)!)
                        request.httpMethod = "POST"
                        request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndrbXJpYnBxaGdkcGtsd292cm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE3MDY1OTksImV4cCI6MjA2NzI4MjU5OX0.N2wWfCSbjHMjHgA-stYesbcC8GZMATXug1rFew0qQOk", forHTTPHeaderField: "Authorization")
                        request.setValue(mediaType == "video" ? "video/quicktime" : "image/jpeg", forHTTPHeaderField: "Content-Type")
                        request.httpBody = data
                        do {
                            let (respData, resp) = try await URLSession.shared.data(for: request)
                            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 || httpResp.statusCode == 201 {
                                let publicUrl = "\(supabaseUrl)/storage/v1/object/public/\(supabaseBucket)/\(fileName)"
                                if let draft = await Creatist.shared.uploadDraft(for: board.id, mediaUrl: publicUrl, mediaType: mediaType) {
                                    drafts.append(draft)
                                }
                            } else {
                                draftUploadError = "Failed to upload draft."
                            }
                        } catch {
                            draftUploadError = "Upload error: \(error.localizedDescription)"
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
                            let urlString = "ws://localhost:8080/ws/visionboard/\(board.id.uuidString)/group-chat?token=\(KeychainHelper.get("accessToken") ?? "")"
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
    }
}

// Draft preview and comments sheet
struct DraftPreviewSheet: View {
    let draft: Draft
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
                                .foregroundColor(.gray)
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
                                                .foregroundColor(.gray)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
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