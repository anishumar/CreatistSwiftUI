import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var locationUpdateHandler: ((CLLocation?) -> Void)?
    private var isUpdatingLocation = false
    private var currentContinuation: CheckedContinuation<Void, Never>?
    
    private let lastLocationUpdateKey = "lastLocationUpdateTime"
    private let locationUpdateInterval: TimeInterval = 24 * 60 * 60 // 24 hours in seconds
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // Check if location should be updated (24 hours passed or never updated)
    func shouldUpdateLocation() -> Bool {
        if let lastUpdateTimeString = UserDefaults.standard.string(forKey: lastLocationUpdateKey),
           let lastUpdateTime = TimeInterval(lastUpdateTimeString) {
            let timeSinceLastUpdate = Date().timeIntervalSince1970 - lastUpdateTime
            return timeSinceLastUpdate >= locationUpdateInterval
        }
        // Never updated, should update
        return true
    }
    
    // Update location if needed (checks 24 hour interval)
    func updateLocationIfNeeded() async {
        if shouldUpdateLocation() {
            await updateLocation()
        }
    }
    
    // Force update location (used on login)
    func updateLocation() async {
        // Request authorization if not determined
        let status = locationManager.authorizationStatus
        
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // Wait for authorization response (up to 2 seconds)
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                let newStatus = locationManager.authorizationStatus
                if newStatus != .notDetermined {
                    break
                }
            }
        }
        
        let finalStatus = locationManager.authorizationStatus
        guard finalStatus == .authorizedWhenInUse || 
              finalStatus == .authorizedAlways else {
            // Authorization denied or restricted - can't update location
            return
        }
        
        return await withCheckedContinuation { continuation in
            // Store continuation to prevent multiple resumes
            guard self.currentContinuation == nil else {
                continuation.resume()
                return
            }
            self.currentContinuation = continuation
            
            locationUpdateHandler = { [weak self] location in
                guard let self = self, let cont = self.currentContinuation else { return }
                
                // Clear handler and continuation immediately to prevent multiple calls
                self.locationUpdateHandler = nil
                self.currentContinuation = nil
                
                if let location = location {
                    Task {
                        let success = await Creatist.shared.updateUserLocation(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude
                        )
                        if success {
                            // Store update time
                            let updateTime = Date().timeIntervalSince1970
                            UserDefaults.standard.set(
                                String(updateTime),
                                forKey: self.lastLocationUpdateKey
                            )
                        }
                        cont.resume()
                    }
                } else {
                    cont.resume()
                }
            }
            
            locationManager.requestLocation()
            
            // Add timeout to ensure continuation always resumes even if location fails
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
                if let cont = self.currentContinuation {
                    self.currentContinuation = nil
                    self.locationUpdateHandler = nil
                    cont.resume()
                }
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationUpdateHandler?(locations.last)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationUpdateHandler?(nil)
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Handle authorization changes if needed
    }
}

