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
    
    private var finishMealTimer: Timer?
    private var finishMealStartTime: Date?

    private init() {}
    
    func startFinishMealCountdown() {
        stopFinishMealCountdown() // Stop any existing timer
        
        // Set finishMealStartTime to the stored mealDate from UserDefaults
        finishMealStartTime = UserDefaults.standard.object(forKey: "mealDate") as? Date
        
        finishMealTimer = Timer.scheduledTimer(timeInterval: 45 * 60, target: self, selector: #selector(finishMealTimerCompleted), userInfo: nil, repeats: false)
        print("Finish Meal timer started")
    }
    
    func stopFinishMealCountdown() {
        finishMealTimer?.invalidate()
        finishMealTimer = nil
        finishMealStartTime = nil
        print("Finish Meal timer stopped")
    }
    
    @objc private func finishMealTimerCompleted() {
        guard let startTime = finishMealStartTime else { return }
        
        // Check if finish meal notifications are allowed
        guard UserDefaultsRepository.finishMealNotificationsAllowed else {
            print("Finish Meal notifications are disabled in settings.")
            stopFinishMealCountdown() // Stop the timer if notifications are not allowed
            return
        }
        
        // Schedule the notification
        let content = UNMutableNotificationContent()
        
        // Localize title and body
        content.title = NSLocalizedString("Ej avslutad måltid", comment: "Title for finish meal reminder notification")
        
        let bodyFormat = NSLocalizedString(
            "Kom ihåg att slutföra måltidsregistreringen som påbörjades kl: %@",
            comment: "Body format for finish meal reminder notification"
        )
        
        let formattedTime = DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .short)
        content.body = String(format: bodyFormat, formattedTime)
        
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "finishMealReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
        
        stopFinishMealCountdown() // Clear timer after completion
    }
}
