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
    @State private var showCreatePostSheet = false
    @State private var selectedMediaItems: [PhotosPickerItem] = []
    @State private var selectedMediaData: [(data: Data, type: String)] = []
    @State private var isUploadingMedia = false
    @State private var uploadError: String? = nil
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    var currentUser: User? { Creatist.shared.user }
    @State private var selectedSection = 0
    let sections = ["My Projects", "Top Works"]
    @State private var myPosts: [PostWithDetails] = []
    @State private var isLoadingMyPosts = false
    @State private var selectedPost: PostWithDetails? = nil
    @State private var showSettingsSheet = false
    @State private var userCache: [UUID: User] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                ScrollView {
                    VStack(spacing: 16) {
                        if let user = currentUser {
                            Spacer(minLength: 24)
                            profileImageView(user: user)
                            usernameView(user: user)
                                .padding(.top, 12)
                            if let username = user.username {
                                Text("@\(username)")
                                    .font(.subheadline)
                                    .foregroundColor(Color.secondary)
                            }
                            statsView(user: user)
                            bioView(user: user)
                            infoRowsView(user: user)
                            segmentedControlView
                            sectionContentView
                        } else {
                            Spacer()
                            SkeletonView(width: 20, height: 20, cornerRadius: 10)
                            Spacer()
                        }
                        if let updateMessage = updateMessage {
                            Text(updateMessage)
                                .foregroundColor(updateMessage == "Location updated successfully!" ? .green : .red)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle(currentUser?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreatePostSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                    }
                }
            }
            .alert("Are you sure you want to log out?", isPresented: $showLogoutAlert) {
                Button("Log Out", role: .destructive) { logout() }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showCreatePostSheet) {
                CreateSelfPostSheet(onPost: {
                    showCreatePostSheet = false
                    // Refresh posts to update count
                    if let user = currentUser {
                        Task { await loadMyPosts(for: user.id) }
                    }
                })
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsSheet(
                    isUpdatingLocation: $isUpdatingLocation,
                    onUpdateLocation: updateLocation,
                    onLogout: { showLogoutAlert = true }
                )
            }
        }
        .task {
            if let user = currentUser {
                followersCount = await Creatist.shared.fetchFollowersCount(for: user.id.uuidString)
                followingCount = await Creatist.shared.fetchFollowingCount(for: user.id.uuidString)
                // Always load posts to get accurate count
                await loadMyPosts(for: user.id)
            }
        }
        .onChange(of: selectedSection) { newValue in
            // Posts are already loaded, no need to reload
        }
    }
    
    func logout() {
        KeychainHelper.remove("email")
        KeychainHelper.remove("password")
        KeychainHelper.remove("accessToken")
        KeychainHelper.remove("refreshToken")
        KeychainHelper.remove("tokenExpirationTime")
        TokenMonitor.shared.stopMonitoring()
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

    func loadMyPosts(for userId: UUID) async {
        isLoadingMyPosts = true
        let posts = await Creatist.shared.fetchUserPosts(userId: userId)
        await MainActor.run {
            myPosts = posts
            isLoadingMyPosts = false
        }
    }

    func fetchUser(userId: UUID, completion: @escaping (User?) -> Void) {
        if let cached = userCache[userId] {
            completion(cached)
            return
        }
        Task {
            if let user = await Creatist.shared.fetchUserById(userId: userId) {
                await MainActor.run {
                    userCache[userId] = user
                    completion(user)
                }
            } else {
                completion(nil)
            }
        }
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
                    HStack { Spacer(); 
                        SkeletonView(width: 20, height: 20, cornerRadius: 10)
                        Spacer() 
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Create Post")
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

struct SettingsSheet: View {
    @Binding var isUpdatingLocation: Bool
    var onUpdateLocation: () -> Void
    var onLogout: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showEditProfile = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showAbout = false
    @State private var showHelp = false
    @State private var showContact = false
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Profile").foregroundColor(Color.secondary)) {
                    Button(action: onUpdateLocation) {
                        if isUpdatingLocation {
                            Label {
                                Text("Updating...").foregroundColor(Color.primary)
                            } icon: {
                                Image(systemName: "location")
                            }
                        } else {
                            Label {
                                Text("Update Location").foregroundColor(Color.primary)
                            } icon: {
                                Image(systemName: "location")
                            }
                        }
                    }
                    Button(action: { showEditProfile = true }) {
                        Label {
                            Text("Edit Profile").foregroundColor(Color.primary)
                        } icon: {
                            Image(systemName: "pencil")
                        }
                    }
                }
                Section(header: Text("Legal").foregroundColor(Color.secondary)) {
                    Button(action: { showPrivacyPolicy = true }) {
                        Label {
                            Text("Privacy Policy").foregroundColor(Color.primary)
                        } icon: {
                            Image(systemName: "lock.shield")
                        }
                    }
                    Button(action: { showTermsOfService = true }) {
                        Label {
                            Text("Terms of Service").foregroundColor(Color.primary)
                        } icon: {
                            Image(systemName: "doc.text")
                        }
                    }
                }
                Section(header: Text("Support").foregroundColor(Color.secondary)) {
                    Button(action: { showAbout = true }) {
                        Label {
                            Text("About").foregroundColor(Color.primary)
                        } icon: {
                            Image(systemName: "info.circle")
                        }
                    }
                    Button(action: { showHelp = true }) {
                        Label {
                            Text("Help & Support").foregroundColor(Color.primary)
                        } icon: {
                            Image(systemName: "questionmark.circle")
                        }
                    }
                    Button(action: { showContact = true }) {
                        Label {
                            Text("Contact Us").foregroundColor(Color.primary)
                        } icon: {
                            Image(systemName: "envelope")
                        }
                    }
                }
                Section(header: Text("Account").foregroundColor(Color.secondary)) {
                    Button(role: .destructive, action: onLogout) {
                        Label {
                            Text("Log Out").foregroundColor(Color.red)
                        } icon: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(
                    onSave: { showEditProfile = false },
                    onCancel: { showEditProfile = false }
                )
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicySheet(isPresented: $showPrivacyPolicy)
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceSheet(isPresented: $showTermsOfService)
            }
            .sheet(isPresented: $showAbout) {
                AboutSheet(isPresented: $showAbout)
            }
            .sheet(isPresented: $showHelp) {
                HelpSupportSheet(isPresented: $showHelp)
            }
            .sheet(isPresented: $showContact) {
                ContactUsSheet(isPresented: $showContact)
            }
        }
    }
}

// MARK: - View Components
extension ProfileView {
    
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.accentColor.opacity(0.85), Color.clear]),
            startPoint: .bottom,
            endPoint: .top
        )
        .ignoresSafeArea()
        .background(.ultraThinMaterial)
    }
    
    private func profileImageView(user: User) -> some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 110, height: 110)
            if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().aspectRatio(contentMode: .fill)
                            .foregroundColor(Color(.tertiaryLabel))
                    } else {
                        SkeletonView(width: 100, height: 100, cornerRadius: 50)
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(.top, 16)
    }
    
    private func usernameView(user: User) -> some View {
        VStack(spacing: 4) {
            Text(user.name)
                .font(.title).bold()
                .foregroundColor(Color.primary)
            if let username = user.username {
                Text("@\(username)")
                    .font(.subheadline)
                    .foregroundColor(Color.secondary)
            }
        }
    }
    
    private func statsView(user: User) -> some View {
        HStack(spacing: 24) {
            StatView(number: Double(followersCount), label: "Followers")
            StatView(number: Double(followingCount), label: "Following")
            StatView(number: Double(myPosts.count), label: "Projects")
            StatView(number: user.rating ?? 0, label: "Rating", isDouble: true)
        }
        .padding(.top, 8)
    }
    
    private func bioView(user: User) -> some View {
        Group {
            if let desc = user.description, !desc.isEmpty {
                Text(desc)
                    .font(.body)
                    .foregroundColor(Color.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 8)
            } else {
                Text(user.email)
                    .font(.body)
                    .foregroundColor(Color.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
        }
    }
    
    private func infoRowsView(user: User) -> some View {
        VStack(spacing: 8) {
            if let city = user.city, let country = user.country {
                InfoRow(icon: "location", text: "\(city), \(country)")
            }
            if let workMode = user.workMode {
                InfoRow(icon: "globe", text: workMode.rawValue)
            }
            if let paymentMode = user.paymentMode {
                InfoRow(icon: paymentMode == .paid ? "creditcard.fill" : "gift.fill", text: paymentMode.rawValue.capitalized)
            }
            if let genres = user.genres, !genres.isEmpty {
                InfoRow(icon: "music.note.list", text: genres.map { $0.rawValue }.joined(separator: ", "))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var segmentedControlView: some View {
        Picker("Section", selection: $selectedSection) {
            ForEach(0..<sections.count, id: \.self) { idx in
                Text(sections[idx])
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }
    
    private var sectionContentView: some View {
        Group {
            if selectedSection == 0 {
                myProjectsView
            } else {
                topWorksView
            }
        }
    }
    
    private var myProjectsView: some View {
        Group {
            if isLoadingMyPosts {
                UserProfileProjectsSkeleton()
            } else if myPosts.isEmpty {
                Text("No projects found.")
                    .foregroundColor(Color.secondary)
                    .padding()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(myPosts, id: \.id) { post in
                        Button(action: { selectedPost = post }) {
                            ZStack {
                                if let urlString = post.media.first?.url, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } else if phase.error != nil {
                                            Color(.systemGray4)
                                        } else {
                                            SkeletonView(cornerRadius: 12)
                                        }
                                    }
                                    .frame(height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    Color(.systemGray4).frame(height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let post = selectedPost {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                PostCellView(post: post)
                                    .padding(.bottom, 16)
                                let orderedPosts = [post] + myPosts.filter { $0.id != post.id }
                                ForEach(orderedPosts, id: \.id) { detailPost in
                                    if detailPost.id != post.id {
                                        PostCellView(post: detailPost)
                                            .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                },
                isActive: Binding(
                    get: { selectedPost != nil },
                    set: { if !$0 { selectedPost = nil } }
                )
            ) { EmptyView() }.hidden()
        )
    }
    
    private var topWorksView: some View {
        VStack {
            Text("Top Works")
                .foregroundColor(Color.secondary)
                .padding()
            // TODO: List top works here
        }
    }
} 