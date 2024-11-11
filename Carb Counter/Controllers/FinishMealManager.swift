//
//  FinishMealManager.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-09.
//

import Foundation
import UserNotifications
import AudioToolbox

class FinishMealManager {
    static let shared = FinishMealManager()
    private let baseIdentifier = "finishMealReminder"
    private var mealStartDate: Date?
    
    // Define intervals in minutes for notifications
    private let intervals = [45, 90, 135, 180, 225]
    
    private init() {}
    
    func startFinishMealCountdown() {
        // Cancel any existing notifications
        cancelScheduledNotification()
        
        // Retrieve meal start date from UserDefaults
        if let storedMealDate = UserDefaults.standard.object(forKey: "mealDate") as? Date {
            mealStartDate = storedMealDate
            print("Successfully retrieved meal start date from UserDefaults: \(storedMealDate)")
        } else {
            print("Warning: No meal date found in UserDefaults.")
            return
        }
        
        // Schedule all notifications
        scheduleNotifications()
    }
    
    func stopFinishMealCountdown() {
        cancelScheduledNotification()
        mealStartDate = nil
        print("Finish Meal notifications cancelled.")
    }
    
    private func scheduleNotifications() {
        guard let startTime = mealStartDate else {
            print("Error: mealStartDate is nil, cannot schedule notifications.")
            return
        }
        
        guard UserDefaultsRepository.finishMealNotificationsAllowed else {
            print("Finish Meal notifications are disabled in settings.")
            return
        }
        
        for (index, interval) in intervals.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Ej avslutad måltid", comment: "Title for finish meal reminder notification")
            
            let bodyFormat = NSLocalizedString(
                "Kom ihåg att slutföra måltidsregistreringen som påbörjades kl %@",
                comment: "Body format for finish meal reminder notification"
            )
            
            let formattedTime = DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .short)
            content.body = String(format: bodyFormat, formattedTime)
            content.sound = .default
            
            // Schedule for the specified interval
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(interval * 60), repeats: false)
            let identifier = "\(baseIdentifier)_\(index)"  // Fixed: Using index instead of $0
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule notification for \(interval) minutes: \(error)")
                } else {
                    print("Finish Meal notification successfully scheduled for \(interval) minutes from now.")
                }
            }
        }
    }
    
    private func cancelScheduledNotification() {
        let identifiers = intervals.indices.map { "\(baseIdentifier)_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Cancelled all pending finish meal notifications")
    }
}
