// OK!
//  Profile.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-16.
//

import Foundation
extension ComposeMealViewController {
    // NS Profile Web Call
    func webLoadNSProfile() {
        NightscoutUtils.executeRequest(eventType: .profile, parameters: [:]) { (result: Result<NSProfile, Error>) in
            switch result {
            case .success(let profileData):
                self.updateProfile(profileData: profileData)
            case .failure(let error):
                print("Error fetching profile data: \(error.localizedDescription)")
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
