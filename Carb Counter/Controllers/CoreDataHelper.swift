import CoreData
import UIKit
import CloudKit

class CoreDataHelper: NSObject {
    static let shared = CoreDataHelper()
    let context = CoreDataStack.shared.context

    let sharedRootID = "sharedRootID"

    func fetchOrCreateSharedRoot() -> SharedRoot {
        let fetchRequest: NSFetchRequest<SharedRoot> = SharedRoot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", sharedRootID)

        do {
            let results = try context.fetch(fetchRequest)
            if let sharedRoot = results.first {
                return sharedRoot
            } else {
                let newSharedRoot = SharedRoot(context: context)
                newSharedRoot.id = sharedRootID
                try context.save()
                return newSharedRoot
            }
        } catch {
            fatalError("Failed to fetch or create SharedRoot: \(error)")
        }
    }
    func triggerCloudKitSyncOperation() {
        let container = CoreDataStack.shared.persistentContainer
        container.performBackgroundTask { context in
            let operation = CKFetchRecordZoneChangesOperation()
            operation.fetchAllChanges = true
            operation.recordZoneIDs = [CKRecordZone.default().zoneID]
            operation.qualityOfService = .userInitiated

            // Use the new block for record changes
            operation.recordWasChangedBlock = { recordID, recordResult in
                switch recordResult {
                case .success(let record):
                    print("Record changed: \(record)")
                case .failure(let error):
                    print("Failed to change record: \(error)")
                }
            }

            // Use the new block for completion
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    print("Successfully fetched changes.")
                case .failure(let error):
                    print("Failed to fetch changes: \(error)")
                }
            }

            CKContainer(identifier: "iCloud.com.dsnallfot.CarbContainer").sharedCloudDatabase.add(operation)
        }
    }
    // MARK: - Sharing Functionality

    func shareSharedRoot(completion: @escaping (UICloudSharingController?) -> Void) {
        let sharedRoot = fetchOrCreateSharedRoot()
        let container = CoreDataStack.shared.persistentContainer
        let context = container.viewContext

        // Use the container's share method to share the object
        container.share([sharedRoot], to: nil) { (objectIDs, share, cloudKitContainer, error) in
            if let error = error {
                print("Failed to share SharedRoot: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            guard let share = share else {
                print("Share is nil")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            // Set a default share title
            share[CKShare.SystemFieldKey.title] = "Shared Data" as CKRecordValue?

            // Save the context
            context.performAndWait {
                do {
                    if context.hasChanges {
                        try context.save()
                    }

                    // Create the UICloudSharingController
                    let shareController = UICloudSharingController(share: share, container: cloudKitContainer!)
                    shareController.delegate = self
                    DispatchQueue.main.async {
                        completion(shareController)
                    }
                } catch {
                    print("Failed to save context after sharing: \(error)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // Save or update Carb Ratio
    func saveCarbRatio(hour: Int, ratio: Double) {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "hour == %d AND sharedRoot == %@", hour, sharedRoot)

        do {
            let results = try context.fetch(fetchRequest)
            let carbRatio: CarbRatioSchedule

            if let existingCarbRatio = results.first {
                // Update existing entry
                carbRatio = existingCarbRatio
            } else {
                // Create new entry
                carbRatio = CarbRatioSchedule(context: context)
                carbRatio.hour = Int16(hour)
                carbRatio.sharedRoot = sharedRoot
            }

            carbRatio.carbRatio = ratio

            try context.save()
        } catch {
            print("Failed to save carb ratio: \(error)")
        }
    }
    
    // Update Carb Ratios with hourly mapping
    func updateCarbRatios(with hourlyCarbRatios: [Int: Double]) {
        for (hour, ratio) in hourlyCarbRatios {
            saveCarbRatio(hour: hour, ratio: ratio)
        }
    }
    
    // Fetch Carb Ratios for all hours
    func fetchCarbRatios() -> [Int: Double] {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "sharedRoot == %@", sharedRoot)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "hour", ascending: true)]
        do {
            let results = try context.fetch(fetchRequest)
            var carbRatios = [Int: Double]()
            var seenHours = Set<Int16>()
            for result in results {
                let hour = result.hour
                if seenHours.contains(hour) {
                    print("Warning: Multiple CarbRatioSchedule entries found for hour \(hour).")
                    // Optionally, clean up duplicates
                    // context.delete(result)
                    // try context.save()
                } else {
                    seenHours.insert(hour)
                    carbRatios[Int(hour)] = result.carbRatio
                }
            }
            return carbRatios
        } catch {
            print("Failed to fetch carb ratios: \(error)")
            return [:]
        }
    }

    // Fetch Carb Ratio for a specific hour
    func fetchCarbRatio(for hour: Int) -> Double? {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "hour == %d AND sharedRoot == %@", hour, sharedRoot)
        do {
            let results = try context.fetch(fetchRequest)
            if results.count > 1 {
                print("Warning: Multiple CarbRatioSchedule entries found for hour \(hour).")
                // Optionally, clean up duplicates
                // for duplicate in results.dropFirst() {
                //     context.delete(duplicate)
                // }
                // try context.save()
            }
            return results.first?.carbRatio
        } catch {
            print("Failed to fetch carb ratio: \(error)")
            return nil
        }
    }

    // Fetch Carb Ratio Schedule for a specific hour
    func fetchCarbRatioSchedule(hour: Int) -> CarbRatioSchedule? {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "hour == %d AND sharedRoot == %@", hour, sharedRoot)
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("Failed to fetch carb ratio schedule: \(error)")
            return nil
        }
    }
    
    // Delete Carb Ratio for a specific hour
    func deleteCarbRatio(hour: Int) {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "hour == %d AND sharedRoot == %@", hour, sharedRoot)
        do {
            let results = try context.fetch(fetchRequest)
            for carbRatio in results {
                context.delete(carbRatio)
            }
            try context.save()
        } catch {
            print("Failed to delete carb ratio: \(error)")
        }
    }
    
    // Clear all Carb Ratio entries
    func clearAllCarbRatios() {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "sharedRoot == %@", sharedRoot)
        do {
            let results = try context.fetch(fetchRequest)
            for object in results {
                context.delete(object)
            }
            try context.save()
        } catch {
            print("Failed to clear carb ratios: \(error)")
        }
    }
    
    // Save or update Start Dose
    func saveStartDose(hour: Int, dose: Double) {
        guard dose != 0 else {
            // If dose is zero, we handle deletion separately
            return
        }
        
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "hour == %d AND sharedRoot == %@", hour, sharedRoot)
        
        do {
            let results = try context.fetch(fetchRequest)
            let startDose: StartDoseSchedule
            
            if let existingStartDose = results.first {
                // Update existing entry
                startDose = existingStartDose
            } else {
                // Create new entry
                startDose = StartDoseSchedule(context: context)
                startDose.hour = Int16(hour)
                startDose.sharedRoot = sharedRoot
            }
            
            startDose.startDose = dose
            try context.save()
        } catch {
            print("Failed to save start dose: \(error)")
        }
    }
    
    // Fetch Start Doses for all hours
    func fetchStartDoses() -> [Int: Double] {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "sharedRoot == %@", sharedRoot)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "hour", ascending: true)]
        do {
            let results = try context.fetch(fetchRequest)
            var startDoses = [Int: Double]()
            var seenHours = Set<Int16>()
            for result in results {
                let hour = result.hour
                if result.startDose > 0 {
                    if seenHours.contains(hour) {
                        // Duplicate found
                        print("Warning: Multiple StartDoseSchedule entries found for hour \(hour).")
                        // Optionally, clean up duplicates
                        // context.delete(result)
                        // continue
                    } else {
                        seenHours.insert(hour)
                        startDoses[Int(hour)] = result.startDose
                    }
                }
            }
            // Optionally save context if duplicates were deleted
            // try context.save()
            return startDoses
        } catch {
            print("Failed to fetch start doses: \(error)")
            return [:]
        }
    }

    // Fetch Start Dose for a specific hour
    func fetchStartDose(for hour: Int) -> Double? {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "hour == %d AND sharedRoot == %@", hour, sharedRoot)
        do {
            let results = try context.fetch(fetchRequest)
            if results.count > 1 {
                print("Warning: Multiple StartDoseSchedule entries found for hour \(hour).")
                // Optionally clean up duplicates
                // Keep the first entry and delete the rest
                for duplicate in results.dropFirst() {
                    context.delete(duplicate)
                }
                try context.save()
            }
            return results.first?.startDose
        } catch {
            print("Failed to fetch start dose: \(error)")
            return nil
        }
    }
    // Delete Start Dose for a specific hour
    func deleteStartDose(hour: Int) {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "hour == %d AND sharedRoot == %@", hour, sharedRoot)
        
        do {
            let results = try context.fetch(fetchRequest)
            for startDose in results {
                context.delete(startDose)
            }
            try context.save()
        } catch {
            print("Failed to delete start dose: \(error)")
        }
    }
    
    // Clear all Start Dose entries
    func clearAllStartDoses() {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "sharedRoot == %@", sharedRoot)
        do {
            let results = try context.fetch(fetchRequest)
            for object in results {
                context.delete(object)
            }
            try context.save()
        } catch {
            print("Failed to clear start doses: \(error)")
        }
        removeDuplicateStartDoses()
    }
    
    func removeDuplicateStartDoses() {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "sharedRoot == %@", sharedRoot)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "hour", ascending: true)]
        do {
            let results = try context.fetch(fetchRequest)
            var seenHours = Set<Int16>()
            for startDose in results {
                if seenHours.contains(startDose.hour) {
                    // Duplicate found; delete it
                    context.delete(startDose)
                } else {
                    seenHours.insert(startDose.hour)
                }
            }
            try context.save()
        } catch {
            print("Failed to remove duplicates: \(error)")
        }
    }
    
    // Save or update Food Item
    func saveFoodItem(foodItemData: FoodItemDataModel) {
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND sharedRoot == %@", foodItemData.id as CVarArg, sharedRoot)

        do {
            let results = try context.fetch(fetchRequest)
            let foodItem: FoodItem

            if let existingFoodItem = results.first {
                // Update existing entry
                foodItem = existingFoodItem
            } else {
                // Create new entry
                foodItem = FoodItem(context: context)
                foodItem.id = foodItemData.id
                foodItem.sharedRoot = sharedRoot
            }

            foodItem.name = foodItemData.name
            foodItem.carbohydrates = foodItemData.carbohydrates
            foodItem.carbsPP = foodItemData.carbsPP
            foodItem.protein = foodItemData.protein
            foodItem.proteinPP = foodItemData.proteinPP
            foodItem.fat = foodItemData.fat
            foodItem.fatPP = foodItemData.fatPP
            foodItem.emoji = foodItemData.emoji
            foodItem.notes = foodItemData.notes
            foodItem.perPiece = foodItemData.perPiece
            foodItem.lastEdited = Date()
            foodItem.delete = false

            // Associate with SharedRoot
            let sharedRoot = fetchOrCreateSharedRoot()
            foodItem.sharedRoot = sharedRoot

            try context.save()
        } catch {
            print("Failed to save food item: \(error)")
        }
    }
    
    // Fetch all Food Items
    func fetchAllFoodItems() -> [FoodItem] {
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "delete == false AND sharedRoot == %@", sharedRoot)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        do {
            let results = try context.fetch(fetchRequest)
            var uniqueItems = [FoodItem]()
            var seenIds = Set<UUID>()
            for item in results {
                if let id = item.id, seenIds.contains(id) {
                    print("Warning: Duplicate FoodItem with id \(id) found.")
                    // Optionally delete duplicate
                    // context.delete(item)
                    // try context.save()
                } else {
                    if let id = item.id {
                        seenIds.insert(id)
                    }
                    uniqueItems.append(item)
                }
            }
            return uniqueItems
        } catch {
            print("Failed to fetch food items: \(error)")
            return []
        }
    }
    
    // Delete Food Item
    func deleteFoodItem(foodItem: FoodItem) {
        context.delete(foodItem)
        do {
            try context.save()
        } catch {
            print("Failed to delete food item: \(error)")
        }
    }
    
    // Save or update Favorite Meal
    func saveFavoriteMeal(favoriteMealData: FavoriteMealDataModel) {
        let fetchRequest: NSFetchRequest<FavoriteMeals> = FavoriteMeals.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND sharedRoot == %@", favoriteMealData.id as CVarArg, sharedRoot)

        do {
            let results = try context.fetch(fetchRequest)
            let favoriteMeal: FavoriteMeals

            if let existingMeal = results.first {
                favoriteMeal = existingMeal
            } else {
                favoriteMeal = FavoriteMeals(context: context)
                favoriteMeal.id = favoriteMealData.id
                favoriteMeal.sharedRoot = sharedRoot
            }

            favoriteMeal.name = favoriteMealData.name
            favoriteMeal.lastEdited = Date()
            favoriteMeal.delete = favoriteMealData.delete

            // Serialize items
            if let itemsData = encodeItems(favoriteMealData.items) {
                favoriteMeal.items = itemsData as NSObject
            }

            // Associate with SharedRoot
            let sharedRoot = fetchOrCreateSharedRoot()
            favoriteMeal.sharedRoot = sharedRoot

            try context.save()
        } catch {
            print("Failed to save favorite meal: \(error)")
        }
    }
    
    // Fetch all Favorite Meals
    func fetchAllFavoriteMeals() -> [FavoriteMealDataModel] {
        let fetchRequest: NSFetchRequest<FavoriteMeals> = FavoriteMeals.fetchRequest()
            let sharedRoot = fetchOrCreateSharedRoot()
            fetchRequest.predicate = NSPredicate(format: "delete == false AND sharedRoot == %@", sharedRoot)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            do {
                let results = try context.fetch(fetchRequest)
                var favoriteMealsData = [FavoriteMealDataModel]()
                var seenIds = Set<UUID>()
                for favoriteMeal in results {
                if let id = favoriteMeal.id, seenIds.contains(id) {
                                print("Warning: Duplicate FavoriteMeals with id \(id) found.")
                                // Optionally delete duplicate
                                // context.delete(favoriteMeal)
                                // try context.save()
                } else {
                    if let id = favoriteMeal.id {
                        seenIds.insert(id)
                    }
                    // Deserialize items
                    var items: [FoodItemDataModel] = []
                    if let data = favoriteMeal.items as? Data, let decodedItems = decodeItems(data) {
                        items = decodedItems
                    }
                    let favoriteMealData = FavoriteMealDataModel(
                        id: favoriteMeal.id ?? UUID(),
                        name: favoriteMeal.name,
                        items: items,
                        lastEdited: favoriteMeal.lastEdited,
                        delete: favoriteMeal.delete
                    )
                    favoriteMealsData.append(favoriteMealData)
                }
            }
            return favoriteMealsData
        } catch {
            print("Failed to fetch favorite meals: \(error)")
            return []
        }
    }
    
    // Delete Favorite Meal
    func deleteFavoriteMeal(favoriteMeal: FavoriteMeals) {
        context.delete(favoriteMeal)
        do {
            try context.save()
        } catch {
            print("Failed to delete favorite meal: \(error)")
        }
    }
    
    // Clear all favorite meals entries
    func clearAllFavorites() {
        let fetchRequest: NSFetchRequest<FavoriteMeals> = FavoriteMeals.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "sharedRoot == %@", sharedRoot)
        do {
            let results = try context.fetch(fetchRequest)
            for favoriteMeal in results {
                context.delete(favoriteMeal)
            }
            try context.save()
        } catch {
            print("Failed to clear favorites: \(error)")
        }
    }
    
    // Save Meal History
    func saveMealHistory(mealHistoryData: MealHistoryDataModel) {
        let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND sharedRoot == %@", mealHistoryData.id as CVarArg, sharedRoot)

        do {
            let results = try context.fetch(fetchRequest)
            let mealHistory: MealHistory

            if let existingMealHistory = results.first {
                // Update existing entry
                mealHistory = existingMealHistory
                // Delete existing food entries
                if let existingFoodEntries = mealHistory.foodEntries {
                    for entry in existingFoodEntries {
                        context.delete(entry as! NSManagedObject)
                    }
                }
            } else {
                // Create new entry
                mealHistory = MealHistory(context: context)
                mealHistory.id = mealHistoryData.id
                mealHistory.sharedRoot = sharedRoot
                mealHistory.mealDate = mealHistoryData.mealDate
                mealHistory.totalNetCarbs = mealHistoryData.totalNetCarbs
                mealHistory.totalNetProtein = mealHistoryData.totalNetProtein
                mealHistory.totalNetFat = mealHistoryData.totalNetFat
                mealHistory.totalNetBolus = mealHistoryData.totalNetBolus
                mealHistory.delete = mealHistoryData.delete
                
                // Add FoodItemEntries
                for entryData in mealHistoryData.foodEntries {
                    let foodEntry = FoodItemEntry(context: context)
                    foodEntry.entryId = entryData.entryId
                    foodEntry.entryName = entryData.entryName
                    foodEntry.entryCarbohydrates = entryData.entryCarbohydrates
                    foodEntry.entryCarbsPP = entryData.entryCarbsPP
                    foodEntry.entryProtein = entryData.entryProtein
                    foodEntry.entryProteinPP = entryData.entryProteinPP
                    foodEntry.entryFat = entryData.entryFat
                    foodEntry.entryFatPP = entryData.entryFatPP
                    foodEntry.entryEmoji = entryData.entryEmoji
                    foodEntry.entryNotEaten = entryData.entryNotEaten
                    foodEntry.entryPerPiece = entryData.entryPerPiece
                    foodEntry.entryPortionServed = entryData.entryPortionServed
                    foodEntry.mealHistory = mealHistory
                    
                    // Associate with SharedRoot
                    foodEntry.sharedRoot = sharedRoot
                }
            }
            try context.save()
        } catch {
            print("Failed to save meal history: \(error)")
        }
    }
    
    // Fetch all Meal Histories
    func fetchAllMealHistories() -> [MealHistoryDataModel] {
        let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
            let sharedRoot = fetchOrCreateSharedRoot()
            fetchRequest.predicate = NSPredicate(format: "delete == false AND sharedRoot == %@", sharedRoot)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "mealDate", ascending: false)]
            do {
            let results = try context.fetch(fetchRequest)
            var mealHistoriesData = [MealHistoryDataModel]()
                var seenIds = Set<UUID>()
                for mealHistory in results {
                    if let id = mealHistory.id, seenIds.contains(id) {
                        print("Warning: Duplicate MealHistory with id \(id) found.")
                        // Optionally delete duplicate
                        // context.delete(mealHistory)
                        // try context.save()
                    } else {
                        if let id = mealHistory.id {
                            seenIds.insert(id)
                        }
                        var foodEntriesData = [FoodItemEntryDataModel]()
                        if let foodEntries = mealHistory.foodEntries as? Set<FoodItemEntry> {
                            for foodEntry in foodEntries {
                                let foodEntryData = FoodItemEntryDataModel(
                                    entryId: foodEntry.entryId ?? UUID(),
                                    entryName: foodEntry.entryName,
                                    entryCarbohydrates: foodEntry.entryCarbohydrates,
                                    entryCarbsPP: foodEntry.entryCarbsPP,
                                    entryProtein: foodEntry.entryProtein,
                                    entryProteinPP: foodEntry.entryProteinPP,
                                    entryFat: foodEntry.entryFat,
                                    entryFatPP: foodEntry.entryFatPP,
                                    entryEmoji: foodEntry.entryEmoji,
                                    entryNotEaten: foodEntry.entryNotEaten,
                                    entryPerPiece: foodEntry.entryPerPiece,
                                    entryPortionServed: foodEntry.entryPortionServed
                                )
                                foodEntriesData.append(foodEntryData)
                            }
                        }
                        let mealHistoryData = MealHistoryDataModel(
                            id: mealHistory.id ?? UUID(),
                            mealDate: mealHistory.mealDate,
                            totalNetBolus: mealHistory.totalNetBolus,
                            totalNetCarbs: mealHistory.totalNetCarbs,
                            totalNetFat: mealHistory.totalNetFat,
                            totalNetProtein: mealHistory.totalNetProtein,
                            foodEntries: foodEntriesData,
                            delete: mealHistory.delete
                        )
                        mealHistoriesData.append(mealHistoryData)
                    }
                }
            return mealHistoriesData
        } catch {
            print("Failed to fetch meal histories: \(error)")
            return []
        }
    }
    
    // Delete Meal History
    func deleteMealHistory(mealHistory: MealHistory) {
        context.delete(mealHistory)
        do {
            try context.save()
        } catch {
            print("Failed to delete meal history: \(error)")
        }
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                print("Context saved successfully.")
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    struct FoodItemDataModel: Codable {
        var id: UUID
        var name: String?
        var carbohydrates: Double
        var carbsPP: Double
        var protein: Double
        var proteinPP: Double
        var fat: Double
        var fatPP: Double
        var emoji: String?
        var notes: String?
        var perPiece: Bool
    }
    
    struct FavoriteMealDataModel {
        var id: UUID
        var name: String?
        var items: [FoodItemDataModel] // An array of FoodItemDataModel
        var lastEdited: Date?
        var delete: Bool
    }

    struct MealHistoryDataModel {
        var id: UUID
        var mealDate: Date?
        var totalNetBolus: Double
        var totalNetCarbs: Double
        var totalNetFat: Double
        var totalNetProtein: Double
        var foodEntries: [FoodItemEntryDataModel]
        var delete: Bool
    }

    struct FoodItemEntryDataModel {
        var entryId: UUID
        var entryName: String?
        var entryCarbohydrates: Double
        var entryCarbsPP: Double
        var entryProtein: Double
        var entryProteinPP: Double
        var entryFat: Double
        var entryFatPP: Double
        var entryEmoji: String?
        var entryNotEaten: Double
        var entryPerPiece: Bool
        var entryPortionServed: Double
    }
    
    // Encoding
    func encodeItems(_ items: [FoodItemDataModel]) -> Data? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(items)
            return data
        } catch {
            print("Failed to encode items: \(error)")
            return nil
        }
    }

    // Decoding
    func decodeItems(_ data: Data) -> [FoodItemDataModel]? {
        let decoder = JSONDecoder()
        do {
            let items = try decoder.decode([FoodItemDataModel].self, from: data)
            return items
        } catch {
            print("Failed to decode items: \(error)")
            return nil
        }
    }
    
    }

// MARK: - UICloudSharingControllerDelegate

extension CoreDataHelper: UICloudSharingControllerDelegate {
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("Failed to save share: \(error)")
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        // Print out the current participant's information
        if let participant = csc.share?.currentUserParticipant {
            print("Participant name: \(String(describing: participant.userIdentity.nameComponents))")
        }
        return "Shared Data"
    }

    func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
        // Return image data if you want a thumbnail
        return nil
    }

    func itemType(for csc: UICloudSharingController) -> String? {
        return "public.data"
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        print("Successfully saved share")
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        print("Stopped sharing")
        // Handle the stop sharing action
    }
}
