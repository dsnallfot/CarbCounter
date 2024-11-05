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
        // Create a background task request
        let taskRequest = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        taskRequest.requiresNetworkConnectivity = false
        taskRequest.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(taskRequest)
        } catch {
            print("Could not schedule background task: \(error)")
        }
        
        // Create a background URL session configuration
        let config = URLSessionConfiguration.background(withIdentifier: "com.dsnallfot.CarbsCounter.backgroundSession")
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        
        // Start background task
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = await UIApplication.shared.beginBackgroundTask {
            // End the task if the background task expires
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        // Perform the save operation
        await saveMealHistory(
            foodItem: foodItem.foodItem,
            portionServed: portionServed,
            bolus: bolus,
            mealDate: mealDate
        )
        
        // End background task
        if backgroundTask != .invalid {
            await UIApplication.shared.endBackgroundTask(backgroundTask)
        }

        return .result()
    }

    private func saveMealHistory(foodItem: FoodItem, portionServed: Double, bolus: Double, mealDate: Date) async {
        let context = CoreDataStack.shared.context
        
        // Create a child context for background operations
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        await backgroundContext.perform {
            let mealHistory = MealHistory(context: backgroundContext)
            
            // Set unique ID, date, and lastEdited
            mealHistory.id = UUID()
            mealHistory.mealDate = mealDate
            mealHistory.lastEdited = Date()
            mealHistory.delete = false
            
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
            
            do {
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
            } catch {
                print("Failed to save MealHistory: \(error)")
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
    
    func defaultResult() async -> FoodItemEntity? {
        return try? await results().first
    }
}

