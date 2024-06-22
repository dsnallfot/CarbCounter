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
        let exportButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportFoodItemsToCSV))
        let importButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importFoodItemsFromCSV))
        navigationItem.leftBarButtonItems = [exportButton, importButton]
    }
    
    @objc private func exportFoodItemsToCSV() {
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        
        do {
            let foodItems = try context.fetch(fetchRequest)
            let csvData = createCSV(from: foodItems)
            saveCSV(data: csvData)
        } catch {
            print("Failed to fetch food items: \(error)")
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
    
    private func saveCSV(data: String) {
        let fileName = "FoodItems.csv"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        do {
            try data.write(to: path!, atomically: true, encoding: String.Encoding.utf8)
            let activityViewController = UIActivityViewController(activityItems: [path!], applicationActivities: nil)
            present(activityViewController, animated: true, completion: nil)
        } catch {
            print("Failed to create file: \(error)")
        }
    }
    
    @objc private func importFoodItemsFromCSV() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    private func parseCSV(at url: URL) {
        do {
            let csvData = try String(contentsOf: url, encoding: .utf8)
            let rows = csvData.components(separatedBy: "\n").filter { !$0.isEmpty }
            let columns = rows[0].components(separatedBy: ";")
            
            guard columns.count == 13 else { // Adjusted to 13 to include count
                print("CSV file does not have the correct format")
                showAlert(title: "Import Failed", message: "CSV file does not have the correct format")
                return
            }
            
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            let context = appDelegate.persistentContainer.viewContext
            
            // Fetch existing food item IDs
            let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
            let existingFoodItems = try context.fetch(fetchRequest)
            let existingIDs = Set(existingFoodItems.compactMap { $0.id })
            
            for row in rows[1...] {
                let values = row.components(separatedBy: ";")
                if values.count == 13 { // Adjusted to 13 to include count
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
                        foodItem.count = Int16(values[12]) ?? 0 // Adjusted to parse count
                    }
                }
            }
            
            try context.save()
            showAlert(title: "Import Successful", message: "Food items have been imported")
        } catch {
            print("Failed to read CSV file: \(error)")
            showAlert(title: "Import Failed", message: "Could not read CSV file: \(error)")
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
        parseCSV(at: url)
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
