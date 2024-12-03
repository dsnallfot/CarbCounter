// OK!
//  Profile.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-16.
//

import Foundation
import Network

extension ComposeMealViewController {
    // NS Profile Web Call
    @objc func webLoadNSProfile() {
        // Check for network connectivity
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        
        monitor.pathUpdateHandler = { path in
            monitor.cancel() // Stop monitoring once we have the result

            guard path.status == .satisfied else {
                print("No network connection available.")
                DispatchQueue.main.async {
                    // Optionally, update UI or show an alert
                    print("Unable to fetch profile data due to no network.")
                }
                return
            }

            // Proceed with the network request if network is available
            NightscoutUtils.executeRequest(eventType: .profile, parameters: [:]) { (result: Result<NSProfile, Error>) in
                switch result {
                case .success(let profileData):
                    DispatchQueue.main.async {
                        self.updateProfile(profileData: profileData)
                    }
                case .failure(let error):
                    print("Error fetching profile data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // NS Profile Response Processor
    func updateProfile(profileData: NSProfile) {
        //if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: profile") }
        
        guard let store = profileData.store["default"] ?? profileData.store["Default"] else {
            return
        }
        profileManager.loadProfile(from: profileData)
        
    }
}
