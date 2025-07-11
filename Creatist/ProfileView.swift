import SwiftUI
import CoreLocation
import PhotosUI

struct ProfileView: View {
    @Binding var isLoggedIn: Bool
    @State private var isUpdatingLocation = false
    @State private var updateMessage: String? = nil
    @StateObject private var locationDelegate = LocationDelegate()
    @State private var locationManager = CLLocationManager()
    @State private var showLogoutAlert = false
    @State private var showEditProfile = false
    @State private var showCreatePostSheet = false
    @State private var selectedMediaItems: [PhotosPickerItem] = []
    @State private var selectedMediaData: [(data: Data, type: String)] = []
    @State private var isUploadingMedia = false
    @State private var uploadError: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                if let updateMessage = updateMessage {
                    Text(updateMessage)
                        .foregroundColor(updateMessage == "Location updated successfully!" ? .green : .red)
                        .font(.subheadline)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreatePostSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            updateLocation()
                        } label: {
                            if isUpdatingLocation {
                                Label("Updating...", systemImage: "location")
                            } else {
                                Label("Update Location", systemImage: "location")
                            }
                        }
                        Button {
                            showEditProfile = true
                        } label: {
                            Label("Edit Profile", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showLogoutAlert = true
                        } label: {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                    }
                }
            }
            .alert("Are you sure you want to log out?", isPresented: $showLogoutAlert) {
                Button("Log Out", role: .destructive) { logout() }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
        }
        .sheet(isPresented: $showCreatePostSheet) {
            CreateSelfPostSheet(onPost: {
                showCreatePostSheet = false
                // Optionally refresh user's posts here
            })
        }
    }
    
    func logout() {
        KeychainHelper.remove("email")
        KeychainHelper.remove("password")
        KeychainHelper.remove("accessToken")
        isLoggedIn = false
    }
    
    func updateLocation() {
        isUpdatingLocation = true
        updateMessage = nil
        locationManager.requestWhenInUseAuthorization()
        locationDelegate.onLocationUpdate = { location in
            if let location = location {
                Task {
                    let success = await Creatist.shared.updateUserLocation(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    await MainActor.run {
                        isUpdatingLocation = false
                        updateMessage = success ? "Location updated successfully!" : "Failed to update location."
                    }
                }
            } else {
                isUpdatingLocation = false
                updateMessage = "Could not get location."
            }
        }
        locationManager.delegate = locationDelegate
        locationManager.requestLocation()
    }
}

struct CreateSelfPostSheet: View {
    var onPost: () -> Void
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var tags: String = ""
    @State private var selectedMedia: [PhotosPickerItem] = []
    @State private var mediaData: [(data: Data, type: String)] = []
    @State private var isPosting = false
    @State private var postError: String? = nil
    @Environment(\.dismiss) var dismiss
    // Load media data when selection changes
    @MainActor
    func loadMediaData(from items: [PhotosPickerItem]) async {
        print("[DEBUG] Media selection changed. Items count: \(items.count)")
        var loaded: [(Data, String)] = []
        for (idx, item) in items.enumerated() {
            if let type = item.supportedContentTypes.first {
                let isVideo = type.conforms(to: .movie)
                let mediaType = isVideo ? "video" : "image"
                if let data = try? await item.loadTransferable(type: Data.self) {
                    print("[DEBUG] Loaded media item #\(idx+1): type=\(mediaType), size=\(data.count) bytes")
                    loaded.append((data, mediaType))
                } else {
                    print("[DEBUG] Failed to load media item #\(idx+1)")
                }
            }
        }
        mediaData = loaded
        print("[DEBUG] Total loaded media items: \(mediaData.count)")
    }
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Create Post").font(.largeTitle).bold()
                PhotosPicker(selection: $selectedMedia, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Select Media")
                    }
                    .padding(8)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .onChange(of: selectedMedia) { newItems in
                    print("[DEBUG] PhotosPicker selection changed. New items count: \(newItems.count)")
                    Task { await loadMediaData(from: newItems) }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(mediaData.enumerated()), id: \.offset) { element in
                            let idx = element.offset
                            let item = element.element
                            if item.type == "video" {
                                Image(systemName: "video.fill")
                                    .resizable().aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.accentColor)
                            } else if let uiImage = UIImage(data: item.data) {
                                Image(uiImage: uiImage)
                                    .resizable().aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                TextField("Title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Description", text: $description)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Tags (comma separated)", text: $tags)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                if let postError = postError {
                    Text(postError).foregroundColor(.red).font(.caption)
                }
                if isPosting {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            print("[DEBUG] Post button clicked. Starting post flow...")
                            isPosting = true
                            postError = nil
                            let newPostId = UUID()
                            guard let userId = Creatist.shared.user?.id else {
                                postError = "User not found"; isPosting = false; return
                            }
                            // 1. Load all media data
                            var loadedMedia: [(data: Data, type: String)] = []
                            for (idx, item) in selectedMedia.enumerated() {
                                if let type = item.supportedContentTypes.first {
                                    let isVideo = type.conforms(to: .movie)
                                    let mediaType = isVideo ? "video" : "image"
                                    if let data = try? await item.loadTransferable(type: Data.self) {
                                        print("[DEBUG] [Post] Loaded media #\(idx+1): type=\(mediaType), size=\(data.count) bytes")
                                        loadedMedia.append((data, mediaType))
                                    } else {
                                        print("[DEBUG] [Post] Failed to load media #\(idx+1)")
                                    }
                                }
                            }
                            mediaData = loadedMedia
                            print("[DEBUG] [Post] Total media to upload: \(mediaData.count)")
                            // 2. Upload all media to Supabase Storage
                            var mediaArray: [PostMediaCreate] = []
                            for (idx, item) in mediaData.enumerated() {
                                let ext = (item.type == "video") ? ".mov" : ".jpg"
                                let fileName = UUID().uuidString + ext
                                let uploadPath = "posts/\(userId.uuidString)/\(newPostId.uuidString)/\(fileName)"
                                let supabaseUrl = "https://wkmribpqhgdpklwovrov.supabase.co"
                                let uploadUrlString = "\(supabaseUrl)/storage/v1/object/\(uploadPath)"
                                var request = URLRequest(url: URL(string: uploadUrlString)!)
                                request.httpMethod = "PUT"
                                request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndrbXJpYnBxaGdkcGtsd292cm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE3MDY1OTksImV4cCI6MjA2NzI4MjU5OX0.N2wWfCSbjHMjHgA-stYesbcC8GZMATXug1rFew0qQOk", forHTTPHeaderField: "Authorization")
                                request.setValue(item.type == "video" ? "video/quicktime" : "image/jpeg", forHTTPHeaderField: "Content-Type")
                                print("[DEBUG] [Upload] Uploading media #\(idx+1): \(fileName), type=\(item.type), size=\(item.data.count) bytes")
                                print("[DEBUG] [Upload] Upload URL: \(uploadUrlString)")
                                print("[DEBUG] [Upload] Headers: \(request.allHTTPHeaderFields ?? [:])")
                                do {
                                    request.httpBody = item.data
                                    let (respData, resp) = try await URLSession.shared.data(for: request)
                                    if let httpResp = resp as? HTTPURLResponse {
                                        print("[DEBUG] [Upload] Status: \(httpResp.statusCode)")
                                        print("[DEBUG] [Upload] Response: \(String(data: respData, encoding: .utf8) ?? "nil")")
                                        if httpResp.statusCode == 200 || httpResp.statusCode == 201 {
                                            let finalUrl = "\(supabaseUrl)/storage/v1/object/public/posts/\(userId.uuidString)/\(newPostId.uuidString)/\(fileName)"
                                            print("[DEBUG] [Upload] Success. Public URL: \(finalUrl)")
                                            mediaArray.append(PostMediaCreate(url: finalUrl, type: item.type, order: idx))
                                        } else {
                                            postError = "Failed to upload media: \(fileName)"
                                            isPosting = false
                                            print("[DEBUG] [Upload] Failed to upload media: \(fileName)")
                                            return
                                        }
                                    }
                                } catch {
                                    postError = "Upload error: \(error.localizedDescription)"
                                    isPosting = false
                                    print("[DEBUG] [Upload] Exception: \(error.localizedDescription)")
                                    return
                                }
                            }
                            // 3. Build tags array
                            let tagsArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                            // 4. Call createPost
                            print("[DEBUG] [Post] About to call createPost. mediaArray count: \(mediaArray.count), title: \(title)")
                            let postId = await Creatist.shared.createPost(
                                caption: title.isEmpty ? nil : title,
                                media: mediaArray,
                                tags: tagsArray,
                                status: "public",
                                sharedFromPostId: nil,
                                visionboardId: nil
                            )
                            print("[DEBUG] [Post] createPost result: \(String(describing: postId))")
                            if let postId = postId {
                                isPosting = false
                                print("[DEBUG] [Post] Post created successfully. Post ID: \(postId)")
                                onPost()
                                dismiss()
                            } else {
                                postError = "Failed to create post."
                                isPosting = false
                                print("[DEBUG] [Post] Failed to create post.")
                            }
                        }
                    }.disabled(title.isEmpty || mediaData.isEmpty || isPosting)
                }
            }
        }
    }
}

class LocationDelegate: NSObject, CLLocationManagerDelegate, ObservableObject {
    var onLocationUpdate: (CLLocation?) -> Void = { _ in }
    override init() { super.init() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        onLocationUpdate(locations.last)
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
        onLocationUpdate(nil)
    }
} 