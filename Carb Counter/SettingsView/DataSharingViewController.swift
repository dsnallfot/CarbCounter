import UIKit
import CloudKit
import CoreData
import UniformTypeIdentifiers

class DataSharingViewController: UIViewController {
    
    private var lastImportTime: Date?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dela data"
        view.backgroundColor = .systemBackground
        
        setupNavigationBarButtons()
    }
    
    private func setupNavigationBarButtons() {
        let exportButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportData))
        let importButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importData))
        navigationItem.rightBarButtonItems = [exportButton, importButton]
    }
    
    //Manual exporting and importing
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
    
    ///Manual and automatic importing
    @objc public func importAllCSVFiles() {
        // Run the import process on a background thread with low priority
        DispatchQueue.global(qos: .background).async {
            self.performImportAllCSVFiles()
        }
    }
    
    private func performImportAllCSVFiles() {
        // Check if the function was called less than 10 seconds ago
        if let lastImportTime = lastImportTime, Date().timeIntervalSince(lastImportTime) < 15 {
            print("Import blocked to prevent running more often than every 15 seconds")
            return
        }
        
        // Update the last import time
        lastImportTime = Date()
        
        let fileManager = FileManager.default
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/CarbsCounter") else {
            print("Import Failed: iCloud Drive URL is nil.")
            return
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: iCloudURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            let entityFileMapping: [String: String] = [
                "FoodItems.csv": "Food Items",
                "FavoriteMeals.csv": "Favorite Meals",
                "MealHistory.csv": "Meal History",
                "CarbRatioSchedule.csv": "Carb Ratio Schedule",
                "StartDoseSchedule.csv": "Start Dose Schedule"
            ]
            
            let dispatchGroup = DispatchGroup()
            
            for (fileName, entityName) in entityFileMapping {
                if let fileURL = fileURLs.first(where: { $0.lastPathComponent == fileName }) {
                    dispatchGroup.enter()
                    parseCSV(at: fileURL, for: entityName)
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                print("Data import done!")
            }
            
        } catch {
            print("Failed to list directory: \(error)")
        }
    }
    
    ///Exporting
    @objc public func exportFoodItemsToCSV() {
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        exportToCSV(fetchRequest: fetchRequest, fileName: "FoodItems.csv", createCSV: createCSV(from:))
    }
    
    @objc public func exportFavoriteMealsToCSV() {
        let fetchRequest: NSFetchRequest<FavoriteMeals> = FavoriteMeals.fetchRequest()
        exportToCSV(fetchRequest: fetchRequest, fileName: "FavoriteMeals.csv", createCSV: createCSV(from:))
    }
    
    @objc public func exportCarbRatioScheduleToCSV() {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        exportToCSV(fetchRequest: fetchRequest, fileName: "CarbRatioSchedule.csv", createCSV: createCSV(from:))
    }
    
    @objc public func exportStartDoseScheduleToCSV() {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        exportToCSV(fetchRequest: fetchRequest, fileName: "StartDoseSchedule.csv", createCSV: createCSV(from:))
    }
    
    @objc public func exportMealHistoryToCSV() {
        let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
        exportToCSV(fetchRequest: fetchRequest, fileName: "MealHistory.csv", createCSV: createCSV(from:))
    }
    
    public func exportToCSV<T: NSFetchRequestResult>(fetchRequest: NSFetchRequest<T>, fileName: String, createCSV: @escaping ([T]) -> String) {
        DispatchQueue.global(qos: .background).async {
            let context = CoreDataStack.shared.context
            
            do {
                let entities = try context.fetch(fetchRequest)
                let csvData = createCSV(entities)
                
                DispatchQueue.main.async {
                    self.saveCSV(data: csvData, fileName: fileName)
                    print("\(fileName) export done")
                }
            } catch {
                DispatchQueue.main.async {
                    print("Failed to fetch data: \(error)")
                }
            }
        }
    }
    
    ///Creating csv files
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
            
            let itemsString = meal.items as? String ?? ""
            
            csvString += "\(id);\(name);\(itemsString)\n"
        }
        
        return csvString
    }
    
    private func createCSV(from carbRatioSchedules: [CarbRatioSchedule]) -> String {
        var csvString = "hour;carbRatio\n"
        var scheduleDict = [Int16: Double]()
        
        for schedule in carbRatioSchedules {
            scheduleDict[schedule.hour] = schedule.carbRatio
        }
        
        for hour in 0..<24 {
            let carbRatio = scheduleDict[Int16(hour)] ?? 0.0
            csvString += "\(hour);\(carbRatio)\n"
        }
        return csvString
    }
    
    private func createCSV(from startDoseSchedules: [StartDoseSchedule]) -> String {
        var csvString = "hour;startDose\n"
        var scheduleDict = [Int16: Double]()
        
        for schedule in startDoseSchedules {
            scheduleDict[schedule.hour] = schedule.startDose
        }
        
        for hour in 0..<24 {
            let startDose = scheduleDict[Int16(hour)] ?? 0.0
            csvString += "\(hour);\(startDose)\n"
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
                print("Export Successful: Data has been exported to iCloud successfully.")
            } else {
                print("Export Failed: iCloud Drive URL is nil.")
            }
        } catch {
            print("Failed to save file to iCloud: \(error)")
        }
    }
    
    ///Importing and parsing
    @objc public func importCSV(for entityName: String) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
        documentPicker.delegate = self
        documentPicker.accessibilityHint = entityName
        present(documentPicker, animated: true, completion: nil)
    }
    
    public func parseCSV(at url: URL, for entityName: String) {
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
                return
            }
            
            try context.save()
            print("Import Successful: \(entityName) has been imported")
        } catch {
            print("Failed to read CSV file: \(error)")
        }
    }
    
    public func parseFoodItemsCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 15 else {
            print("Import Failed: CSV file was not correctly formatted")
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
            print("Failed to save food items: \(error)")
        }
    }
    
    public func parseFavoriteMealsCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 3 else {
            print("Import Failed: CSV file was not correctly formatted")
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
                    favoriteMeal.items = values[2] as NSObject
                }
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Save Failed: Failed to save favorite meals: \(error)")
        }
    }
    
    public func parseCarbRatioScheduleCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 2 else {
            print("Import Failed: CSV file was not correctly formatted")
            return
        }
        
        // Delete existing schedules
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CarbRatioSchedule.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
        } catch {
            print("Failed to delete existing CarbRatioSchedules: \(error)")
        }
        
        // Import new schedules
        var scheduleDict = [Int16: Double]()
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 2,
               let hour = Int16(values[0]),
               let carbRatio = Double(values[1]),
               hour >= 0, hour < 24 { // Ensure hour is between 0 and 23
                scheduleDict[hour] = carbRatio
            }
        }
        
        for (hour, carbRatio) in scheduleDict {
            let carbRatioSchedule = CarbRatioSchedule(context: context)
            carbRatioSchedule.hour = hour
            carbRatioSchedule.carbRatio = carbRatio
        }
        
        do {
            try context.save()
        } catch {
            print("Save Failed: Failed to save Carb Ratio Schedules: (error)")
        }
    }
    public func parseStartDoseScheduleCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 2 else {
            print("Import Failed: CSV file was not correctly formatted")
            return
        }
        
        // Delete existing schedules
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = StartDoseSchedule.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
        } catch {
            print("Failed to delete existing StartDoseSchedules: \(error)")
        }
        
        // Import new schedules
        var scheduleDict = [Int16: Double]()
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 2,
               let hour = Int16(values[0]),
               let startDose = Double(values[1]),
               hour >= 0, hour < 24 { // Ensure hour is between 0 and 23
                scheduleDict[hour] = startDose
            }
        }
        
        for (hour, startDose) in scheduleDict {
            let startDoseSchedule = StartDoseSchedule(context: context)
            startDoseSchedule.hour = hour
            startDoseSchedule.startDose = startDose
        }
        
        do {
            try context.save()
        } catch {
            print("Save Failed: Failed to save Start Dose Schedules: \(error)")
        }
    }
    
    public func parseMealHistoryCSV(_ rows: [String], context: NSManagedObjectContext) {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 6 else {
            print("Import Failed: CSV file was not correctly formatted")
            return
        }
        
        let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
        do {
            let existingMealHistories = try context.fetch(fetchRequest)
            let existingIDs = Set(existingMealHistories.compactMap { $0.id })
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Use the same format for export and import
            
            for row in rows[1...] {
                let values = row.components(separatedBy: ";")
                if values.count == 6, !values.allSatisfy({ $0.isEmpty || $0 == "0" }) { // Ensure no blank or all-zero rows
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
            try context.save()
        } catch {
            print("Import Failed: Error fetching or saving data: \(error)")
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
