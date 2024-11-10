import Foundation
import UserNotifications
import AudioToolbox

class FinishMealManager {
    static let shared = FinishMealManager()
    
    private var finishMealTimer: Timer?
    private var lastActionTime: Date?
    private var mealStartDate: Date? // This is the fixed meal start time from UserDefaults
    
    private init() {}
    
    func startFinishMealCountdown() {
        stopFinishMealCountdown() // Stop any existing timer
        
        // Retrieve meal start date from UserDefaults
        if let storedMealDate = UserDefaults.standard.object(forKey: "mealDate") as? Date {
            mealStartDate = storedMealDate
            print("Successfully retrieved meal start date from UserDefaults: \(storedMealDate)")
        } else {
            print("Warning: No meal date found in UserDefaults.")
        }
        
        // Update lastActionTime to the current time for the countdown
        lastActionTime = Date()
        print("Updated last action time: \(String(describing: lastActionTime))")
        
        // Start the 45-minute timer
        finishMealTimer = Timer.scheduledTimer(timeInterval: 45 * 60, target: self, selector: #selector(finishMealTimerCompleted), userInfo: mealStartDate, repeats: false)
        print("Finish Meal timer started")
    }
    
    func stopFinishMealCountdown() {
        finishMealTimer?.invalidate()
        finishMealTimer = nil
        lastActionTime = nil
        print("Finish Meal timer stopped and last action time reset.")
    }
    
    @objc private func finishMealTimerCompleted() {
        // Use mealStartDate for the notification time, and check if it's available
        guard let startTime = mealStartDate else {
            print("Error: mealStartDate is nil, cannot schedule notification.")
            return
        }
        
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
            "Kom ihåg att slutföra måltidsregistreringen som påbörjades kl %@",
            comment: "Body format for finish meal reminder notification"
        )
        
        // Format meal start time for the notification message
        let formattedTime = DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .short)
        print("Notification scheduled with meal start time: \(formattedTime)")
        content.body = String(format: bodyFormat, formattedTime)
        
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "finishMealReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            } else {
                print("Finish Meal notification successfully scheduled.")
            }
        }
        
        stopFinishMealCountdown() // Restart the countdown timer
    }
}
