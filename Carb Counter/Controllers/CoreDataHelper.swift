import CoreData
import UIKit

class CoreDataHelper {
    static let shared = CoreDataHelper()
    let context = CoreDataStack.shared.context

    // Fetch or create SharedRoot
        func fetchOrCreateSharedRoot() -> SharedRoot {
            let fetchRequest: NSFetchRequest<SharedRoot> = SharedRoot.fetchRequest()
            do {
                let results = try context.fetch(fetchRequest)
                if let sharedRoot = results.first {
                    return sharedRoot
                } else {
                    let newSharedRoot = SharedRoot(context: context)
                    try context.save()
                    return newSharedRoot
                }
            } catch {
                fatalError("Failed to fetch or create SharedRoot: \(error)")
            }
        }
    
    // Save or update Carb Ratio
    func saveCarbRatio(hour: Int, ratio: Double) {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)

        do {
            let results = try context.fetch(fetchRequest)
            let carbRatio = results.first ?? CarbRatioSchedule(context: context)
            carbRatio.hour = Int16(hour)
            carbRatio.carbRatio = ratio

            // Associate with SharedRoot
            let sharedRoot = fetchOrCreateSharedRoot()
            carbRatio.sharedRoot = sharedRoot

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
        
        // Filter by SharedRoot
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "sharedRoot == %@", sharedRoot)
        
        do {
            let results = try context.fetch(fetchRequest)
            var carbRatios = [Int: Double]()
            for result in results {
                carbRatios[Int(result.hour)] = result.carbRatio
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
            if let carbRatio = results.first {
                context.delete(carbRatio)
                try context.save()
            }
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
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)
        do {
            let results = try context.fetch(fetchRequest)
            if dose == 0 {
                if let startDose = results.first {
                    context.delete(startDose)
                    try context.save()
                }
            } else {
                let startDose = results.first ?? StartDoseSchedule(context: context)
                startDose.hour = Int16(hour)
                startDose.startDose = dose

                // Associate with SharedRoot
                let sharedRoot = fetchOrCreateSharedRoot()
                startDose.sharedRoot = sharedRoot

                try context.save()
            }
        } catch {
            print("Failed to save start dose: \(error)")
        }
    }
    
    // Fetch Start Doses for all hours
    func fetchStartDoses() -> [Int: Double] {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        let sharedRoot = fetchOrCreateSharedRoot()
        fetchRequest.predicate = NSPredicate(format: "sharedRoot == %@", sharedRoot)
        do {
            let results = try context.fetch(fetchRequest)
            var startDoses = [Int: Double]()
            for result in results {
                if result.startDose > 0 {
                    startDoses[Int(result.hour)] = result.startDose
                }
            }
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
            if let startDose = results.first {
                context.delete(startDose)
                try context.save()
            }
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
            print("Failed to clear carb ratios: \(error)")
        }
    }
    
    // Save or update Food Item
    func saveFoodItem(foodItemData: FoodItemDataModel) {
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", foodItemData.id as CVarArg)

        do {
            let results = try context.fetch(fetchRequest)
            let foodItem = results.first ?? FoodItem(context: context)
            foodItem.id = foodItemData.id
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
        fetchRequest.predicate = NSPredicate(format: "delete == false")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        do {
            let results = try context.fetch(fetchRequest)
            return results
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
        fetchRequest.predicate = NSPredicate(format: "id == %@", favoriteMealData.id as CVarArg)

        do {
            let results = try context.fetch(fetchRequest)
            let favoriteMeal = results.first ?? FavoriteMeals(context: context)
            favoriteMeal.id = favoriteMealData.id
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
        fetchRequest.predicate = NSPredicate(format: "delete == false")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        do {
            let results = try context.fetch(fetchRequest)
            var favoriteMealsData = [FavoriteMealDataModel]()
            for favoriteMeal in results {
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
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = FavoriteMeals.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear favorites: \(error)")
        }
    }
    
    // Save Meal History
    func saveMealHistory(mealHistoryData: MealHistoryDataModel) {
        let mealHistory = MealHistory(context: context)
        mealHistory.id = mealHistoryData.id
        mealHistory.mealDate = mealHistoryData.mealDate
        mealHistory.totalNetCarbs = mealHistoryData.totalNetCarbs
        mealHistory.totalNetProtein = mealHistoryData.totalNetProtein
        mealHistory.totalNetFat = mealHistoryData.totalNetFat
        mealHistory.totalNetBolus = mealHistoryData.totalNetBolus
        mealHistory.delete = mealHistoryData.delete

        // Associate with SharedRoot
        let sharedRoot = fetchOrCreateSharedRoot()
        mealHistory.sharedRoot = sharedRoot

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

        do {
            try context.save()
        } catch {
            print("Failed to save meal history: \(error)")
        }
    }
    
    // Fetch all Meal Histories
    func fetchAllMealHistories() -> [MealHistoryDataModel] {
        let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "delete == false")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "mealDate", ascending: false)]
        do {
            let results = try context.fetch(fetchRequest)
            var mealHistoriesData = [MealHistoryDataModel]()
            for mealHistory in results {
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
    
    
// MARK: OLD CODE
    
   /*
    // Fetch Carb Ratios for all hours
    func fetchCarbRatios() -> [Int: Double] {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            var carbRatios = [Int: Double]()
            for result in results {
                carbRatios[Int(result.hour)] = result.carbRatio
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
        fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)
        do {
            let results = try context.fetch(fetchRequest)
            return results.first?.carbRatio
        } catch {
            print("Failed to fetch carb ratio: \(error)")
            return nil
        }
    }

    // Fetch Carb Ratio Schedule for a specific hour
    func fetchCarbRatioSchedule(hour: Int) -> CarbRatioSchedule? {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("Failed to fetch carb ratio schedule: \(error)")
            return nil
        }
    }

    // Fetch Start Dose for all hours
    func fetchStartDoses() -> [Int: Double] {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            var startDoses = [Int: Double]()
            for result in results {
                if result.startDose > 0 {
                    startDoses[Int(result.hour)] = result.startDose
                }
            }
            return startDoses
        } catch {
            print("Failed to fetch start doses: \(error)")
            return [:]
        }
    }

    // Fetch Start Dose for a specific hour
    func fetchStartDose(for hour: Int) -> Double? {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)
        do {
            let results = try context.fetch(fetchRequest)
            return results.first?.startDose
        } catch {
            print("Failed to fetch start dose: \(error)")
            return nil
        }
    }

    // Fetch Start Dose Schedule for a specific hour
    func fetchStartDoseSchedule(hour: Int) -> StartDoseSchedule? {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("Failed to fetch start dose schedule: \(error)")
            return nil
        }
    }

    // Save or update Carb Ratio
    func saveCarbRatio(hour: Int, ratio: Double) {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)

        do {
            let results = try context.fetch(fetchRequest)
            let carbRatio = results.first ?? CarbRatioSchedule(context: context)
            carbRatio.hour = Int16(hour)
            carbRatio.carbRatio = ratio
            try context.save()
        } catch {
            print("Failed to save carb ratio: \(error)")
        }
    }

    // Save or update Start Dose
    func saveStartDose(hour: Int, dose: Double) {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)
        do {
            let results = try context.fetch(fetchRequest)
            if dose == 0 {
                if let startDose = results.first {
                    context.delete(startDose)
                    try context.save()
                }
            } else {
                let startDose = results.first ?? StartDoseSchedule(context: context)
                startDose.hour = Int16(hour)
                startDose.startDose = dose
                try context.save()
            }
        } catch {
            print("Failed to save start dose: \(error)")
        }
    }

    // Update Carb Ratios with hourly mapping
    func updateCarbRatios(with hourlyCarbRatios: [Int: Double]) {
        for (hour, ratio) in hourlyCarbRatios {
            saveCarbRatio(hour: hour, ratio: ratio)
        }
    }

    // Clear all Carb Ratio entries
    func clearAllCarbRatios() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CarbRatioSchedule.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear carb ratios: \(error)")
        }
    }
    
    // Delete Start Dose for a specific hour
    func deleteStartDose(hour: Int) {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)
        do {
            let results = try context.fetch(fetchRequest)
            if let startDose = results.first {
                context.delete(startDose)
                try context.save()
            }
        } catch {
            print("Failed to delete start dose: \(error)")
        }
    }

    // Clear all Start Dose entries
    func clearAllStartDoses() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = StartDoseSchedule.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear start doses: \(error)")
        }
    }
    
    // Clear all favorite meals entries
    func clearAllFavorites() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = FavoriteMeals.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear favorites: \(error)")
        }
    }
}*/
