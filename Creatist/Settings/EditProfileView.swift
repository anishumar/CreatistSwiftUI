import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var phoneNumber: String = ""
    @State private var originalPhoneNumber: String = ""  // Store original phone number
    @State private var selectedCountryCode: CountryCode = CountryCode.getDefault()
    @State private var showCountryCodePicker: Bool = false
    @State private var showPhoneOTPView: Bool = false
    @State private var pendingPhoneNumber: String = ""  // Phone number waiting for verification
    @State private var dob: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var selectedGenres: Set<UserGenre> = []
    @State private var paymentMode: PaymentMode = .free
    @State private var workMode: WorkMode = .online
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var showGenreSheet = false
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var imagePickerItem: PhotosPickerItem? = nil

    var user: User? { Creatist.shared.user }
    var onSave: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    // MARK: - Supabase Storage Config
    private let supabaseUrl = EnvironmentConfig.shared.supabaseURL
    private let supabaseAnonKey = EnvironmentConfig.shared.supabaseAnonKey
    private let supabaseBucket = "profile-images" // <-- Updated bucket name

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ZStack(alignment: .bottomTrailing) {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else if let urlString = user?.profileImageUrl, let url = URL(string: urlString) {
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
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable().aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.gray)
                            }
                            Button(action: { showImagePicker = true }) {
                                Image(systemName: "camera.fill")
                                    .padding(6)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            .offset(x: 8, y: 8)
                        }
                        Spacer()
                    }
                }
                Section(header: Text("Basic Information")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    HStack(spacing: 8) {
                        // Country Code Picker Button
                        Button(action: {
                            showCountryCodePicker = true
                        }) {
                            HStack(spacing: 4) {
                                Text(selectedCountryCode.flag)
                                Text(selectedCountryCode.code)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        
                        // Phone Number Input
                        TextField("Phone Number (optional)", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    
                    // Show verify button if phone number has changed
                    if !phoneNumber.isEmpty && getFormattedPhoneNumber() != originalPhoneNumber {
                        Button(action: {
                            verifyPhoneNumber()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Verify Phone Number")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isSaving)
                    }
                    DatePicker("Date of Birth", selection: $dob, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                Section(header: Text("Genres")) {
                    Button {
                        showGenreSheet = true
                    } label: {
                        HStack {
                            Text("Genres")
                            Spacer()
                            Text(selectedGenres.isEmpty ? "None" : selectedGenres.map { $0.rawValue.capitalized }.joined(separator: ", "))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .sheet(isPresented: $showGenreSheet) {
                    GenreMultiSelectSheet(selectedGenres: $selectedGenres)
                }
                Section(header: Text("Payment Mode")) {
                    Picker("Payment Mode", selection: $paymentMode) {
                        ForEach(PaymentMode.allCases, id: \ .self) { mode in
                            Text(mode.rawValue.capitalized).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("Work Mode")) {
                    Picker("Work Mode", selection: $workMode) {
                        ForEach(WorkMode.allCases, id: \ .self) { mode in
                            Text(mode.rawValue.capitalized).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel?() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { saveProfile() }
                    }
                }
            }
            .onAppear {
                Task {
                    await Creatist.shared.fetch()
                    loadUser()
                }
            }
            .sheet(isPresented: $showCountryCodePicker) {
                CountryCodePickerView(selectedCountryCode: $selectedCountryCode)
            }
            .sheet(isPresented: $showPhoneOTPView) {
                PhoneVerificationView(
                    phoneNumber: pendingPhoneNumber,
                    onVerified: {
                        // Phone verified, update the original phone number
                        originalPhoneNumber = pendingPhoneNumber
                        showPhoneOTPView = false
                        // Refresh user data
                        Task {
                            await Creatist.shared.fetch()
                            loadUser()
                        }
                    },
                    onCancel: {
                        showPhoneOTPView = false
                        // Revert phone number if verification cancelled
                        phoneNumber = String(originalPhoneNumber.dropFirst(selectedCountryCode.code.count))
                    }
                )
            }
            .photosPicker(isPresented: $showImagePicker, selection: $imagePickerItem, matching: .images)
            .onChange(of: imagePickerItem) { newItem in
                if let newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                        }
                    }
                }
            }
        }
    }

    func getFormattedPhoneNumber() -> String {
        let cleaned = phoneNumber.trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty {
            return ""
        }
        var formattedPhone = cleaned
        if formattedPhone.hasPrefix("+") {
            let withoutPlus = String(formattedPhone.dropFirst())
            if !withoutPlus.allSatisfy({ $0.isNumber }) {
                formattedPhone = selectedCountryCode.code + withoutPlus
            }
        } else {
            formattedPhone = selectedCountryCode.code + formattedPhone
        }
        return formattedPhone
    }
    
    func verifyPhoneNumber() {
        let formattedPhone = getFormattedPhoneNumber()
        guard !formattedPhone.isEmpty else {
            errorMessage = "Please enter a phone number"
            return
        }
        
        // Check if phone number is different from original
        if formattedPhone == originalPhoneNumber {
            errorMessage = "Phone number hasn't changed"
            return
        }
        
        pendingPhoneNumber = formattedPhone
        isSaving = true
        errorMessage = nil
        
        Task {
            let (success, errorMsg) = await Creatist.shared.requestPhoneVerifyOTP(phoneNumber: formattedPhone)
            await MainActor.run {
                isSaving = false
                if success {
                    showPhoneOTPView = true
                } else {
                    errorMessage = errorMsg ?? "Failed to send OTP. Please try again."
                }
            }
        }
    }
    
    func loadUser() {
        guard let user = Creatist.shared.user else { return }
        name = user.name
        description = user.description ?? ""
        
        // Parse phone number and country code
        if let phone = user.phoneNumber, !phone.isEmpty {
            originalPhoneNumber = phone  // Store original for comparison
            // Extract country code if present
            if let countryCode = CountryCode.countries.first(where: { phone.hasPrefix($0.code) }) {
                selectedCountryCode = countryCode
                // Remove country code from phone number for display
                phoneNumber = String(phone.dropFirst(countryCode.code.count))
            } else {
                // No recognized country code, try to detect or use default
                if phone.hasPrefix("+") {
                    // Has country code but not recognized, extract first few digits
                    let withoutPlus = String(phone.dropFirst())
                    if let firstDigit = withoutPlus.first, firstDigit.isNumber {
                        // Try common codes
                        for codeLength in [3, 2, 1] {
                            if withoutPlus.count >= codeLength {
                                let possibleCode = "+" + String(withoutPlus.prefix(codeLength))
                                if let country = CountryCode.findByCode(possibleCode) {
                                    selectedCountryCode = country
                                    phoneNumber = String(withoutPlus.dropFirst(codeLength))
                                    break
                                }
                            }
                        }
                    }
                } else {
                    phoneNumber = phone
                    originalPhoneNumber = phone
                }
            }
        } else {
            phoneNumber = ""
            originalPhoneNumber = ""
        }
        
        // Load dob from user data if available, otherwise calculate from age
        if let dobString = user.dob, let dobDate = ISO8601DateFormatter().date(from: dobString + "T00:00:00Z") {
            dob = dobDate
        } else if let userAge = user.age, userAge > 0 {
            dob = Calendar.current.date(byAdding: .year, value: -userAge, to: Date()) ?? Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
        } else {
            dob = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
        }
        
        selectedGenres = Set(user.genres ?? [])
        paymentMode = user.paymentMode ?? .free
        workMode = user.workMode ?? .online
        selectedImage = nil
    }

    func saveProfile() {
        guard !name.isEmpty else { errorMessage = "Name is required"; return }
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dob, to: now)
        guard let ageInt = ageComponents.year, ageInt > 0 else { errorMessage = "Enter a valid date of birth"; return }
        
        // Validate phone number format if provided
        if !phoneNumber.isEmpty {
            let cleaned = phoneNumber.trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty {
                // Basic validation: should have at least 10 digits
                let digitsOnly = cleaned.filter { $0.isNumber }
                if digitsOnly.count < 10 {
                    errorMessage = "Please enter a valid phone number with country code (e.g., +1234567890)"
                    return
                }
            }
        }
        
        isSaving = true
        errorMessage = nil
        Task {
            // Check if phone number has changed and needs verification
            let formattedPhone = getFormattedPhoneNumber()
            if !phoneNumber.isEmpty && formattedPhone != originalPhoneNumber {
                // Phone number changed but not verified - show error
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Please verify the phone number before saving. Tap 'Verify Phone Number' button."
                }
                return
            }
            
            var updatedUser = user!
            updatedUser.name = name
            updatedUser.description = description
            
            // Only update phone number if it's verified (matches original) or empty
            if !phoneNumber.isEmpty {
                // Use the verified phone number (originalPhoneNumber is updated after verification)
                updatedUser.phoneNumber = originalPhoneNumber
            } else {
                // If phone number field is empty, clear it
                updatedUser.phoneNumber = nil
            }
            
            updatedUser.age = ageInt
            updatedUser.dob = ISO8601DateFormatter().string(from: dob).components(separatedBy: "T")[0] // Format as YYYY-MM-DD
            updatedUser.genres = Array(selectedGenres)
            updatedUser.paymentMode = paymentMode
            updatedUser.workMode = workMode
            var imageUploadAttempts = 0
            var imageUploadSuccess = false
            var uploadedUrl: String? = nil
            if let image = selectedImage {
                while imageUploadAttempts < 2 && !imageUploadSuccess {
                    print("[DEBUG] Attempting to upload profile image (attempt \(imageUploadAttempts+1))")
                    if let url = await uploadProfileImage(image) {
                        uploadedUrl = url
                        imageUploadSuccess = true
                        print("[DEBUG] Image upload succeeded: \(url)")
                    } else {
                        print("[DEBUG] Image upload failed on attempt \(imageUploadAttempts+1)")
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    }
                    imageUploadAttempts += 1
                }
                if let url = uploadedUrl {
                    updatedUser.profileImageUrl = url
                } else {
                    await MainActor.run {
                        isSaving = false
                        errorMessage = "Failed to upload profile image after 2 attempts."
                    }
                    return
                }
            }
            print("[DEBUG] Saving user with profileImageUrl:", updatedUser.profileImageUrl ?? "nil")
            var profileUpdateAttempts = 0
            var profileUpdateSuccess = false
            var lastErrorMessage: String? = nil
            while profileUpdateAttempts < 2 && !profileUpdateSuccess {
                print("[DEBUG] Attempting to update user profile (attempt \(profileUpdateAttempts+1))")
                let (success, errorMessage) = await Creatist.shared.updateUserProfile(updatedUser)
                if success {
                    profileUpdateSuccess = true
                    print("[DEBUG] User profile update succeeded.")
                } else {
                    lastErrorMessage = errorMessage
                    print("[DEBUG] User profile update failed on attempt \(profileUpdateAttempts+1): \(errorMessage ?? "unknown error")")
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
                profileUpdateAttempts += 1
            }
            await MainActor.run {
                isSaving = false
                if profileUpdateSuccess {
                    onSave?()
                } else {
                    errorMessage = lastErrorMessage ?? "Failed to update profile. Please try again."
                }
            }
        }
    }

    func uploadProfileImage(_ image: UIImage) async -> String? {
        // Debug: Print Info.plist value for SUPABASE_URL
        print("Info.plist SUPABASE_URL:", Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? "nil")
        // Debug: Print Supabase config values
        print("Supabase URL: \(supabaseUrl)")
        print("Supabase Key: \(supabaseAnonKey.prefix(8))... (hidden)")
        print("Supabase Bucket: \(supabaseBucket)")

        // Debug: Print original image size
        print("[DEBUG] Original image size: \(image.size), scale: \(image.scale)")
        // 1. Resize image to max 1024px
        let resizedImage = image.resized(toMax: 1024) ?? image
        print("[DEBUG] Resized image size: \(resizedImage.size), scale: \(resizedImage.scale)")
        // 2. Convert UIImage to JPEG data with more compression
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.4) else {
            await MainActor.run { self.errorMessage = "Failed to convert image to JPEG." }
            print("[DEBUG] Failed to convert image to JPEG.")
            return nil
        }
        print("[DEBUG] JPEG data size: \(imageData.count) bytes")
        // 3. Generate a unique file name
        let fileName = UUID().uuidString + ".jpg"
        let uploadPath = "\(supabaseBucket)/\(fileName)"
        let uploadUrlString = "\(supabaseUrl)/storage/v1/object/\(uploadPath)"
        print("[DEBUG] Upload URL: \(uploadUrlString)")
        guard let uploadUrl = URL(string: uploadUrlString) else {
            await MainActor.run { self.errorMessage = "Invalid Supabase upload URL." }
            print("[DEBUG] Invalid Supabase upload URL: \(uploadUrlString)")
            return nil
        }
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("[DEBUG] Supabase upload HTTP status: \(httpResponse.statusCode)")
            }
            let responseBody = String(data: data, encoding: .utf8) ?? "<no response body>"
            print("[DEBUG] Supabase upload response body: \(responseBody)")
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                await MainActor.run { self.errorMessage = "Supabase upload failed: \(responseBody)" }
                print("[DEBUG] Supabase upload failed: \(responseBody)")
                return nil
            }
            // 4. Construct the public URL (if bucket is public)
            let publicUrl = "\(supabaseUrl)/storage/v1/object/public/\(supabaseBucket)/\(fileName)"
            print("[DEBUG] Supabase upload succeeded. Public URL: \(publicUrl)")
            return publicUrl
        } catch {
            await MainActor.run { self.errorMessage = "Supabase upload error: \(error.localizedDescription)" }
            print("[DEBUG] Supabase upload error: \(error.localizedDescription)")
            return nil
        }
    }
}

struct GenreMultiSelectSheet: View {
    @Binding var selectedGenres: Set<UserGenre>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(UserGenre.allCases, id: \.self) { genre in
                    Button {
                        if selectedGenres.contains(genre) {
                            selectedGenres.remove(genre)
                        } else if selectedGenres.count < 2 {
                            selectedGenres.insert(genre)
                        }
                    } label: {
                        HStack {
                            Text(genre.rawValue.capitalized)
                            Spacer()
                            if selectedGenres.contains(genre) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(!selectedGenres.contains(genre) && selectedGenres.count >= 2)
                }
            }
            .navigationTitle("Select Genres")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - UIImage Resize Extension
extension UIImage {
    func resized(toMax dimension: CGFloat) -> UIImage? {
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        if aspectRatio > 1 {
            newSize = CGSize(width: dimension, height: dimension / aspectRatio)
        } else {
            newSize = CGSize(width: dimension * aspectRatio, height: dimension)
        }
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
} 