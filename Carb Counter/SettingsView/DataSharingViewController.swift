import UIKit
import CloudKit
import CoreData
import UniformTypeIdentifiers

class DataSharingViewController: UIViewController {
    
    private var shareURLTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dela data"
        view.backgroundColor = .systemBackground
        
        setupNavigationBarButtons()
        setupURLTextFieldAndButton()
    }
    
    private func setupNavigationBarButtons() {
        let exportButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportData))
        let importButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importData))
        navigationItem.rightBarButtonItems = [exportButton, importButton]
    }
    
    private func setupURLTextFieldAndButton() {
        shareURLTextField = UITextField(frame: .zero)
        shareURLTextField.placeholder = "Ange URL för datadelning"
        shareURLTextField.autocapitalizationType = .none
        shareURLTextField.keyboardType = .URL
        shareURLTextField.borderStyle = .roundedRect
        shareURLTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shareURLTextField)
        
        let acceptButton = UIButton(type: .system)
        acceptButton.setTitle("Acceptera iCloud datadelning", for: .normal)
        acceptButton.addTarget(self, action: #selector(acceptSharedData), for: .touchUpInside)
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(acceptButton)
        
        NSLayoutConstraint.activate([
            shareURLTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            shareURLTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            shareURLTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            acceptButton.topAnchor.constraint(equalTo: shareURLTextField.bottomAnchor, constant: 20),
            acceptButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    @objc private func acceptSharedData() {
        guard let shareURLString = shareURLTextField.text, !shareURLString.isEmpty, let shareURL = URL(string: shareURLString) else {
            showAlert(title: "Felaktig URL", message: "Vänligen ange en giltig delnings-URL.")
            return
        }
        CloudKitShareController.shared.acceptShare(from: shareURL) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showAlert(title: "Misslyckades att acceptera delning", message: "Error: \(error.localizedDescription)")
                } else {
                    self.showAlert(title: "Lyckades", message: "Delning av data accepterades.")
                }
            }
        }
    }
    
    // MARK: - Sharing Data
    
    @objc private func exportData() {
        let alert = UIAlertController(title: "Vill du exportera din data till iCloud?", message: "• Livsmedel\n• Favoritmåltider\n• Måltidshistorik\n• Carb ratio schema\n• Startdoser schema", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Exportera allt", style: .default, handler: { _ in self.exportAllCSVFiles() }))
        alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel))
        
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func importData() {
        let alert = UIAlertController(title: "Importera data", message: "Välj vilken data du vill importera", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Importera allt", style: .default, handler: { _ in self.importAllCSVFiles() }))
        alert.addAction(UIAlertAction(title: "Livsmedel", style: .default, handler: { _ in self.importCSV(for: "Food Items") }))
        alert.addAction(UIAlertAction(title: "Favoritmåltider", style: .default, handler: { _ in self.importCSV(for: "Favorite Meals") }))
        alert.addAction(UIAlertAction(title: "Måltidshistorik", style: .default, handler: { _ in self.importCSV(for: "Meal History") }))
        alert.addAction(UIAlertAction(title: "Carb ratios schema", style: .default, handler: { _ in self.importCSV(for: "Carb Ratio Schedule") }))
        alert.addAction(UIAlertAction(title: "Startdoser schema", style: .default, handler: { _ in self.importCSV(for: "Start Dose Schedule") }))
        alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func exportAllCSVFiles() {
        exportCarbRatioScheduleToCSV()
        exportFavoriteMealsToCSV()
        exportFoodItemsToCSV()
        exportMealHistoryToCSV()
        exportStartDoseScheduleToCSV()
        
        showAlert(title: "Export Successful", message: "All data has been exported successfully.")
    }
    
    @objc private func importAllCSVFiles() {
        let fileManager = FileManager.default
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/CarbsCounter") else {
            showAlert(title: "Import Failed", message: "iCloud Drive URL is nil.")
            return
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: iCloudURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            let foodItemFiles = fileURLs.filter { $0.lastPathComponent.hasSuffix("FoodItems.csv") }
            let favoriteMealFiles = fileURLs.filter { $0.lastPathComponent.hasSuffix("FavoriteMeals.csv") }
            let mealHistoryFiles = fileURLs.filter { $0.lastPathComponent.hasSuffix("MealHistory.csv") }
            let carbRatioScheduleFiles = fileURLs.filter { $0.lastPathComponent.hasSuffix("CarbRatioSchedule.csv") }
            let startDoseScheduleFiles = fileURLs.filter { $0.lastPathComponent.hasSuffix("StartDoseSchedule.csv") }
            
            let dispatchGroup = DispatchGroup()
            
            for file in foodItemFiles {
                dispatchGroup.enter()
                parseCSV(at: file, for: "Food Items")
                dispatchGroup.leave()
            }
            
            for file in favoriteMealFiles {
                dispatchGroup.enter()
                parseCSV(at: file, for: "Favorite Meals")
                dispatchGroup.leave()
            }
            
            for file in mealHistoryFiles {
                dispatchGroup.enter()
                parseCSV(at: file, for: "Meal History")
                dispatchGroup.leave()
            }
            
            for file in carbRatioScheduleFiles {
                dispatchGroup.enter()
                parseCSV(at: file, for: "Carb Ratio Schedule")
                dispatchGroup.leave()
            }
            
            for file in startDoseScheduleFiles {
                dispatchGroup.enter()
                parseCSV(at: file, for: "Start Dose Schedule")
                dispatchGroup.leave()
            }
            
            dispatchGroup.notify(queue: .main) {
                self.showAlert(title: "Import Successful", message: "All data has been imported successfully.")
            }
            
        } catch {
            print("Failed to list directory: \(error)")
            showAlert(title: "Import Failed", message: "Failed to list directory: \(error.localizedDescription)")
        }
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
        let context = CoreDataStack.shared.context
        
        do {
            let entities = try context.fetch(fetchRequest)
            let csvData = createCSV(entities)
            
            var caregiverName = UserDefaults.standard.string(forKey: "caregiverName") ?? ""
            caregiverName = caregiverName.replacingOccurrences(of: " ", with: "")
            let prefixedFileName = "\(caregiverName)\(fileName)"
            saveCSV(data: csvData, fileName: prefixedFileName)
        } catch {
            print("Failed to fetch data: \(error)")
        }
    }
    
    private func createCSV(from foodItems: [FoodItem]) -> String {
        var csvString = "id;name;carbohydrates;carbsPP;fat;fatPP;netCarbs;netFat;netProtein;perPiece;protein;proteinPP;count;notes;emoji\n"
        
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
            let emoji = item.emoji ?? ""
            
            csvString += "\(id);\(name);\(carbohydrates);\(carbsPP);\(fat);\(fatPP);\(netCarbs);\(netFat);\(netProtein);\(perPiece);\(protein);\(proteinPP);\(count);\(notes);\(emoji)\n"
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
        var csvString = "id;hour;carbRatio\n"
        
        for schedule in carbRatioSchedules {
            let id = schedule.id?.uuidString ?? ""
            let hour = schedule.hour
            let carbRatio = schedule.carbRatio
            csvString += "\(id);\(hour);\(carbRatio)\n"
        }
        
        return csvString
    }
    
    private func createCSV(from startDoseSchedules: [StartDoseSchedule]) -> String {
        var csvString = "id;hour;startDose\n"
        
        for schedule in startDoseSchedules {
            let id = schedule.id?.uuidString ?? ""
            let hour = schedule.hour
            let startDose = schedule.startDose
            csvString += "\(id);\(hour);\(startDose)\n"
        }
        
        return csvString
    }
    
    private func createCSV(from mealHistories: [MealHistory]) -> String {
        var csvString = "id;mealDate;totalNetCarbs;totalNetFat;totalNetProtein;foodEntries\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Use the same format for export and import
        
        for mealHistory in mealHistories {
            let id = mealHistory.id?.uuidString ?? ""
            let mealDate = mealHistory.mealDate.map { dateFormatter.string(from: $0) } ?? ""
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
                    entry.entryPerPiece ? "1" : "0",
                    entry.entryEmoji ?? ""
                ].map { "\($0)" }.joined(separator: ",")
            }.joined(separator: "|") ?? ""
            
            csvString += "\(id);\(mealDate);\(totalNetCarbs);\(totalNetFat);\(totalNetProtein);\(foodEntries)\n"
        }
        
        return csvString
    }
    
    private func saveCSV(data: String, fileName: String) {
        let tempDirectory = NSURL(fileURLWithPath: NSTemporaryDirectory())
        let tempFilePath = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempFilePath!, atomically: true, encoding: .utf8)
            
            let fileManager = FileManager.default
            let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/CarbsCounter")
            let destinationURL = iCloudURL?.appendingPathComponent(fileName)
            
            if let destinationURL = destinationURL {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: tempFilePath!, to: destinationURL)
                showAlert(title: "Export Successful", message: "Data has been exported to iCloud successfully.")
            } else {
                showAlert(title: "Export Failed", message: "iCloud Drive URL is nil.")
            }
        } catch {
            print("Failed to save file to iCloud: \(error)")
            showAlert(title: "Export Failed", message: "Failed to save file to iCloud: \(error.localizedDescription)")
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
            
            let context = CoreDataStack.shared.context
            
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
                print("Unknown entity name: \(entityName)")
                showAlert(title: "Import Failed", message: "Unknown entity name: \(entityName)")
                return
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
        guard columns.count == 15 else {
            showAlert(title: "Import Failed", message: "CSV file was not correctly formatted")
            return
        }
        
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        let existingFoodItems = try? context.fetch(fetchRequest)
        let existingFoodItemsDict = Dictionary(uniqueKeysWithValues: existingFoodItems?.compactMap { ($0.id, $0) } ?? [])
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 15 {
                if let id = UUID(uuidString: values[0]),
                   !values.dropFirst().allSatisfy({ $0.isEmpty || $0 == "0" }) { // Ensure no blank or all-zero rows
                    let foodItem = existingFoodItemsDict[id] ?? FoodItem(context: context)
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
                    foodItem.emoji = values[14]
                }
            }
        }
        do {
            try context.save()
        } catch {
            showAlert(title: "Save Failed", message: "Failed to save food items: \(error)")
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
            if values.count == 3,
               !values.allSatisfy({ $0.isEmpty || $0 == "0" }) { // Ensure no blank or all-zero rows
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
        guard columns.count == 3 else {  // id;hour;carbRatio
            showAlert(title: "Import Failed", message: "CSV file was not correctly formatted")
            return
        }
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 3,
               !values.allSatisfy({ $0.isEmpty || $0 == "0" }) { // Ensure no blank or all-zero rows
                let id = UUID(uuidString: values[0]) ?? UUID()
                let hour = Int16(values[1]) ?? 0
                let carbRatio = Double(values[2]) ?? 0.0
                
                let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                
                let existingSchedules = try? context.fetch(fetchRequest)
                let carbRatioSchedule = existingSchedules?.first ?? CarbRatioSchedule(context: context)
                carbRatioSchedule.id = id
                carbRatioSchedule.hour = hour
                carbRatioSchedule.carbRatio = carbRatio
            }
        }
    }
    
    private func parseStartDoseScheduleCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 3 else {  // id;hour;startDose
            showAlert(title: "Import Failed", message: "CSV file was not correctly formatted")
            return
        }
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 3,
               !values.allSatisfy({ $0.isEmpty || $0 == "0" }) { // Ensure no blank or all-zero rows
                let id = UUID(uuidString: values[0]) ?? UUID()
                let hour = Int16(values[1]) ?? 0
                let startDose = Double(values[2]) ?? 0.0
                
                let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                
                let existingSchedules = try? context.fetch(fetchRequest)
                let startDoseSchedule = existingSchedules?.first ?? StartDoseSchedule(context: context)
                startDoseSchedule.id = id
                startDoseSchedule.hour = hour
                startDoseSchedule.startDose = startDose
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
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Use the same format for export and import
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 6,
               !values.allSatisfy({ $0.isEmpty || $0 == "0" }) { // Ensure no blank or all-zero rows
                if let id = UUID(uuidString: values[0]), !existingIDs.contains(id) {
                    let mealHistory = MealHistory(context: context)
                    mealHistory.id = id
                    mealHistory.mealDate = dateFormatter.date(from: values[1])
                    mealHistory.totalNetCarbs = Double(values[2]) ?? 0.0
                    mealHistory.totalNetFat = Double(values[3]) ?? 0.0
                    mealHistory.totalNetProtein = Double(values[4]) ?? 0.0
                    
                    let foodEntriesValues = values[5].components(separatedBy: "|")
                    for foodEntryValue in foodEntriesValues {
                        let foodEntryParts = foodEntryValue.components(separatedBy: ",")
                        if foodEntryParts.count == 9 {
                            let foodEntry = FoodItemEntry(context: context)
                            foodEntry.entryId = UUID(uuidString: foodEntryParts[0])
                            foodEntry.entryName = foodEntryParts[1]
                            foodEntry.entryPortionServed = Double(foodEntryParts[2]) ?? 0.0
                            foodEntry.entryNotEaten = Double(foodEntryParts[3]) ?? 0.0
                            foodEntry.entryCarbohydrates = Double(foodEntryParts[4]) ?? 0.0
                            foodEntry.entryFat = Double(foodEntryParts[5]) ?? 0.0
                            foodEntry.entryProtein = Double(foodEntryParts[6]) ?? 0.0
                            foodEntry.entryPerPiece = foodEntryParts[7] == "1"
                            foodEntry.entryEmoji = foodEntryParts[8]
                            mealHistory.addToFoodEntries(foodEntry)
                        }
                    }
                }
            }
        }
        do {
            try context.save()
        } catch {
            showAlert(title: "Import Failed", message: "Error saving data")
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
}

extension DataSharingViewController: UIDocumentPickerDelegate {
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
