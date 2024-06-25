//
//  CSVImportExportViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-22.
//

// CSVImportExportViewController.swift

import UIKit
import CoreData
import UniformTypeIdentifiers

class CSVImportExportViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CSV Import/Export"
        view.backgroundColor = .systemBackground
        
        setupNavigationBarButtons()
    }
    
    private func setupNavigationBarButtons() {
        let exportButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportData))
        let importButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importData))
        navigationItem.rightBarButtonItems = [exportButton, importButton]
    }
    
    @objc private func exportData() {
        let alert = UIAlertController(title: "Export Data", message: "Choose which data to export", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Food Items", style: .default, handler: { _ in self.exportFoodItemsToCSV() }))
        alert.addAction(UIAlertAction(title: "Favorite Meals", style: .default, handler: { _ in self.exportFavoriteMealsToCSV() }))
        alert.addAction(UIAlertAction(title: "Carb Ratio Schedule", style: .default, handler: { _ in self.exportCarbRatioScheduleToCSV() }))
        alert.addAction(UIAlertAction(title: "Start Dose Schedule", style: .default, handler: { _ in self.exportStartDoseScheduleToCSV() }))
        alert.addAction(UIAlertAction(title: "Meal History", style: .default, handler: { _ in self.exportMealHistoryToCSV() }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func importData() {
        let alert = UIAlertController(title: "Import Data", message: "Choose which data to import", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Food Items", style: .default, handler: { _ in self.importCSV(for: "Food Items") }))
        alert.addAction(UIAlertAction(title: "Favorite Meals", style: .default, handler: { _ in self.importCSV(for: "Favorite Meals") }))
        alert.addAction(UIAlertAction(title: "Carb Ratio Schedule", style: .default, handler: { _ in self.importCSV(for: "Carb Ratio Schedule") }))
        alert.addAction(UIAlertAction(title: "Start Dose Schedule", style: .default, handler: { _ in self.importCSV(for: "Start Dose Schedule") }))
        alert.addAction(UIAlertAction(title: "Meal History", style: .default, handler: { _ in self.importCSV(for: "Meal History") }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func exportFoodItemsToCSV() {
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        exportToCSV(fetchRequest: fetchRequest, fileName: "FoodItems.csv", createCSV: createCSV(from:))
    }
    
    @objc private func exportFavoriteMealsToCSV() {
        let fetchRequest: NSFetchRequest<FavoriteMeals> = FavoriteMeals.fetchRequest()
        exportToCSV(fetchRequest: fetchRequest, fileName: "FavoriteMeals.csv", createCSV: createCSV(from:))
    }
    
    @objc private func exportCarbRatioScheduleToCSV() {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        exportToCSV(fetchRequest: fetchRequest, fileName: "CarbRatioSchedule.csv", createCSV: createCSV(from:))
    }
    
    @objc private func exportStartDoseScheduleToCSV() {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        exportToCSV(fetchRequest: fetchRequest, fileName: "StartDoseSchedule.csv", createCSV: createCSV(from:))
    }
    
    @objc private func exportMealHistoryToCSV() {
        let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
        exportToCSV(fetchRequest: fetchRequest, fileName: "MealHistory.csv", createCSV: createCSV(from:))
    }
    
    private func exportToCSV<T: NSFetchRequestResult>(fetchRequest: NSFetchRequest<T>, fileName: String, createCSV: ([T]) -> String) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        
        do {
            let entities = try context.fetch(fetchRequest)
            let csvData = createCSV(entities)
            saveCSV(data: csvData, fileName: fileName)
        } catch {
            print("Failed to fetch data: \(error)")
        }
    }
    
    private func createCSV(from foodItems: [FoodItem]) -> String {
        var csvString = "id;name;carbohydrates;carbsPP;fat;fatPP;netCarbs;netFat;netProtein;perPiece;protein;proteinPP;count;notes\n"
        
        for item in foodItems {
            let id = item.id?.uuidString ?? ""
            let name = item.name ?? ""
            let carbohydrates = item.carbohydrates
            let carbsPP = item.carbsPP
            let fat = item.fat
            let fatPP = item.fatPP
            let netCarbs = item.netCarbs
            let netFat = item.netFat
            let netProtein = item.netProtein
            let perPiece = item.perPiece
            let protein = item.protein
            let proteinPP = item.proteinPP
            let count = item.count
            let notes = item.notes ?? ""
            
            csvString += "\(id);\(name);\(carbohydrates);\(carbsPP);\(fat);\(fatPP);\(netCarbs);\(netFat);\(netProtein);\(perPiece);\(protein);\(proteinPP);\(count);\(notes)\n"
        }
        
        return csvString
    }
    
    private func createCSV(from favoriteMeals: [FavoriteMeals]) -> String {
        var csvString = "id;name;items\n"
        
        for meal in favoriteMeals {
            let id = meal.id?.uuidString ?? ""
            let name = meal.name ?? ""
            let itemsData = (meal.items as? [[String: Any]]) ?? []
            let items = itemsData.compactMap { item in
                guard let name = item["name"] as? String,
                      let portionServed = item["portionServed"] as? String,
                      let perPiece = item["perPiece"] as? Bool else {
                    return nil
                }
                return "\(name):\(portionServed):\(perPiece)"
            }.joined(separator: "|")
            
            csvString += "\(id);\(name);\(items)\n"
        }
        
        return csvString
    }
    
    private func createCSV(from carbRatioSchedules: [CarbRatioSchedule]) -> String {
        var csvString = "hour;carbRatio\n"
        
        for schedule in carbRatioSchedules {
            let hour = schedule.hour
            let carbRatio = schedule.carbRatio
            csvString += "\(hour);\(carbRatio)\n"
        }
        
        return csvString
    }
    
    private func createCSV(from startDoseSchedules: [StartDoseSchedule]) -> String {
        var csvString = "hour;startDose\n"
        
        for schedule in startDoseSchedules {
            let hour = schedule.hour
            let startDose = schedule.startDose
            csvString += "\(hour);\(startDose)\n"
        }
        
        return csvString
    }
    
    private func createCSV(from mealHistories: [MealHistory]) -> String {
        var csvString = "id;mealDate;totalNetCarbs;totalNetFat;totalNetProtein;foodEntries\n"
        
        for mealHistory in mealHistories {
            let id = mealHistory.id?.uuidString ?? ""
            let mealDate = mealHistory.mealDate.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? ""
            let totalNetCarbs = mealHistory.totalNetCarbs
            let totalNetFat = mealHistory.totalNetFat
            let totalNetProtein = mealHistory.totalNetProtein
            
            let foodEntries = (mealHistory.foodEntries as? Set<FoodItemEntry>)?.map { entry in
                [
                    entry.entryId?.uuidString ?? "",
                    entry.entryName ?? "",
                    entry.entryPortionServed,
                    entry.entryNotEaten,
                    entry.entryCarbohydrates,
                    entry.entryFat,
                    entry.entryProtein,
                    entry.entryPerPiece ? "1" : "0"
                ].map { "\($0)" }.joined(separator: ",")
            }.joined(separator: "|") ?? ""
            
            csvString += "\(id);\(mealDate);\(totalNetCarbs);\(totalNetFat);\(totalNetProtein);\(foodEntries)\n"
        }
        
        return csvString
    }
    
    private func saveCSV(data: String, fileName: String) {
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            try data.write(to: path!, atomically: true, encoding: .utf8)
            let activityViewController = UIActivityViewController(activityItems: [path!], applicationActivities: nil)
            present(activityViewController, animated: true, completion: nil)
        } catch {
            print("Failed to create file: \(error)")
        }
    }
    
    @objc private func importCSV(for entityName: String) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
        documentPicker.delegate = self
        documentPicker.accessibilityHint = entityName
        present(documentPicker, animated: true, completion: nil)
    }
    
    private func parseCSV(at url: URL, for entityName: String) {
        do {
            let csvData = try String(contentsOf: url, encoding: .utf8)
            let rows = csvData.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            let context = appDelegate.persistentContainer.viewContext
            
            switch entityName {
            case "Food Items":
                parseFoodItemsCSV(rows, context: context)
            case "Favorite Meals":
                parseFavoriteMealsCSV(rows, context: context)
            case "Carb Ratio Schedule":
                parseCarbRatioScheduleCSV(rows, context: context)
            case "Start Dose Schedule":
                parseStartDoseScheduleCSV(rows, context: context)
            case "Meal History":
                parseMealHistoryCSV(rows, context: context)
            default:
                break
            }
            
            try context.save()
            showAlert(title: "Import Successful", message: "\(entityName) has been imported")
        } catch {
            print("Failed to read CSV file: \(error)")
            showAlert(title: "Import Failed", message: "Could not read CSV file: \(error)")
        }
    }
    
    private func parseFoodItemsCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 14 else {
            showAlert(title: "Import Failed", message: "CSV file was not correctly formatted")
            return
        }
        
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        let existingFoodItems = try? context.fetch(fetchRequest)
        let existingIDs = Set(existingFoodItems?.compactMap { $0.id } ?? [])
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 14 {
                if let id = UUID(uuidString: values[0]), !existingIDs.contains(id) {
                    let foodItem = FoodItem(context: context)
                    foodItem.id = id
                    foodItem.name = values[1]
                    foodItem.carbohydrates = Double(values[2]) ?? 0.0
                    foodItem.carbsPP = Double(values[3]) ?? 0.0
                    foodItem.fat = Double(values[4]) ?? 0.0
                    foodItem.fatPP = Double(values[5]) ?? 0.0
                    foodItem.netCarbs = Double(values[6]) ?? 0.0
                    foodItem.netFat = Double(values[7]) ?? 0.0
                    foodItem.netProtein = Double(values[8]) ?? 0.0
                    foodItem.perPiece = values[9] == "true"
                    foodItem.protein = Double(values[10]) ?? 0.0
                    foodItem.proteinPP = Double(values[11]) ?? 0.0
                    foodItem.count = Int16(values[12]) ?? 0
                    foodItem.notes = values[13]
                }
            }
        }
    }
    
    private func parseFavoriteMealsCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 3 else {
            showAlert(title: "Import Failed", message: "CSV file was not correctly formatted")
            return
        }
        
        let fetchRequest: NSFetchRequest<FavoriteMeals> = FavoriteMeals.fetchRequest()
        let existingFavoriteMeals = try? context.fetch(fetchRequest)
        let existingIDs = Set(existingFavoriteMeals?.compactMap { $0.id } ?? [])
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 3 {
                if let id = UUID(uuidString: values[0]), !existingIDs.contains(id) {
                    let favoriteMeal = FavoriteMeals(context: context)
                    favoriteMeal.id = id
                    favoriteMeal.name = values[1]
                    
                    let itemsData = values[2].components(separatedBy: "|").map { item -> [String: Any] in
                        let parts = item.components(separatedBy: ":")
                        return [
                            "name": parts[0],
                            "portionServed": parts[1],
                            "perPiece": parts[2] == "true"
                        ]
                    }
                    favoriteMeal.items = itemsData as NSObject
                }
            }
        }
    }
    
    private func parseCarbRatioScheduleCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 2 else {
            showAlert(title: "Import Failed", message: "CSV file was not correctly formatted")
            return
        }
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 2 {
                let carbRatioSchedule = CarbRatioSchedule(context: context)
                carbRatioSchedule.hour = Int16(values[0]) ?? 0
                carbRatioSchedule.carbRatio = Double(values[1]) ?? 0.0
            }
        }
    }
    
    private func parseStartDoseScheduleCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 2 else {
            showAlert(title: "Import Failed", message: "CSV file was not correctly formatted")
            return
        }
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 2 {
                let startDoseSchedule = StartDoseSchedule(context: context)
                startDoseSchedule.hour = Int16(values[0]) ?? 0
                startDoseSchedule.startDose = Double(values[1]) ?? 0.0
            }
        }
    }
    
    private func parseMealHistoryCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 6 else {
            showAlert(title: "Import Failed", message: "CSV file was not correctly formatted")
            return
        }
        
        let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
        let existingMealHistories = try? context.fetch(fetchRequest)
        let existingIDs = Set(existingMealHistories?.compactMap { $0.id } ?? [])
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 6 {
                if let id = UUID(uuidString: values[0]), !existingIDs.contains(id) {
                    let mealHistory = MealHistory(context: context)
                    mealHistory.id = id
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    mealHistory.mealDate = dateFormatter.date(from: values[1])
                    mealHistory.totalNetCarbs = Double(values[2]) ?? 0.0
                    mealHistory.totalNetFat = Double(values[3]) ?? 0.0
                    mealHistory.totalNetProtein = Double(values[4]) ?? 0.0
                    
                    let foodEntriesValues = values[5].components(separatedBy: "|")
                    for foodEntryValue in foodEntriesValues {
                        let foodEntryParts = foodEntryValue.components(separatedBy: ",")
                        if foodEntryParts.count == 8 {
                            let foodEntry = FoodItemEntry(context: context)
                            foodEntry.entryId = UUID(uuidString: foodEntryParts[0])
                            foodEntry.entryName = foodEntryParts[1]
                            foodEntry.entryPortionServed = Double(foodEntryParts[2]) ?? 0.0
                            foodEntry.entryNotEaten = Double(foodEntryParts[3]) ?? 0.0
                            foodEntry.entryCarbohydrates = Double(foodEntryParts[4]) ?? 0.0
                            foodEntry.entryFat = Double(foodEntryParts[5]) ?? 0.0
                            foodEntry.entryProtein = Double(foodEntryParts[6]) ?? 0.0
                            foodEntry.entryPerPiece = foodEntryParts[7] == "1"
                            mealHistory.addToFoodEntries(foodEntry)
                        }
                    }
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
}

// UIDocumentPickerDelegate implementation
extension CSVImportExportViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        if let entityName = controller.accessibilityHint {
            parseCSV(at: url, for: entityName)
        }
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
