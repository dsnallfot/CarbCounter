// Daniel: 800+ lines - To be cleaned
import UIKit
import CloudKit
import CoreData
import UniformTypeIdentifiers

class DataSharingViewController: UIViewController, UICloudSharingControllerDelegate {
    
    private var lastImportTime: Date?
    private var viewHasAppeared = false
    private var pendingImportEntityName: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // Create the gradient view
        let colors: [CGColor] = [
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        ]
        let gradientView = GradientView(colors: colors)
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the gradient view to the main view
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)
        
        // Set up constraints for the gradient view
        NSLayoutConstraint.activate([
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        title = NSLocalizedString("Dela data", comment: "Dela data")
        view.backgroundColor = .systemBackground
        
        setupNavigationBarButtons()
        setupToggleForOngoingMealSharing()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleShareAcceptance), name: .didAcceptShare, object: nil)

    }
    
    private func setupNavigationBarButtons() {
        let exportButton = UIBarButtonItem(image: UIImage(systemName: "arrow.up.doc"), style: .plain, target: self, action: #selector(exportData))
        let importButton = UIBarButtonItem(image: UIImage(systemName: "arrow.down.doc"), style: .plain, target: self, action: #selector(importData))
        let shareButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(shareButtonTapped(_:)))

        navigationItem.rightBarButtonItems = [shareButton, exportButton, importButton]
    }
    
    @IBAction func shareButtonTapped(_ sender: Any) {
        fetchCurrentUserIdentity { recordID in
            guard let recordID = recordID else {
                print("Failed to fetch current user record ID.")
                return
            }
            
            let sharedRoot = CoreDataHelper.shared.fetchOrCreateSharedRoot()
            let container = CoreDataStack.shared.persistentContainer
            let context = container.viewContext
            
            container.share([sharedRoot], to: nil) { (objectIDs, share, cloudKitContainer, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Failed to create share: \(error.localizedDescription)")
                        return
                    }

                    guard let share = share else {
                        print("Share is nil")
                        return
                    }

                    // Set the title of the share
                    share[CKShare.SystemFieldKey.title] = "Carb Counter Shared Data" as CKRecordValue?

                    // Save the context to persist the share
                    context.performAndWait {
                        do {
                            if context.hasChanges {
                                try context.save()
                            }
                        } catch {
                            print("Failed to save context after sharing: \(error)")
                            return
                        }
                    }

                    // Create the UICloudSharingController
                    let sharingController = UICloudSharingController(share: share, container: cloudKitContainer!)
                    sharingController.delegate = self
                    self.present(sharingController, animated: true, completion: nil)
                }
            }
        }
    }
    
    func fetchCurrentUserIdentity(completion: @escaping (CKRecord.ID?) -> Void) {
        let ckContainer = CKContainer(identifier: "iCloud.com.dsnallfot.CarbContainer")
        
        ckContainer.fetchUserRecordID { (recordID, error) in
            if let error = error {
                print("Failed to fetch user record ID: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let recordID = recordID else {
                print("Failed to fetch user record ID.")
                completion(nil)
                return
            }
            
            completion(recordID)
        }
    }
    
    @objc func handleShareAcceptance() {
        // Refresh the data or update the UI as needed
        print("Share accepted - refreshing data")
        // Fetch data from CoreData or update the UI accordingly
    }
    
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("Failed to save share: \(error.localizedDescription)")
    }
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return "Carb Counter Shared Data"
    }
    
    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        print("Successfully saved share")
    }
    
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        print("Stopped sharing")
        // Handle the stop sharing action
    }
    
    private func setupToggleForOngoingMealSharing() {
        let toggleSwitch = UISwitch()
        toggleSwitch.isOn = UserDefaultsRepository.allowSharingOngoingMeals
        toggleSwitch.addTarget(self, action: #selector(toggleOngoingMealSharing(_:)), for: .valueChanged)
        
        let toggleLabel = UILabel()
        toggleLabel.text = NSLocalizedString("Tillåt delning av pågående måltid", comment: "Tillåt delning av pågående måltid")
        toggleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [toggleLabel, toggleSwitch])
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.distribution = .fill
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }
    
    @objc private func toggleOngoingMealSharing(_ sender: UISwitch) {
        UserDefaultsRepository.allowSharingOngoingMeals = sender.isOn
        print("allowSharingOngoingMeals set to \(sender.isOn)")
    }
    
    //Manual exporting and importing
    @objc private func exportData() {
        let alert = UIAlertController(title: NSLocalizedString("Välj vilken data du vill exportera", comment: "Välj vilken data du vill exportera"), message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Hela databasen", comment: "Hela databasen"), style: .default, handler: { _ in
            Task { await self.exportAllCSVFiles() }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Användarinställningar", comment: "Användarinställningar"), style: .default, handler: { _ in
            Task { await self.exportUserDefaultsToCSV() }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel))
        
        present(alert, animated: true, completion: nil)
    }

    @objc private func importData() {
        print("Import data action triggered.")
        let alert = UIAlertController(title: NSLocalizedString("Importera data", comment: "Importera data"), message: NSLocalizedString("Välj vilken data du vill importera", comment: "Välj vilken data du vill importera"), preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Importera hela databasen", comment: "Importera hela databasen"), style: .default, handler: { _ in
            print("Import all data option selected.")
            Task {
                print("Starting to import all CSV files...")
                await self.importAllCSVFiles()
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Livsmedel", comment: "Livsmedel"), style: .default, handler: { _ in
            print("Import specific CSV for Food Items selected.")
            Task {
                await self.presentDocumentPicker(for: "Food Items")
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Favoritmåltider", comment: "Favoritmåltider"), style: .default, handler: { _ in
            print("Import specific CSV for Favorite Meals selected.")
            Task {
                await self.presentDocumentPicker(for: "Favorite Meals")
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Måltidshistorik", comment: "Måltidshistorik"), style: .default, handler: { _ in
            print("Import specific CSV for Meal History selected.")
            Task {
                await self.presentDocumentPicker(for: "Meal History")
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Carb ratios schema", comment: "Carb ratios schema"), style: .default, handler: { _ in
            print("Import specific CSV for Carb Ratio Schedule selected.")
            Task {
                await self.presentDocumentPicker(for: "Carb Ratio Schedule")
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Startdoser schema", comment: "Startdoser schema"), style: .default, handler: { _ in
            print("Import specific CSV for Start Dose Schedule selected.")
            Task {
                await self.presentDocumentPicker(for: "Start Dose Schedule")
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Användarinställningar", comment: "Användarinställningar"), style: .default, handler: { _ in
            print("Import specific CSV for User Defaults selected.")
            Task {
                await self.presentDocumentPicker(for: "UserDefaults")
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel))
        
        print("Displaying import data options alert.")
        present(alert, animated: true, completion: nil)
    }
    
    
    @objc private func exportAllCSVFiles() async {
        await exportCarbRatioScheduleToCSV()
        await exportFavoriteMealsToCSV()
        await exportFoodItemsToCSV()
        await exportMealHistoryToCSV()
        await exportStartDoseScheduleToCSV()
        
        showAlert(title: "Export Successful", message: "All data has been exported successfully.")
    }
    
    ///Manual and automatic importing
    @objc public func importAllCSVFiles() async {
        await self.performImportAllCSVFiles()
    }
    
    private func performImportAllCSVFiles() async {
        // Check if the function was called less than 15 seconds ago
        if let lastImportTime = lastImportTime, Date().timeIntervalSince(lastImportTime) < 15 {
            print("Import blocked to prevent running more often than every 15 seconds")
            return
        }
        
        // Update the last import time
        lastImportTime = Date()
        
        let fileManager = FileManager.default
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/NewCarbsCounter") else {
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
            
            
            for (fileName, entityName) in entityFileMapping {
                if let fileURL = fileURLs.first(where: { $0.lastPathComponent == fileName }) {
                    await parseCSV(at: fileURL, for: entityName)
                    
                }
            }
            print("Data import done!")
            
        } catch {
            print("Failed to list directory: \(error)")
        }
    }
    
///Ongoing meal import
    @objc public func importOngoingMealCSV() {
        let fileManager = FileManager.default
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/NewCarbsCounter/OngoingMeal.csv") else {
            print("Import Failed: iCloud Drive URL is nil.")
            return
        }
        do {
            let csvData = try String(contentsOf: iCloudURL, encoding: .utf8)
            let rows = csvData.components(separatedBy: "\n").filter { !$0.isEmpty }
            let importedRows = parseOngoingMealCSV(rows)
            NotificationCenter.default.post(name: .didImportOngoingMeal, object: nil, userInfo: ["foodItemRows": importedRows])
            print("Import Successful: OngoingMeal.csv has been imported")
        } catch {
            print("Failed to read CSV file: \(error)")
        }
    }
    ///Exporting
    @objc public func exportFoodItemsToCSV() async {
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        await exportToCSV(fetchRequest: fetchRequest, fileName: "FoodItems.csv", createCSV: createCSV(from:))
    }
    
    @objc public func exportFavoriteMealsToCSV() async {
        let fetchRequest: NSFetchRequest<FavoriteMeals> = FavoriteMeals.fetchRequest()
        await exportToCSV(fetchRequest: fetchRequest, fileName: "FavoriteMeals.csv", createCSV: createCSV(from:))
    }
    
    @objc public func exportCarbRatioScheduleToCSV() async {
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        await exportToCSV(fetchRequest: fetchRequest, fileName: "CarbRatioSchedule.csv", createCSV: createCSV(from:))
    }
    
    @objc public func exportStartDoseScheduleToCSV() async {
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        await exportToCSV(fetchRequest: fetchRequest, fileName: "StartDoseSchedule.csv", createCSV: createCSV(from:))
    }
    
    @objc public func exportMealHistoryToCSV() async {
        let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
        await exportToCSV(fetchRequest: fetchRequest, fileName: "MealHistory.csv", createCSV: createCSV(from:))
    }
    
    public func exportToCSV<T: NSFetchRequestResult>(fetchRequest: NSFetchRequest<T>, fileName: String, createCSV: @escaping ([T]) -> String) async {
        let context = CoreDataStack.shared.context
        
        do {
            let entities = try context.fetch(fetchRequest)
            let csvData = createCSV(entities)
            await self.saveCSV(data: csvData, fileName: fileName)
            print("\(fileName) export done")
        } catch {
            print("Failed to fetch data: \(error)")
        }
    }
    
    ///Creating csv files
    private func createCSV(from foodItems: [FoodItem]) -> String {
        var csvString = "id;name;carbohydrates;carbsPP;fat;fatPP;netCarbs;netFat;netProtein;perPiece;protein;proteinPP;count;notes;lastEdited;delete;emoji\n"
        
        let dateFormatter = ISO8601DateFormatter()  // Using ISO 8601 format for dates
        
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
            let lastEdited = dateFormatter.string(from: item.lastEdited ?? Date())  // Format lastEdited date
            let delete = item.delete  // Adding the delete field
            let emoji = item.emoji ?? ""

            csvString += "\(id);\(name);\(carbohydrates);\(carbsPP);\(fat);\(fatPP);\(netCarbs);\(netFat);\(netProtein);\(perPiece);\(protein);\(proteinPP);\(count);\(notes);\(lastEdited);\(delete);\(emoji)\n"
        }
        
        return csvString
    }
    
    private func createCSV(from favoriteMeals: [FavoriteMeals]) -> String {
        var csvString = "id;name;lastEdited;delete;items\n"
        
        let dateFormatter = ISO8601DateFormatter()  // Using ISO 8601 format for dates
        
        for meal in favoriteMeals {
            let id = meal.id?.uuidString ?? ""
            let name = meal.name ?? ""
            let lastEdited = dateFormatter.string(from: meal.lastEdited ?? Date())  // Format lastEdited date
            let deleteFlag = meal.delete ? "true" : "false"  // Convert delete flag to string
            let itemsString = meal.items as? String ?? ""
            
            csvString += "\(id);\(name);\(lastEdited);\(deleteFlag);\(itemsString)\n"
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
        var csvString = "id;mealDate;totalNetCarbs;totalNetFat;totalNetProtein;totalNetBolus;delete;foodEntries\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Use the same format for export and import
        
        for mealHistory in mealHistories {
            let id = mealHistory.id?.uuidString ?? ""
            let mealDate = mealHistory.mealDate.map { dateFormatter.string(from: $0) } ?? ""
            let totalNetCarbs = mealHistory.totalNetCarbs
            let totalNetFat = mealHistory.totalNetFat
            let totalNetProtein = mealHistory.totalNetProtein
            let totalNetBolus = mealHistory.totalNetBolus
            let deleteFlag = mealHistory.delete ? "true" : "false" // Convert delete boolean to string
            
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
            
            csvString += "\(id);\(mealDate);\(totalNetCarbs);\(totalNetFat);\(totalNetProtein);\(totalNetBolus);\(deleteFlag);\(foodEntries)\n"
        }
        
        return csvString
    }
    
    ///Importing and parsing
    @objc public func importCSV(for entityName: String) async {
        if viewHasAppeared {
            await presentDocumentPicker(for: entityName)
        } else {
            pendingImportEntityName = entityName
        }
    }
    
    private func presentDocumentPicker(for entityName: String) async {
        print("Presenting document picker for entity: \(entityName)")
        DispatchQueue.main.async {
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText], asCopy: true)
            documentPicker.delegate = self
            documentPicker.accessibilityHint = entityName
            self.present(documentPicker, animated: true, completion: {
                print("Document picker presented for entity: \(entityName)")
            })
        }
    }
    
    // Parsing CSV files
    public func parseCSV(at url: URL, for entityName: String) async {
        print("Starting CSV parsing for entity: \(entityName) at URL: \(url)")
        do {
            let csvData = try String(contentsOf: url, encoding: .utf8)
            print("CSV data successfully read.")
            let rows = csvData.components(separatedBy: "\n").filter { !$0.isEmpty }
            print("CSV data split into \(rows.count) rows.")
            
            let context = CoreDataStack.shared.context
            
            switch entityName {
            case "Food Items":
                print("Parsing CSV for Food Items.")
                await parseFoodItemsCSV(rows, context: context)
            case "Favorite Meals":
                print("Parsing CSV for Favorite Meals.")
                await parseFavoriteMealsCSV(rows, context: context)
            case "Carb Ratio Schedule":
                print("Parsing CSV for Carb Ratio Schedule.")
                await parseCarbRatioScheduleCSV(rows, context: context)
            case "Start Dose Schedule":
                print("Parsing CSV for Start Dose Schedule.")
                await parseStartDoseScheduleCSV(rows, context: context)
            case "Meal History":
                print("Parsing CSV for Meal History.")
                await parseMealHistoryCSV(rows, context: context)
            case "Ongoing Meal":
                print("Parsing CSV for Ongoing Meal.")
                let importedRows = parseOngoingMealCSV(rows)
                NotificationCenter.default.post(name: .didImportOngoingMeal, object: nil, userInfo: ["foodItemRows": importedRows])
            default:
                print("Unknown entity name: \(entityName)")
                return
            }
            
            try context.save()
            print("Import successful: \(entityName) has been imported and context saved.")
        } catch {
            print("Failed to read CSV file for entity \(entityName): \(error)")
        }
    }

    
    // Parse Food Items CSV
    public func parseFoodItemsCSV(_ rows: [String], context: NSManagedObjectContext) async {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 17 else {  // Ensure the count is 17 to include the delete flag
            print("Import Failed: CSV file was not correctly formatted")
            return
        }
        
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        let existingFoodItems = try? context.fetch(fetchRequest)
        let existingFoodItemsDict = Dictionary(uniqueKeysWithValues: existingFoodItems?.compactMap { ($0.id, $0) } ?? [])
        
        // Date formatter for parsing dates from CSV
        let dateFormatter = ISO8601DateFormatter()
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 17,  // Ensure the row has 17 columns
               let id = UUID(uuidString: values[0]),
               !values.dropFirst().allSatisfy({ $0.isEmpty || $0 == "0" }) { // Ensure no blank or all-zero rows
                
                // Check if the delete flag is set
                let deleteFlag = (values[15] as NSString).boolValue
                
                if deleteFlag {
                    // If delete flag is true, remove the item from Core Data if it exists
                    if let existingItem = existingFoodItemsDict[id] {
                        context.delete(existingItem)
                        print("Deleted food item with id \(id) from Core Data.")
                    }
                    continue
                }
                
                // Retrieve existing food item if available
                let existingItem = existingFoodItemsDict[id]
                
                // Access the lastEdited date string directly
                let lastEditedString = values[14]
                
                // Parse the lastEdited date from the CSV row
                if let newLastEditedDate = dateFormatter.date(from: lastEditedString) {
                    if let existingLastEdited = existingItem?.lastEdited,
                       existingLastEdited >= newLastEditedDate {
                        // Skip if existing item is more recent or same as the one being imported
                        continue
                    }
                    
                    // Update or create a new FoodItem
                    let foodItem = existingItem ?? FoodItem(context: context)
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
                    foodItem.lastEdited = newLastEditedDate
                    foodItem.delete = deleteFlag  // Set the delete flag
                    foodItem.emoji = values[16]
                } else {
                    // If there's no valid lastEdited date in the CSV, handle the fallback case here
                    let foodItem = existingItem ?? FoodItem(context: context)
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
                    foodItem.lastEdited = Date()  // Set lastEdited to current date if no valid date is provided
                    foodItem.delete = deleteFlag  // Set the delete flag
                    foodItem.emoji = values[16]
                }
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save food items: \(error)")
        }
    }
    
    // Parse Favorite Meals CSV
    public func parseFavoriteMealsCSV(_ rows: [String], context: NSManagedObjectContext) async {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 5 else { // Updated to 5 columns: id, name, lastEdited, delete, items
            print("Import Failed: CSV file was not correctly formatted")
            return
        }

        let fetchRequest: NSFetchRequest<FavoriteMeals> = FavoriteMeals.fetchRequest()
        let existingFavoriteMeals = try? context.fetch(fetchRequest)
        let existingFavoriteMealsDict = Dictionary(uniqueKeysWithValues: existingFavoriteMeals?.compactMap { ($0.id, $0) } ?? [])

        // Date formatter for parsing dates from CSV
        let dateFormatter = ISO8601DateFormatter()

        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 5, // Check for 5 columns
               !values.allSatisfy({ $0.isEmpty || $0 == "0" }) { // Ensure no blank or all-zero rows
                if let id = UUID(uuidString: values[0]) {
                    
                    // Retrieve existing favorite meal if available
                    let existingItem = existingFavoriteMealsDict[id]
                    
                    // Check the delete flag
                    let deleteFlag = (values[3] as NSString).boolValue
                    
                    if deleteFlag {
                        // If delete flag is true, remove the item from Core Data if it exists
                        if let existingMeal = existingItem {
                            context.delete(existingMeal)
                            print("Deleted favorite meal with id \(id) from Core Data.")
                        }
                        continue
                    }
                    
                    // Access the lastEdited date string directly
                    let lastEditedString = values[2]
                    
                    // Parse the lastEdited date from the CSV row
                    if let newLastEditedDate = dateFormatter.date(from: lastEditedString) {
                        if let existingLastEdited = existingItem?.lastEdited,
                           existingLastEdited >= newLastEditedDate {
                            // Skip if existing item is more recent or same as the one being imported
                            continue
                        }
                        
                        // Update or create a new FavoriteMeals
                        let favoriteMeal = existingItem ?? FavoriteMeals(context: context)
                        favoriteMeal.id = id
                        favoriteMeal.name = values[1]
                        favoriteMeal.lastEdited = newLastEditedDate
                        favoriteMeal.delete = deleteFlag // Set the delete flag
                        favoriteMeal.items = values[4] as NSObject
                    } else {
                        // If there's no valid lastEdited date in the CSV, handle the fallback case here
                        let favoriteMeal = existingItem ?? FavoriteMeals(context: context)
                        favoriteMeal.id = id
                        favoriteMeal.name = values[1]
                        favoriteMeal.items = values[4] as NSObject
                        
                        // Use values[2] as the fallback lastEdited date if possible
                        if let fallbackLastEditedDate = dateFormatter.date(from: lastEditedString) {
                            favoriteMeal.lastEdited = fallbackLastEditedDate
                        } else {
                            // Set lastEdited to current date if no valid date is provided
                            favoriteMeal.lastEdited = Date()
                        }
                        favoriteMeal.delete = deleteFlag // Set the delete flag
                    }
                }
            }
        }

        do {
            try context.save()
        } catch {
            print("Save Failed: Failed to save favorite meals: \(error)")
        }
    }
    
    // Parse Carb Ratio Schedule CSV
    public func parseCarbRatioScheduleCSV(_ rows: [String], context: NSManagedObjectContext) async {
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
            print("Save Failed: Failed to save Carb Ratio Schedules: \(error)")
        }
    }
    // Parse Start Dose Schedule CSV
    public func parseStartDoseScheduleCSV(_ rows: [String], context: NSManagedObjectContext) async {
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
    
    // Parse Meal History CSV
    public func parseMealHistoryCSV(_ rows: [String], context: NSManagedObjectContext) async {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 8 else { // Updated to 8 columns: id, mealDate, totalNetCarbs, totalNetFat, totalNetProtein, totalNetBolus, delete, foodEntries
            print("Import Failed: CSV file was not correctly formatted")
            return
        }
        
        let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
        do {
            let existingMealHistories = try context.fetch(fetchRequest)
            let existingMealHistoriesDict = Dictionary(uniqueKeysWithValues: existingMealHistories.compactMap { ($0.id, $0) })
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Use the same format for export and import
            
            for row in rows[1...] {
                let values = row.components(separatedBy: ";")
                if values.count == 8, // Check for 8 columns
                   !values.allSatisfy({ $0.isEmpty || $0 == "0" }) { // Ensure no blank or all-zero rows
                    if let id = UUID(uuidString: values[0]) {
                        
                        // Retrieve existing meal history if available
                        if let existingItem = existingMealHistoriesDict[id] {
                            // Check if the delete flag is set to true
                            if values[6] == "true" {
                                // If delete is true, remove the existing meal history
                                context.delete(existingItem)
                                continue // Skip further processing for this item
                            }
                            
                            // Parse the lastEdited date from the CSV row
                            let lastEditedString = values[1]
                            if let newMealDate = dateFormatter.date(from: lastEditedString) {
                                if let existingMealDate = existingItem.mealDate, existingMealDate >= newMealDate {
                                    // Skip if existing item is more recent or same as the one being imported
                                    continue
                                }
                                
                                // Update existing meal history
                                existingItem.mealDate = newMealDate
                                existingItem.totalNetCarbs = Double(values[2]) ?? 0.0
                                existingItem.totalNetFat = Double(values[3]) ?? 0.0
                                existingItem.totalNetProtein = Double(values[4]) ?? 0.0
                                existingItem.totalNetBolus = Double(values[5]) ?? 0.0
                                existingItem.delete = false // Reset delete flag if updating
                                
                                // Update food entries
                                existingItem.removeFromFoodEntries(existingItem.foodEntries ?? NSSet())
                                let foodEntriesValues = values[7].components(separatedBy: "|")
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
                                        existingItem.addToFoodEntries(foodEntry)
                                    }
                                }
                            }
                        } else {
                            // Create a new meal history if not found
                            let mealHistory = MealHistory(context: context)
                            mealHistory.id = id
                            mealHistory.mealDate = dateFormatter.date(from: values[1])
                            mealHistory.totalNetCarbs = Double(values[2]) ?? 0.0
                            mealHistory.totalNetFat = Double(values[3]) ?? 0.0
                            mealHistory.totalNetProtein = Double(values[4]) ?? 0.0
                            mealHistory.totalNetBolus = Double(values[5]) ?? 0.0
                            mealHistory.delete = values[6] == "true" // Set the delete flag
                            
                            // If delete is true, remove it from Core Data
                            if mealHistory.delete {
                                context.delete(mealHistory)
                                continue
                            }
                            
                            // Parse food entries
                            let foodEntriesValues = values[7].components(separatedBy: "|")
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
            }
            try context.save()
        } catch {
            print("Import Failed: Error fetching or saving data: \(error)")
        }
    }
    
    private func parseOngoingMealCSV(_ rows: [String]) -> [FoodItemRowData] {
        var foodItemRows = [FoodItemRowData]()
        
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 7 else {
            print("Import Failed: CSV file was not correctly formatted")
            return []
        }
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 7 {
                let foodItemRow = FoodItemRowData(
                    foodItemID: UUID(uuidString: values[0]),
                    portionServed: Double(values[1]) ?? 0.0,
                    notEaten: Double(values[2]) ?? 0.0,
                    registeredCarbsSoFar: Double(values[3]) ?? 0.0,
                    registeredFatSoFar: Double(values[4]) ?? 0.0,
                    registeredProteinSoFar: Double(values[5]) ?? 0.0,
                    registeredBolusSoFar: Double(values[6]) ?? 0.0
                )
                foodItemRows.append(foodItemRow)
            } else {
                print("Import Failed: Row was not correctly formatted: \(row)")
            }
        }
        
        return foodItemRows
    }
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    ///Userdefaults export, import and parsing
    @objc private func exportUserDefaultsToCSV() async {
        var userDefaultsData = [String: String]()

        // Collecting UserDefaults data
        userDefaultsData["twilioSIDString"] = UserDefaultsRepository.twilioSIDString
        userDefaultsData["twilioSecretString"] = UserDefaultsRepository.twilioSecretString
        userDefaultsData["twilioFromNumberString"] = UserDefaultsRepository.twilioFromNumberString
        //userDefaultsData["twilioToNumberString"] = UserDefaultsRepository.twilioToNumberString
        userDefaultsData["remoteSecretCode"] = UserDefaultsRepository.remoteSecretCode

        userDefaultsData["useStartDosePercentage"] = UserDefaultsRepository.useStartDosePercentage.description
        userDefaultsData["startDoseFactor"] = String(UserDefaultsRepository.startDoseFactor)
        userDefaultsData["maxCarbs"] = String(UserDefaultsRepository.maxCarbs)
        userDefaultsData["maxBolus"] = String(UserDefaultsRepository.maxBolus)
        userDefaultsData["lateBreakfastFactor"] = String(UserDefaultsRepository.lateBreakfastFactor)
        userDefaultsData["lateBreakfastOverrideName"] = UserDefaultsRepository.lateBreakfastOverrideName ?? ""

        userDefaultsData["useMmol"] = UserDefaultsRepository.useMmol.description
        userDefaultsData["lateBreakfastStartTime"] = UserDefaultsRepository.lateBreakfastStartTime?.description ?? ""
        userDefaultsData["lateBreakfastFactorUsed"] = UserDefaultsRepository.lateBreakfastFactorUsed
        userDefaultsData["dabasAPISecret"] = UserDefaultsRepository.dabasAPISecret
        userDefaultsData["nightscoutURL"] = UserDefaultsRepository.nightscoutURL ?? ""
        userDefaultsData["nightscoutToken"] = UserDefaultsRepository.nightscoutToken ?? ""

        userDefaultsData["allowSharingOngoingMeals"] = UserDefaultsRepository.allowSharingOngoingMeals.description
        userDefaultsData["allowViewingOngoingMeals"] = UserDefaultsRepository.allowViewingOngoingMeals.description
        userDefaultsData["schoolFoodURL"] = UserDefaultsRepository.schoolFoodURL ?? ""
        userDefaultsData["excludeWords"] = UserDefaultsRepository.excludeWords ?? ""
        userDefaultsData["topUps"] = UserDefaultsRepository.topUps ?? ""

        let csvString = userDefaultsData.map { "\($0.key);\($0.value)" }.joined(separator: "\n")

        // Get the current caregiver name
        let caregiverName = UserDefaultsRepository.caregiverName.replacingOccurrences(of: " ", with: "_")

        // Create a timestamped filename with caregiver name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "UserDefaults_\(caregiverName)_\(timestamp).csv"

        await saveUserDefaultsCSV(data: csvString, fileName: fileName)
        showAlert(title: NSLocalizedString("Export lyckades", comment: "Export lyckades"), message: NSLocalizedString("Användarinställningarna har exporterats.", comment: "Användarinställningarna har exporterats."))
    }

    
    private func parseUserDefaultsCSV(_ rows: [String]) {
        print("Parsing UserDefaults CSV with \(rows.count) rows.")
        for row in rows {
            let values = row.components(separatedBy: ";")
            guard values.count == 2 else {
                print("Skipped row due to incorrect format: \(row)")
                continue
            }
            
            switch values[0] {
            case "twilioSIDString":
                UserDefaultsRepository.twilioSIDString = values[1]
                print("Updated twilioSIDString: \(values[1])")
            case "twilioSecretString":
                UserDefaultsRepository.twilioSecretString = values[1]
                print("Updated twilioSecretString: \(values[1])")
            case "twilioFromNumberString":
                UserDefaultsRepository.twilioFromNumberString = values[1]
                print("Updated twilioFromNumberString: \(values[1])")
            case "remoteSecretCode":
                UserDefaultsRepository.remoteSecretCode = values[1]
                print("Updated remoteSecretCode: \(values[1])")
            case "useStartDosePercentage":
                UserDefaultsRepository.useStartDosePercentage = Bool(values[1]) ?? false
                print("Updated useStartDosePercentage: \(values[1])")
            case "startDoseFactor":
                UserDefaultsRepository.startDoseFactor = Double(values[1]) ?? 0.5
                print("Updated startDoseFactor: \(values[1])")
            case "maxCarbs":
                UserDefaultsRepository.maxCarbs = Double(values[1]) ?? 30.0
                print("Updated maxCarbs: \(values[1])")
            case "maxBolus":
                UserDefaultsRepository.maxBolus = Double(values[1]) ?? 1.0
                print("Updated maxBolus: \(values[1])")
            case "lateBreakfastFactor":
                UserDefaultsRepository.lateBreakfastFactor = Double(values[1]) ?? 1.0
                print("Updated lateBreakfastFactor: \(values[1])")
            case "lateBreakfastOverrideName":
                UserDefaultsRepository.lateBreakfastOverrideName = values[1]
                print("Updated lateBreakfastOverrideName: \(values[1])")
            case "useMmol":
                UserDefaultsRepository.useMmol = Bool(values[1]) ?? false
                print("Updated useMmol: \(values[1])")
            case "lateBreakfastStartTime":
                if let date = ISO8601DateFormatter().date(from: values[1]) {
                    UserDefaultsRepository.lateBreakfastStartTime = date
                    print("Updated lateBreakfastStartTime: \(date)")
                }
            case "lateBreakfastFactorUsed":
                UserDefaultsRepository.lateBreakfastFactorUsed = values[1]
                print("Updated lateBreakfastFactorUsed: \(values[1])")
            case "dabasAPISecret":
                UserDefaultsRepository.dabasAPISecret = values[1]
                print("Updated dabasAPISecret: \(values[1])")
            case "nightscoutURL":
                UserDefaultsRepository.nightscoutURL = values[1]
                print("Updated nightscoutURL: \(values[1])")
            case "nightscoutToken":
                UserDefaultsRepository.nightscoutToken = values[1]
                print("Updated nightscoutToken: \(values[1])")
            case "allowSharingOngoingMeals":
                UserDefaultsRepository.allowSharingOngoingMeals = Bool(values[1]) ?? false
                print("Updated allowSharingOngoingMeals: \(values[1])")
            case "allowViewingOngoingMeals":
                UserDefaultsRepository.allowViewingOngoingMeals = Bool(values[1]) ?? true
                print("Updated allowViewingOngoingMeals: \(values[1])")
            case "schoolFoodURL":
                UserDefaultsRepository.schoolFoodURL = values[1]
                print("Updated schoolFoodURL: \(values[1])")
            case "excludeWords":
                UserDefaultsRepository.excludeWords = values[1]
                print("Updated excludeWords: \(values[1])")
            case "topUps":
                UserDefaultsRepository.topUps = values[1]
                print("Updated topUps: \(values[1])")
            default:
                print("Unknown UserDefaults key: \(values[0]) with value: \(values[1])")
            }
        }
        NotificationCenter.default.post(name: .didImportUserDefaults, object: nil)
        print("UserDefaults import completed and notification posted.")
    }
    
}

// Document Picker Delegate Methods
extension DataSharingViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("Document picker did pick documents at URLs: \(urls)")
        guard let url = urls.first else {
            print("No URL found.")
            return
        }

        // Check if the file is in the app's sandbox; no need for security-scoped resource access
        let isInAppSandbox = url.path.starts(with: NSTemporaryDirectory()) || url.path.starts(with: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path)

        if !isInAppSandbox {
            // Access security-scoped resource only if outside the sandbox
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                processFile(at: url, controller: controller)
            } else {
                print("Failed to access security-scoped resource for URL: \(url)")
                showAlert(title: "Access Error", message: "Unable to access the selected file. Please make sure the file is available and try again.")
            }
        } else {
            // Process the file directly if within the sandbox
            processFile(at: url, controller: controller)
        }
    }

    func processFile(at url: URL, controller: UIDocumentPickerViewController) {
        do {
            if let entityName = controller.accessibilityHint {
                print("Starting CSV import for entity: \(entityName)")
                if entityName == "UserDefaults" {
                    let csvData = try String(contentsOf: url, encoding: .utf8)
                    let rows = csvData.components(separatedBy: "\n").filter { !$0.isEmpty }
                    print("Parsing UserDefaults CSV with \(rows.count) rows.")
                    parseUserDefaultsCSV(rows)
                    showAlert(title: NSLocalizedString("Import lyckades", comment: "Import lyckades"), message: NSLocalizedString("Användarinställningarna har importerats.", comment: "Användarinställningarna har importerats."))
                } else {
                    Task { await parseCSV(at: url, for: entityName) }
                }
            }
        } catch {
            print("Error reading CSV file: \(error.localizedDescription)")
            showAlert(title: "File Error", message: "Unable to read the selected file. Please ensure it is in the correct format and try again.")
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Document picker was cancelled.")
        controller.dismiss(animated: true, completion: nil)
    }
}

extension DataSharingViewController {
    func exportOngoingMealToCSV() async {
        guard let composeMealVC = ComposeMealViewController.current else {
            print("Error: ComposeMealViewController is not available")
            return
        }
        let foodItemRows = composeMealVC.exportFoodItemRows()
        await exportToCSV(rows: foodItemRows, fileName: "OngoingMeal.csv", createCSV: createOngoingMealCSV(from:))
    }
    
    private func exportToCSV(rows: [FoodItemRowData], fileName: String, createCSV: ([FoodItemRowData]) -> String) async {
        let csvData = createCSV(rows)
        await saveCSV(data: csvData, fileName: fileName)
        print("\(fileName) export done")
    }
    
    private func createOngoingMealCSV(from foodItemRows: [FoodItemRowData]) -> String {
        var csvString = "foodItemID;portionServed;notEaten;registeredCarbsSoFar;registeredFatSoFar;registeredProteinSoFar;registeredBolusSoFar\n"
        
        for row in foodItemRows {
            let foodItemID = row.foodItemID?.uuidString ?? ""
            let portionServed = row.portionServed
            let notEaten = row.notEaten
            let registeredCarbsSoFar = row.registeredCarbsSoFar
            let registeredFatSoFar = row.registeredFatSoFar
            let registeredProteinSoFar = row.registeredProteinSoFar
            let registeredBolusSoFar = row.registeredBolusSoFar
            
            csvString += "\(foodItemID);\(portionServed);\(notEaten);\(registeredCarbsSoFar);\(registeredFatSoFar);\(registeredProteinSoFar);\(registeredBolusSoFar)\n"
        }
        
        return csvString
    }
    
    public func saveCSV(data: String, fileName: String) async {
            let tempDirectory = NSURL(fileURLWithPath: NSTemporaryDirectory())
            let tempFilePath = tempDirectory.appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempFilePath!, atomically: true, encoding: .utf8)
                
                let fileManager = FileManager.default
                let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/NewCarbsCounter")
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
    public func saveUserDefaultsCSV(data: String, fileName: String) async {
            let tempDirectory = NSURL(fileURLWithPath: NSTemporaryDirectory())
            let tempFilePath = tempDirectory.appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempFilePath!, atomically: true, encoding: .utf8)
                
                let fileManager = FileManager.default
                let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent(NSLocalizedString("Documents/NewCarbsCounter/Användarinställningar", comment: "Documents/NewCarbsCounter/Användarinställningar"))
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
}

extension Notification.Name {
    static let didImportOngoingMeal = Notification.Name("didImportOngoingMeal")
    static let didImportUserDefaults = Notification.Name("didImportUserDefaults")
    static let didAcceptShare = Notification.Name("didAcceptShare")
    static let dataDidChangeRemotely = Notification.Name("dataDidChangeRemotely")
}

