import AppIntents
import UIKit
import BackgroundTasks

let updateAmountBackgroundTaskIdentifier = "com.dsnallfot.CarbsCounter.updateRegisteredAmount"

final class UpdateRegisteredAmountIntent: AppIntent {
    static var title: LocalizedStringResource = "Uppdatera registrerad mängd"
    static var description = IntentDescription("Uppdatera registrerad mängd kh, fett, protein och bolus.")
    
    @Parameter(title: "Kolhydrater (g)")
    var khValue: Double
    
    @Parameter(title: "Fett (g)")
    var fatValue: Double
    
    @Parameter(title: "Protein (g)")
    var proteinValue: Double
    
    @Parameter(title: "Bolus (E)")
    var bolusValue: Double
    
    @Parameter(title: "Startdos", default: false)
    var startDose: Bool
    
    private var backgroundTaskCompletion: (() -> Void)?
    
    func perform() async throws -> some IntentResult {
        let khValueString = String(format: "%.1f", khValue)
        let fatValueString = String(format: "%.1f", fatValue)
        let proteinValueString = String(format: "%.1f", proteinValue)
        let bolusValueString = String(format: "%.2f", bolusValue)
        
        try await performUpdate(
            khValue: khValueString,
            fatValue: fatValueString,
            proteinValue: proteinValueString,
            bolusValue: bolusValueString,
            startDose: self.startDose
        )
        
        // Check notification settings
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus != .authorized && settings.authorizationStatus != .provisional {
            print("Data updated, but notifications are not enabled. Please open the app to enable notifications.")
        }

        // Return a generic result
        return .result()
    }



    
    private func performUpdate(
        khValue: String,
        fatValue: String,
        proteinValue: String,
        bolusValue: String,
        startDose: Bool
    ) async throws {
        let defaults = UserDefaults.standard
        
        // Set mealDate if it’s not already set
        if defaults.object(forKey: "mealDate") == nil {
            defaults.set(Date(), forKey: "mealDate")
        }
        
        // Accumulate values for carbs, fat, protein, and bolus in UserDefaults
        let currentCarbs = defaults.double(forKey: "registeredCarbsSoFar")
        let currentFat = defaults.double(forKey: "registeredFatSoFar")
        let currentProtein = defaults.double(forKey: "registeredProteinSoFar")
        let currentBolus = defaults.double(forKey: "registeredBolusSoFar")
        
        let newCarbs = (Double(khValue) ?? 0.0) + currentCarbs
        let newFat = (Double(fatValue) ?? 0.0) + currentFat
        let newProtein = (Double(proteinValue) ?? 0.0) + currentProtein
        let newBolus = (Double(bolusValue) ?? 0.0) + currentBolus
        
        defaults.set(newCarbs, forKey: "registeredCarbsSoFar")
        defaults.set(newFat, forKey: "registeredFatSoFar")
        defaults.set(newProtein, forKey: "registeredProteinSoFar")
        defaults.set(newBolus, forKey: "registeredBolusSoFar")
        defaults.set(startDose, forKey: "startDoseGiven")
        
        // Schedule notification to inform the user
        scheduleNotification(
            khValue: String(format: "%.1f", newCarbs),
            fatValue: String(format: "%.1f", newFat),
            proteinValue: String(format: "%.1f", newProtein),
            bolusValue: String(format: "%.2f", newBolus)
        )
    }


    private func scheduleNotification(khValue: String, fatValue: String, proteinValue: String, bolusValue: String) {
        // Check if registration notifications are allowed
        guard UserDefaultsRepository.registrationNotificationsAllowed else {
            print("Registration notifications are disabled in settings.")
            return
        }
        
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                let content = UNMutableNotificationContent()
                
                // Localize title and body
                content.title = NSLocalizedString("Måltid uppdaterad", comment: "Title for meal update notification")
                
                let bodyFormat = NSLocalizedString(
                    "KH: %@g, Fett: %@g, Protein: %@g, Bolus: %@E",
                    comment: "Body format for meal update notification"
                )
                content.body = String(format: bodyFormat, khValue, fatValue, proteinValue, bolusValue)
                content.sound = .default
                
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                
                center.add(request) { error in
                    if let error = error {
                        print("Error scheduling notification: \(error)")
                    }
                }
            case .denied:
                print("Notifications are denied")
            case .notDetermined:
                print("Notifications are not determined")
            @unknown default:
                print("Unknown notification authorization status")
            }
        }
    }

}
