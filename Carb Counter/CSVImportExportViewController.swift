//
//  CSVImportExportViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-22.
//

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
        let alert = UIAlertController(title: "Exportera data", message: "Välj vilken data du vill exportera", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Food Items", style: .default, handler: { _ in self.exportFoodItemsToCSV() }))
        alert.addAction(UIAlertAction(title: "Favorite Meals", style: .default, handler: { _ in self.exportFavoriteMealsToCSV() }))
        alert.addAction(UIAlertAction(title: "Carb Ratio Schedule", style: .default, handler: { _ in self.exportCarbRatioScheduleToCSV() }))
        alert.addAction(UIAlertAction(title: "Start Dose Schedule", style: .default, handler: { _ in self.exportStartDoseScheduleToCSV() }))
        alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel))
        
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func importData() {
        let alert = UIAlertController(title: "Importera data", message: "Välj vilken data du vill importera", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Food Items", style: .default, handler: { _ in self.importCSV(for: "Food Items") }))
        alert.addAction(UIAlertAction(title: "Favorite Meals", style: .default, handler: { _ in self.importCSV(for: "Favorite Meals") }))
        alert.addAction(UIAlertAction(title: "Carb Ratio Schedule", style: .default, handler: { _ in self.importCSV(for: "Carb Ratio Schedule") }))
        alert.addAction(UIAlertAction(title: "Start Dose Schedule", style: .default, handler: { _ in self.importCSV(for: "Start Dose Schedule") }))
        alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel))
        
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
        var csvString = "id;name;carbohydrates;carbsPP;fat;fatPP;netCarbs;netFat;netProtein;perPiece;protein;proteinPP;count\n"
        
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
            
            csvString += "\(id);\(name);\(carbohydrates);\(carbsPP);\(fat);\(fatPP);\(netCarbs);\(netFat);\(netProtein);\(perPiece);\(protein);\(proteinPP);\(count)\n"
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
                      let portionServed = item["portionServed"] as? String else {
                    return nil
                }
                return "\(name):\(portionServed)"
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
    
    private func saveCSV(data: String, fileName: String) {
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        do {
            try data.write(to: path!, atomically: true, encoding: String.Encoding.utf8)
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
            default:
                break
            }
            
            try context.save()
            showAlert(title: "Import lyckades", message: "\(entityName) har importerats")
        } catch {
            print("Failed to read CSV file: \(error)")
            showAlert(title: "Import misslyckades", message: "Kunde inte läsa CSV-fil: (error)")
        }
    }
    private func parseFoodItemsCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 13 else {
            showAlert(title: "Import misslyckades", message: "CSV-fil var inte korrekt formaterad")
            return
        }
        
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        let existingFoodItems = try? context.fetch(fetchRequest)
        let existingIDs = Set(existingFoodItems?.compactMap { $0.id } ?? [])
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 13 {
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
                }
            }
        }
    }
    
    private func parseFavoriteMealsCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 3 else {
            showAlert(title: "Import misslyckades", message: "CSV-fil var inte korrekt formaterad")
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
                        return ["name": parts[0], "portionServed": parts[1]]
                    }
                    favoriteMeal.items = itemsData as NSObject
                }
            }
        }
    }
    
    private func parseCarbRatioScheduleCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 2 else {
            showAlert(title: "Import misslyckades", message: "CSV-fil var inte korrekt formaterad")
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
            showAlert(title: "Import misslyckades", message: "CSV-fil var inte korrekt formaterad")
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
