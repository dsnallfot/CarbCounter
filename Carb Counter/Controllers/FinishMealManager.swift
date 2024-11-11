import Foundation
import UserNotifications
import AudioToolbox

class FinishMealManager {
    static let shared = FinishMealManager()
    private let notificationIdentifier = "finishMealReminder"
    private var mealStartDate: Date?
    
    private init() {}
    
    func startFinishMealCountdown() {
        // Cancel any existing notification
        cancelScheduledNotification()
        
        // Retrieve meal start date from UserDefaults
        if let storedMealDate = UserDefaults.standard.object(forKey: "mealDate") as? Date {
            mealStartDate = storedMealDate
            print("Successfully retrieved meal start date from UserDefaults: \(storedMealDate)")
        } else {
            print("Warning: No meal date found in UserDefaults.")
            return
        }
        
        // Schedule notification immediately for 45 minutes from now
        scheduleNotification()
    }
    
    func stopFinishMealCountdown() {
        cancelScheduledNotification()
        mealStartDate = nil
        print("Finish Meal notification cancelled.")
    }
    
    private func scheduleNotification() {
        guard let startTime = mealStartDate else {
            print("Error: mealStartDate is nil, cannot schedule notification.")
            return
        }
        
        guard UserDefaultsRepository.finishMealNotificationsAllowed else {
            print("Finish Meal notifications are disabled in settings.")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Ej avslutad måltid", comment: "Title for finish meal reminder notification")
        
        let bodyFormat = NSLocalizedString(
            "Kom ihåg att slutföra måltidsregistreringen som påbörjades kl %@",
            comment: "Body format for finish meal reminder notification"
        )
        
        let formattedTime = DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .short)
        content.body = String(format: bodyFormat, formattedTime)
        content.sound = .default
        
        // Schedule for 45 minutes from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 45 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            } else {
                print("Finish Meal notification successfully scheduled for 45 minutes from now.")
            }
        }
    }
    
    private func cancelScheduledNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        print("Cancelled pending finish meal notification")
    }
}
