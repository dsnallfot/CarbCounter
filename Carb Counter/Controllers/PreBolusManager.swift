//
//  PreBolusManager.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-05.
//

import Foundation
import UserNotifications
import AudioToolbox

class PreBolusManager {
    static let shared = PreBolusManager()
    
    private var preBolusTimer: Timer?
    private var preBolusStartTime: Date?

    private init() {}
    
    func startPreBolusCountdown() {
        stopPreBolusCountdown() // Stop any existing timer
        
        // Fetch the bolus amount from UserDefaults
        let bolus = UserDefaults.standard.double(forKey: "registeredBolusSoFar")
        self.preBolusStartTime = Date()
        
        preBolusTimer = Timer.scheduledTimer(timeInterval: 20 * 60, target: self, selector: #selector(preBolusTimerCompleted), userInfo: bolus, repeats: false)
        print("Prebolus timer started")
    }
    
    func stopPreBolusCountdown() {
        preBolusTimer?.invalidate()
        preBolusTimer = nil
        preBolusStartTime = nil
        print("Prebolus timer stopped")
    }
    
    @objc private func preBolusTimerCompleted() {
        guard let startTime = preBolusStartTime else { return }
        
        // Check if pre-bolus notifications are allowed
        guard UserDefaultsRepository.preBolusNotificationsAllowed else {
            print("Pre-bolus notifications are disabled in settings.")
            stopPreBolusCountdown() // Stop the timer if notifications are not allowed
            return
        }

        // Fetch the bolus amount from UserDefaults to ensure it's the latest
        let bolus = UserDefaults.standard.double(forKey: "registeredBolusSoFar")
        
        // Schedule the notification
        let content = UNMutableNotificationContent()
        
        // Localize title and body
        content.title = NSLocalizedString("Kom ihåg att äta", comment: "Title for pre-bolus reminder notification")
        
        let bodyFormat = NSLocalizedString(
            "En prebolus på %.2f E gavs klockan %@",
            comment: "Body format for pre-bolus reminder notification"
        )
        content.body = String(
            format: bodyFormat,
            bolus,
            DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .short)
        )
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "preBolusReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
        
        stopPreBolusCountdown() // Clear timer after completion
    }
}
