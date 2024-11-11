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
    private let notificationIdentifier = "preBolusReminder"
    private var preBolusStartTime: Date?
    
    private init() {}
    
    func startPreBolusCountdown() {
        // Cancel any existing notification
        cancelScheduledNotification()
        
        // Get current bolus amount and start time
        let bolus = UserDefaults.standard.double(forKey: "registeredBolusSoFar")
        self.preBolusStartTime = Date()
        
        // Schedule notification immediately
        scheduleNotification(bolus: bolus)
        print("Prebolus notification scheduled")
    }
    
    func stopPreBolusCountdown() {
        cancelScheduledNotification()
        preBolusStartTime = nil
        print("Prebolus notification cancelled")
    }
    
    private func scheduleNotification(bolus: Double) {
        guard let startTime = preBolusStartTime else { return }
        
        guard UserDefaultsRepository.preBolusNotificationsAllowed else {
            print("Pre-bolus notifications are disabled in settings.")
            return
        }
        
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
        
        // Schedule for 20 minutes from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 20 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            } else {
                print("Pre-bolus notification successfully scheduled for 20 minutes from now.")
            }
        }
    }
    
    private func cancelScheduledNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        print("Cancelled pending pre-bolus notification")
    }
}
