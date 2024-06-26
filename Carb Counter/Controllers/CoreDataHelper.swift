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
                startDoses[Int(result.hour)] = result.startDose
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
            if carbRatio.id == nil {
                carbRatio.id = UUID() // Set the id if it's not already set
            }
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
            let startDose = results.first ?? StartDoseSchedule(context: context)
            startDose.id = startDose.id ?? UUID() // Ensure id is set
            startDose.hour = Int16(hour)
            startDose.startDose = dose
            try context.save()
        } catch {
            print("Failed to save start dose: \(error)")
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
}
