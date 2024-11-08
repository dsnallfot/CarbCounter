import AppIntents
import UIKit
import CoreData
import BackgroundTasks

// Register background task identifier
let backgroundTaskIdentifier = "com.dsnallfot.CarbsCounter.processMealHistory"

struct CreateMealHistoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Logga måltidshistorik"
    static var description = IntentDescription("Skapa ett nytt inlägg i måltidshistoriken.")

    @Parameter(title: "Välj livsmedel", optionsProvider: FoodItemOptionsProvider())
    var foodItem: FoodItemEntity

    @Parameter(title: "Mängd")
    var portionServed: Double

    @Parameter(title: "Bolus")
    var bolus: Double

    @Parameter(title: "Datum")
    var mealDate: Date

    func perform() async throws -> some IntentResult {
        // Ensure dataSharingVC is instantiated
        guard let appDelegate = await UIApplication.shared.delegate as? AppDelegate,
              let dataSharingVC = await appDelegate.dataSharingVC else {
            print("DataSharingVC could not be instantiated.")
            return .result()
        }
        
        // Trigger data import for Meal History only before saving the new MealHistory entry
        print("Starting data import for Meal History")
        await dataSharingVC.importCSVFiles(specificFileName: "MealHistory.csv")
        print("Data import complete for Meal History")

        // Perform the save operation
        try await saveMealHistory(
            foodItem: foodItem.foodItem,
            portionServed: portionServed,
            bolus: bolus,
            mealDate: mealDate
        )
        
        // Schedule notification
        scheduleNotification(
            foodItemName: foodItem.name,
            portionServed: portionServed,
            bolus: bolus,
            mealDate: mealDate
        )

        return .result()
    }


    private func saveMealHistory(foodItem: FoodItem, portionServed: Double, bolus: Double, mealDate: Date) async throws {
        let context = CoreDataStack.shared.context
        
        // Create a child context for background operations
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        try await backgroundContext.perform {
            let mealHistory = MealHistory(context: backgroundContext)
            
            // Set unique ID, date, and lastEdited
            mealHistory.id = UUID()
            mealHistory.mealDate = mealDate
            mealHistory.lastEdited = Date()
            mealHistory.delete = false
            
            // Calculate total nutrients
            mealHistory.totalNetCarbs = foodItem.perPiece
                ? foodItem.carbsPP * portionServed
                : foodItem.carbohydrates * portionServed / 100
            
            mealHistory.totalNetFat = foodItem.perPiece
                ? foodItem.fatPP * portionServed
                : foodItem.fat * portionServed / 100
            
            mealHistory.totalNetProtein = foodItem.perPiece
                ? foodItem.proteinPP * portionServed
                : foodItem.protein * portionServed / 100
            
            mealHistory.totalNetBolus = bolus
            
            let foodEntry = FoodItemEntry(context: backgroundContext)
            foodEntry.entryId = foodItem.id
            foodEntry.entryName = foodItem.name
            foodEntry.entryCarbohydrates = foodItem.carbohydrates
            foodEntry.entryFat = foodItem.fat
            foodEntry.entryProtein = foodItem.protein
            foodEntry.entryEmoji = foodItem.emoji
            foodEntry.entryPortionServed = portionServed
            foodEntry.entryCarbsPP = foodItem.carbsPP
            foodEntry.entryFatPP = foodItem.fatPP
            foodEntry.entryProteinPP = foodItem.proteinPP
            foodEntry.entryPerPiece = foodItem.perPiece
            
            mealHistory.addToFoodEntries(foodEntry)
            
            // Save the background context
            try backgroundContext.save()
            
            // Save the main context
            try context.save()
            
            print("MealHistory saved successfully through shortcut!")
            
            // Trigger the export after saving
            Task { @MainActor in
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                   let dataSharingVC = appDelegate.dataSharingVC {
                    await dataSharingVC.exportMealHistoryToCSV()
                    print("Meal history export triggered from shortcut")
                }
            }
        }
    }
    
    private func scheduleNotification(foodItemName: String, portionServed: Double, bolus: Double, mealDate: Date) {
        // Check if history notifications are allowed
        guard UserDefaultsRepository.historyNotificationsAllowed else {
            print("History notifications are disabled in settings.")
            return
        }
        
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                let content = UNMutableNotificationContent()
                
                // Localize title
                content.title = NSLocalizedString("Måltid loggad i historiken", comment: "Title for meal history notification")
                
                // Format date and amounts
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                let dateString = dateFormatter.string(from: mealDate)
                
                // Localize body text with format string
                let bodyFormat = NSLocalizedString(
                    """
                    Livsmedel: %@\nMängd: %.1fg\nBolus: %.2fE\nDatum: %@
                    """,
                    comment: "Body format for meal history notification"
                )
                content.body = String(format: bodyFormat, foodItemName, portionServed, bolus, dateString)
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

enum FoodItemSortOption: String, AppEnum {
    case name
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: "Sort Option")
    static var caseDisplayRepresentations: [FoodItemSortOption: DisplayRepresentation] = [
        .name: DisplayRepresentation(title: "Name")
    ]
}

struct FoodItemEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: "Food Item")
    
    var id: UUID
    var name: String
    var emoji: String
    var foodItem: FoodItem
    
    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(
            title: "\(name)" // Removed emoji from display
        )
    }
    
    static var defaultQuery = FoodItemQuery()
    
    static func suggestedEntities() async throws -> [FoodItemEntity] {
        return try await defaultQuery.entities()
    }
}

struct FoodItemQuery: EntityQuery {
    typealias Entity = FoodItemEntity
    
    func entities() async throws -> [FoodItemEntity] {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "delete == NO OR delete == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let foodItems = try context.fetch(fetchRequest)
        return foodItems.map { foodItem in
            FoodItemEntity(
                id: foodItem.id ?? UUID(),
                name: foodItem.name ?? "",
                emoji: foodItem.emoji ?? "🍽",
                foodItem: foodItem
            )
        }
    }
    
    func suggestedEntities() async throws -> [FoodItemEntity] {
        return try await entities()
    }
    
    func entities(for identifiers: [UUID]) async throws -> [FoodItemEntity] {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "(delete == NO OR delete == nil) AND id IN %@", identifiers)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let foodItems = try context.fetch(fetchRequest)
        return foodItems.map { foodItem in
            FoodItemEntity(
                id: foodItem.id ?? UUID(),
                name: foodItem.name ?? "",
                emoji: foodItem.emoji ?? "🍽",
                foodItem: foodItem
            )
        }
    }
}

struct FoodItemOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [FoodItemEntity] {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "delete == NO OR delete == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)] // Added sorting
        
        let foodItems = try context.fetch(fetchRequest)
        return foodItems.map { foodItem in
            FoodItemEntity(
                id: foodItem.id ?? UUID(),
                name: foodItem.name ?? "",
                emoji: foodItem.emoji ?? "🍽",
                foodItem: foodItem
            )
        }
    }
}
