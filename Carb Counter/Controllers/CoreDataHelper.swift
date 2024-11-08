import CoreData
import UIKit

class CoreDataHelper {
    static let shared = CoreDataHelper()
    let context = CoreDataStack.shared.context

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
    func saveCarbRatio(hour: Int, ratio: Double, lastEdited: Date = Date()) {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)

        do {
            let results = try context.fetch(fetchRequest)
            let carbRatio = results.first ?? CarbRatioSchedule(context: context)
            
            carbRatio.hour = Int16(hour)
            carbRatio.carbRatio = ratio
            carbRatio.lastEdited = lastEdited
            
            try context.save()
        } catch {
            print("Failed to save carb ratio: \(error)")
        }
    }


    // Save or update Start Dose
    func saveStartDose(hour: Int, dose: Double, lastEdited: Date = Date()) {
            let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)

            do {
                let results = try context.fetch(fetchRequest)
                if dose == 0 {
                    if let startDose = results.first {
                        context.delete(startDose)
                        try context.save()
                        print("Start dose deleted for hour \(hour)")
                    }
                } else {
                    let startDose = results.first ?? StartDoseSchedule(context: context)
                    startDose.hour = Int16(hour)
                    startDose.startDose = dose
                    startDose.lastEdited = lastEdited
                    try context.save()
                    print("Start dose saved for hour \(hour) with lastEdited \(lastEdited)")
                }
            } catch {
                print("Failed to save start dose: \(error)")
            }
        }

    // Update Carb Ratios with hourly mapping
    func updateCarbRatios(with hourlyCarbRatios: [Int: Double]) {
        for (hour, ratio) in hourlyCarbRatios {
            saveCarbRatio(hour: hour, ratio: ratio, lastEdited: Date())
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
                print("Start dose deleted for hour \(hour)")
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
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NewFavoriteMeals.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear favorites: \(error)")
        }
    }
    
    // Clear all Meal History entries
    func clearAllMealHistory() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = MealHistory.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear meal history: \(error)")
        }
    }
    
    // Delete all MealHistory entries older than 365 days
        func clearOldMealHistory() {
            let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
            
            // Calculate the date 365 days ago
            let calendar = Calendar.current
            if let date365DaysAgo = calendar.date(byAdding: .day, value: -365, to: Date()) {
                fetchRequest.predicate = NSPredicate(format: "mealDate < %@", date365DaysAgo as NSDate)
                
                do {
                    let oldMealHistories = try context.fetch(fetchRequest)
                    
                    // Delete each entry in the result
                    for mealHistory in oldMealHistories {
                        context.delete(mealHistory)
                    }
                    
                    // Save the context to persist changes
                    try context.save()
                    print("Old meal history entries older than 365 days have been deleted.")
                    
                } catch {
                    print("Failed to delete old meal history entries: \(error)")
                }
            }
        }
}
