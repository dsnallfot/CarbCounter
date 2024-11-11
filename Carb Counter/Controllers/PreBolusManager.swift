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
    private let baseIdentifier = "preBolusReminder"
    private var preBolusStartTime: Date?
    
    // Define intervals in minutes for notifications
    private let intervals = [20, 40, 60]
    
    private init() {}
    
    func startPreBolusCountdown() {
        // Cancel any existing notifications
        cancelScheduledNotification()
        
        // Get current bolus amount and start time
        let bolus = UserDefaults.standard.double(forKey: "registeredBolusSoFar")
        self.preBolusStartTime = Date()
        
        // Schedule all notifications
        scheduleNotifications(bolus: bolus)
        print("Prebolus notifications scheduled")
    }
    
    func stopPreBolusCountdown() {
        cancelScheduledNotification()
        preBolusStartTime = nil
        print("Prebolus notifications cancelled")
    }
    
    private func scheduleNotifications(bolus: Double) {
        guard let startTime = preBolusStartTime else { return }
        
        guard UserDefaultsRepository.preBolusNotificationsAllowed else {
            print("Pre-bolus notifications are disabled in settings.")
            return
        }
        
        for (index, interval) in intervals.enumerated() {
            let content = UNMutableNotificationContent()
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
            
            // Schedule for the specified interval
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(interval * 60), repeats: false)
            let identifier = "\(baseIdentifier)_\(index)" 
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule notification for \(interval) minutes: \(error)")
                } else {
                    print("Pre-bolus notification successfully scheduled for \(interval) minutes from now.")
                }
            }
        }
    }
    
    private func cancelScheduledNotification() {
        let identifiers = intervals.indices.map { "\(baseIdentifier)_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Cancelled all pending pre-bolus notifications")
    }
}
