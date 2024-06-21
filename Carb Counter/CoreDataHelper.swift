import CoreData
import UIKit

class CoreDataHelper {
    static let shared = CoreDataHelper()
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

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

    // Save or update Start Dose
    func saveStartDose(hour: Int, dose: Double) {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hour == %d", hour)
        
        do {
            let results = try context.fetch(fetchRequest)
            let startDose = results.first ?? StartDoseSchedule(context: context)
            startDose.hour = Int16(hour)
            startDose.startDose = dose
            try context.save()
        } catch {
            print("Failed to save start dose: \(error)")
        }
    }
}
