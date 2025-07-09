import SwiftUI
import CoreLocation

struct ProfileView: View {
    @Binding var isLoggedIn: Bool
    @State private var isUpdatingLocation = false
    @State private var updateMessage: String? = nil
    @StateObject private var locationDelegate = LocationDelegate()
    @State private var locationManager = CLLocationManager()
    @State private var showLogoutAlert = false
    @State private var showEditProfile = false
    
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