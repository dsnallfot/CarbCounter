//
//  CoreDataHelper.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-21.
//

import CoreData
import UIKit

class CoreDataHelper {
    static let shared = CoreDataHelper()
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    // Fetch Carb Ratios
    func fetchCarbRatios() -> [CarbRatioSchedule] {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch carb ratios: \(error)")
            return []
        }
    }
    
    // Save Carb Ratio
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
    
    // Fetch Start Doses
    func fetchStartDoses() -> [StartDoseSchedule] {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch start doses: \(error)")
            return []
        }
    }
    
    // Save Start Dose
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
