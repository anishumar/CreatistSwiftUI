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
                drafts = await Creatist.shared.fetchDrafts(for: board.id)
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
                        let supabaseBucket = "profile-images" // or a drafts bucket if you have one
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
    }
}

// Draft preview and comments sheet
struct DraftPreviewSheet: View {
    let draft: Draft
    @State private var comments: [DraftComment] = []
    @State private var newComment: String = ""
    @State private var isLoading = false
    @State private var error: String? = nil

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
                                Text(comment.comment)
                                    .font(.body)
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
                                comments.append(comment)
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
                    comments = await Creatist.shared.fetchDraftComments(for: draft.id)
                }
            }
        }
    }
} 