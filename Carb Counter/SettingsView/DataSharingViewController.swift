// Daniel: 800+ lines - To be cleaned
import UIKit
import CloudKit
import CoreData
import UniformTypeIdentifiers

class DataSharingViewController: UITableViewController {
    
    private var lastImportTime: Date?
    private var viewHasAppeared = false
    private var pendingImportEntityName: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Dela data", comment: "Share Data")
        
        setupBackground()
        
        // Register cell style
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "dataCell")
        
        // Add Done button to the navigation bar
        let doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Klar"), style: .done, target: self, action: #selector(doneButtonTapped))
        navigationItem.rightBarButtonItem = doneButton
    }
    
    @objc private func doneButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupBackground() {
            // Create a solid background for light mode and a gradient for dark mode
            let backgroundContainerView = UIView()
            let solidBackgroundView = UIView()
            solidBackgroundView.translatesAutoresizingMaskIntoConstraints = false
            backgroundContainerView.addSubview(solidBackgroundView)
            
            if traitCollection.userInterfaceStyle == .dark {
                solidBackgroundView.backgroundColor = .systemBackground
                
                // Set up gradient
                let colors: [CGColor] = [
                    UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
                    UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
                    UIColor.systemBlue.withAlphaComponent(0.15).cgColor
                ]
                let gradientView = GradientView(colors: colors)
                gradientView.translatesAutoresizingMaskIntoConstraints = false
                backgroundContainerView.addSubview(gradientView)
                
                NSLayoutConstraint.activate([
                    gradientView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
                    gradientView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
                    gradientView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
                    gradientView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
                ])
            } else {
                solidBackgroundView.backgroundColor = .systemGray6
            }

            // Set the container view as the table's background view
            tableView.backgroundView = backgroundContainerView

            NSLayoutConstraint.activate([
                solidBackgroundView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
                solidBackgroundView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
                solidBackgroundView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
                solidBackgroundView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
            ])
        }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1  // All settings are in a single section
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5  // Toggle Sharing, Export, Import, Clear History, NS sync
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "dataCell")
        cell.backgroundColor = .clear

        // Create a horizontal stack view for aligning label and icon/switch
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Label for row text
        let label = UILabel()
        label.font = .systemFont(ofSize: 17)
        label.textColor = .label

        // Configure cell content based on row
        switch indexPath.row {
        case 0:
            label.text = NSLocalizedString("Tillåt delning av pågående måltid", comment: "Allow ongoing meal sharing")
            let toggleSwitch = UISwitch()
            toggleSwitch.isOn = UserDefaultsRepository.allowSharingOngoingMeals
            toggleSwitch.addTarget(self, action: #selector(toggleOngoingMealSharing(_:)), for: .valueChanged)
            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(toggleSwitch)

        case 1:
            label.text = NSLocalizedString("Exportera data", comment: "Export data")
            let exportIcon = UIImageView(image: UIImage(systemName: "square.and.arrow.up"))
            exportIcon.tintColor = .label
            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(exportIcon)

        case 2:
            label.text = NSLocalizedString("Importera data", comment: "Import data")
            let importIcon = UIImageView(image: UIImage(systemName: "square.and.arrow.down"))
            importIcon.tintColor = .label
            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(importIcon)

        case 3:
            label.text = NSLocalizedString("Rensa gammal måltidshistorik", comment: "Clear old meal history")
            let trashIcon = UIImageView(image: UIImage(systemName: "trash"))
            trashIcon.tintColor = .red
            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(trashIcon)

        case 4: // New row
            label.text = NSLocalizedString("Synka Nightscout profildata", comment: "Sync with Nightscout")
            let syncIcon = UIImageView(image: UIImage(systemName: "arrow.triangle.2.circlepath.icloud"))
            syncIcon.tintColor = .label
            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(syncIcon)

        default:
            break
        }

        // Add stack view to cell content
        cell.contentView.addSubview(stackView)

        // Set up constraints for stack view to fit within cell
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10)
        ])

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.row {
        case 1:
            exportData()
        case 2:
            importData()
        case 3:
            clearHistoryTapped()
        case 4:
            syncWithNightscout()
        default:
            break
        }
    }
    
    private func syncWithNightscout() {
        NotificationCenter.default.post(name: Notification.Name("SyncWithNightscout"), object: nil)
    }
    
    /*
     private func setupDarkModeBackground() {
     view.backgroundColor = .systemBackground
     let colors: [CGColor] = [
     UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
     UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
     UIColor.systemBlue.withAlphaComponent(0.15).cgColor
     ]
     let gradientView = GradientView(colors: colors)
     gradientView.translatesAutoresizingMaskIntoConstraints = false
     view.addSubview(gradientView)
     view.sendSubviewToBack(gradientView)
     
     NSLayoutConstraint.activate([
     gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
     gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
     gradientView.topAnchor.constraint(equalTo: view.topAnchor),
     gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
     ])
     }*/
    /*
     private func setupNavigationBarButtons() {
     let exportButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportData))
     let importButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importData))
     navigationItem.rightBarButtonItems = [exportButton, importButton]
     }*/
    /*
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
     
     private func setupClearHistoryRow() {
     let clearHistoryContainer = UIView()
     clearHistoryContainer.translatesAutoresizingMaskIntoConstraints = false
     view.addSubview(clearHistoryContainer)
     
     let clearHistoryLabel = UILabel()
     clearHistoryLabel.text = NSLocalizedString("Rensa gammal måltidshistorik", comment: "Clear history over 365 days")
     clearHistoryLabel.translatesAutoresizingMaskIntoConstraints = false
     
     let trashIcon = UIImageView(image: UIImage(systemName: "trash"))
     trashIcon.tintColor = .red
     trashIcon.translatesAutoresizingMaskIntoConstraints = false
     
     clearHistoryContainer.addSubview(clearHistoryLabel)
     clearHistoryContainer.addSubview(trashIcon)
     
     NSLayoutConstraint.activate([
     clearHistoryContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
     clearHistoryContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
     clearHistoryContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
     clearHistoryContainer.heightAnchor.constraint(equalToConstant: 44),  // Define a height for the container
     
     clearHistoryLabel.leadingAnchor.constraint(equalTo: clearHistoryContainer.leadingAnchor),
     clearHistoryLabel.centerYAnchor.constraint(equalTo: clearHistoryContainer.centerYAnchor),
     
     trashIcon.trailingAnchor.constraint(equalTo: clearHistoryContainer.trailingAnchor),
     trashIcon.centerYAnchor.constraint(equalTo: clearHistoryContainer.centerYAnchor)
     ])
     
     // Make the container tappable
     let tapGesture = UITapGestureRecognizer(target: self, action: #selector(clearHistoryTapped))
     clearHistoryContainer.addGestureRecognizer(tapGesture)
     clearHistoryContainer.isUserInteractionEnabled = true  // Ensure interaction is enabled
     }
     */
    @objc private func toggleOngoingMealSharing(_ sender: UISwitch) {
        UserDefaultsRepository.allowSharingOngoingMeals = sender.isOn
        print("allowSharingOngoingMeals set to \(sender.isOn)")
    }
    
    @objc private func clearHistoryTapped() {
        let alert = UIAlertController(
            title: NSLocalizedString("⚠️ Rensa måltidshistorik", comment: "Clear meal history"),
            message: NSLocalizedString("\nVill du radera all måltidshistorik äldre än 365 dagar?", comment: "Delete all meal history older than 365 days"),
            preferredStyle: .alert
        )
        
        let deleteAction = UIAlertAction(title: NSLocalizedString("Radera", comment: "Delete"), style: .destructive) { _ in
            CoreDataHelper.shared.clearOldMealHistory()
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel"), style: .cancel)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
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
        let alert = UIAlertController(title: NSLocalizedString("Importera data", comment: "Importera data"), message: NSLocalizedString("Välj vilken data du vill importera", comment: "Välj vilken data du vill importera"), preferredStyle: .actionSheet)
        
        // Automatic import for all CSV files
        alert.addAction(UIAlertAction(title: NSLocalizedString("Importera hela databasen", comment: "Importera hela databasen"), style: .default, handler: { _ in
            Task { await self.importCSVFiles() }
        }))
        
        // Present document picker for specific CSV imports
        alert.addAction(UIAlertAction(title: NSLocalizedString("Livsmedel", comment: "Livsmedel"), style: .default, handler: { _ in
            Task { await self.presentDocumentPicker(for: "Food Items") }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Favoritmåltider", comment: "Favoritmåltider"), style: .default, handler: { _ in
            Task { await self.presentDocumentPicker(for: "Favorite Meals") }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Måltidshistorik", comment: "Måltidshistorik"), style: .default, handler: { _ in
            Task { await self.presentDocumentPicker(for: "Meal History") }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("AI Måltidslogg", comment: "AI Måltidslogg"), style: .default, handler: { _ in
            Task { await self.presentDocumentPicker(for: "AI Meal Log") }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Carb ratios schema", comment: "Carb ratios schema"), style: .default, handler: { _ in
            Task { await self.presentDocumentPicker(for: "Carb Ratio Schedule") }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Startdoser schema", comment: "Startdoser schema"), style: .default, handler: { _ in
            Task { await self.presentDocumentPicker(for: "Start Dose Schedule") }
        }))
        
        // New option for importing user settings
        alert.addAction(UIAlertAction(title: NSLocalizedString("Användarinställningar", comment: "Användarinställningar"), style: .default, handler: { _ in
            Task { await self.importUserDefaultsFromCSV() }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel))
        
        present(alert, animated: true, completion: nil)
    }
    
    
    @objc private func exportAllCSVFiles() async {
        await exportCarbRatioScheduleToCSV()
        await exportFavoriteMealsToCSV()
        await exportFoodItemsToCSV()
        await exportMealHistoryToCSV()
        await exportAIMealLogToCSV()
        await exportStartDoseScheduleToCSV()
        
        showAlert(title: "Export Successful", message: "All data has been exported successfully.")
    }
    
    ///Manual and automatic importing
    @objc public func importCSVFiles(specificFileName: String? = nil) async {
        await self.performImportCSVFiles(specificFileName: specificFileName)
    }
    
    private func performImportCSVFiles(specificFileName: String? = nil) async {
        var updateView: UpdateView?
        
        // Apply the 300-second block only if no specific file is provided (i.e., all files are imported)
        if specificFileName == nil {
            if let lastImportTime = lastImportTime, Date().timeIntervalSince(lastImportTime) < 300 {
                print("Import blocked to prevent running more often than every 5 minutes")
                return
            }
            
            // Update the last import time when importing all files
            lastImportTime = Date()
            
            // Create and display the UpdateView if no specific file is provided and the import proceeds
            updateView = UpdateView()
            if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                updateView?.showInView(keyWindow)
            }
        }
        
        let fileManager = FileManager.default
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/CarbsCounter") else {
            print("Import Failed: iCloud Drive URL is nil.")
            // Hide UpdateView in case of failure
            if let updateView = updateView {
                await hideUpdateView(updateView)
            }
            return
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: iCloudURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            let entityFileMapping: [String: String] = [
                "FoodItems.csv": "Food Items",
                "FavoriteMeals.csv": "Favorite Meals",
                "MealHistory.csv": "Meal History",
                "AIMealLog.csv" : "AI Meal Log",
                "CarbRatioSchedule.csv": "Carb Ratio Schedule",
                "StartDoseSchedule.csv": "Start Dose Schedule"
            ]
            
            // If specificFileName is provided, filter the mapping to import just that file
            let filesToImport = specificFileName != nil ?
            entityFileMapping.filter { $0.key == specificFileName } :
            entityFileMapping
            
            for (fileName, entityName) in filesToImport {
                if let fileURL = fileURLs.first(where: { $0.lastPathComponent == fileName }) {
                    await parseCSV(at: fileURL, for: entityName)
                } else if specificFileName != nil {
                    print("File \(specificFileName!) not found.")
                }
            }
            
            print("Data import done!")
            
        } catch {
            print("Failed to list directory: \(error)")
        }
        
        // Hide UpdateView once import is done
        if let updateView = updateView {
            await hideUpdateView(updateView)
        }
    }
    
    private func hideUpdateView(_ updateView: UpdateView) async {
        await MainActor.run {
            updateView.hide()
        }
    }
    
    
    ///Ongoing meal import
    @objc public func importOngoingMealCSV() {
        // Initialize and display the UpdateView
        let updateView = UpdateView()
        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            updateView.showInView(keyWindow)
        }
        
        let fileManager = FileManager.default
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/CarbsCounter/OngoingMeal.csv") else {
            print("Import Failed: iCloud Drive URL is nil.")
            // Hide UpdateView immediately in case of failure
            updateView.hide()
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
        
        // Hide UpdateView once import is done
        updateView.hide()
    }
    ///Exporting
    @objc public func exportFoodItemsToCSV() async {
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        await exportToCSV(fetchRequest: fetchRequest, fileName: "FoodItems.csv", createCSV: createCSV(from:))
    }
    
    @objc public func exportFavoriteMealsToCSV() async {
        let fetchRequest: NSFetchRequest<NewFavoriteMeals> = NewFavoriteMeals.fetchRequest()
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
    
    @objc public func exportAIMealLogToCSV() async {
        let fetchRequest: NSFetchRequest<AIMeal> = AIMeal.fetchRequest()
        await exportToCSV(fetchRequest: fetchRequest, fileName: "AIMealLog.csv", createCSV: createCSV(from:))
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
    private func createCSV(from favoriteMeals: [NewFavoriteMeals]) -> String {
        var csvString = "id;name;lastEdited;delete;favoriteEntries\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        for meal in favoriteMeals {
            let id = meal.id?.uuidString ?? ""
            let name = meal.name ?? ""
            let lastEdited = dateFormatter.string(from: meal.lastEdited ?? Date())
            let deleteFlag = meal.delete ? "true" : "false"
            
            let favoriteEntries = (meal.favoriteEntries as? Set<FoodItemFavorite>)?.map { entry in
                [
                    cleanString(entry.id?.uuidString ?? ""),
                    cleanString(entry.name ?? ""),
                    entry.portionServed,
                    entry.perPiece ? "1" : "0"
                ].map { "\($0)" }.joined(separator: ",")
            }.joined(separator: "|") ?? ""
            
            csvString += "\(id);\(name);\(lastEdited);\(deleteFlag);\(favoriteEntries)\n"
        }
        
        return csvString
    }
    
    private func createCSV(from aiMeal: [AIMeal]) -> String {
        var csvString = "id;name;totalCarbs;totalFat;totalProtein;totalOriginalWeight;totalAdjustedWeight;mealDate;lastEdited;delete;response\n"
        
        let dateFormatter = ISO8601DateFormatter()  // Using ISO 8601 format for dates
        
        for item in aiMeal {
            let id = item.id?.uuidString ?? ""
            let name = item.name ?? ""
            let totalCarbs = item.totalCarbs
            let totalFat = item.totalFat
            let totalProtein = item.totalProtein
            let totalOriginalWeight = item.totalOriginalWeight
            let totalAdjustedWeight = item.totalAdjustedWeight
            let mealDate = dateFormatter.string(from: item.mealDate ?? Date())
            let lastEdited = dateFormatter.string(from: item.lastEdited ?? Date())
            let delete = item.delete
            let response = escapeForCSV(item.response ?? "")
            
            csvString += "\(id);\(name);\(totalCarbs);\(totalFat);\(totalProtein);\(totalOriginalWeight);\(totalAdjustedWeight);\(mealDate);\(lastEdited);\(delete);\"\(response)\"\n"
        }
        
        return csvString
    }

    private func escapeForCSV(_ field: String) -> String {
        // Escape double quotes by doubling them (standard CSV format)
        return field.replacingOccurrences(of: "\"", with: "\"\"")
    }
    
    private func createCSV(from carbRatioSchedules: [CarbRatioSchedule]) -> String {
        var csvString = "hour;carbRatio;lastEdited\n"
        let dateFormatter = ISO8601DateFormatter()
        
        for schedule in carbRatioSchedules {
            let hour = schedule.hour
            let carbRatio = schedule.carbRatio
            let lastEdited = dateFormatter.string(from: schedule.lastEdited ?? Date())
            
            csvString += "\(hour);\(carbRatio);\(lastEdited)\n"
        }
        return csvString
    }
    
    
    private func createCSV(from startDoseSchedules: [StartDoseSchedule]) -> String {
        var csvString = "hour;startDose;lastEdited\n"
        let dateFormatter = ISO8601DateFormatter()
        
        for schedule in startDoseSchedules {
            let hour = schedule.hour
            let startDose = schedule.startDose
            let lastEdited = dateFormatter.string(from: schedule.lastEdited ?? Date())
            
            csvString += "\(hour);\(startDose);\(lastEdited)\n"
        }
        return csvString
    }
    
    
    private func cleanString(_ input: String) -> String {
        // Remove invisible characters, trim whitespace, and remove commas
        let cleaned = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .controlCharacters)
            .joined()
            .replacingOccurrences(of: ",", with: ".") // Remove commas
        
        return cleaned
    }
    
    private func createCSV(from mealHistories: [MealHistory]) -> String {
        var csvString = "id;mealDate;totalNetCarbs;totalNetFat;totalNetProtein;totalNetBolus;delete;foodEntries;lastEdited\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let lastEditedFormatter = ISO8601DateFormatter() // Use ISO8601 for lastEdited field
        
        // Calculate the date 365 days ago from today
        let calendar = Calendar.current
        guard let date365DaysAgo = calendar.date(byAdding: .day, value: -365, to: Date()) else { return csvString }
        
        for mealHistory in mealHistories {
            // Only include mealHistory entries with mealDate within the last 365 days
            if let mealDate = mealHistory.mealDate, mealDate >= date365DaysAgo {
                let id = mealHistory.id?.uuidString ?? ""
                let formattedMealDate = dateFormatter.string(from: mealDate)
                let totalNetCarbs = mealHistory.totalNetCarbs
                let totalNetFat = mealHistory.totalNetFat
                let totalNetProtein = mealHistory.totalNetProtein
                let totalNetBolus = mealHistory.totalNetBolus
                let deleteFlag = mealHistory.delete ? "true" : "false"
                let lastEdited = lastEditedFormatter.string(from: mealHistory.lastEdited ?? Date())
                
                let foodEntries = (mealHistory.foodEntries as? Set<FoodItemEntry>)?.map { entry in
                    [
                        cleanString(entry.entryId?.uuidString ?? ""),
                        cleanString(entry.entryName ?? ""),
                        entry.entryPortionServed,
                        entry.entryNotEaten,
                        entry.entryCarbohydrates,
                        entry.entryFat,
                        entry.entryProtein,
                        entry.entryPerPiece ? "1" : "0",
                        cleanString(entry.entryEmoji ?? "")
                    ].map { "\($0)" }.joined(separator: ",")
                }.joined(separator: "|") ?? ""
                
                csvString += "\(id);\(formattedMealDate);\(totalNetCarbs);\(totalNetFat);\(totalNetProtein);\(totalNetBolus);\(deleteFlag);\(foodEntries);\(lastEdited)\n"
            }
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
        DispatchQueue.main.async {
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
            documentPicker.delegate = self
            documentPicker.accessibilityHint = entityName
            self.present(documentPicker, animated: true, completion: nil)
        }
    }
    
    // Parsing CSV files
    public func parseCSV(at url: URL, for entityName: String) async {
        do {
            let csvData = try String(contentsOf: url, encoding: .utf8)
            let rows = csvData.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            let context = CoreDataStack.shared.context
            
            switch entityName {
            case "Food Items":
                await parseFoodItemsCSV(rows, context: context)
            case "Favorite Meals":
                await parseFavoriteMealsCSV(rows, context: context)
            case "Carb Ratio Schedule":
                await parseCarbRatioScheduleCSV(rows, context: context)
            case "Start Dose Schedule":
                await parseStartDoseScheduleCSV(rows, context: context)
            case "Meal History":
                await parseMealHistoryCSV(rows, context: context)
            case "AI Meal Log":
                await parseAIMealLogCSV(rows, context: context)
            case "Ongoing Meal":
                let importedRows = parseOngoingMealCSV(rows)
                NotificationCenter.default.post(name: .didImportOngoingMeal, object: nil, userInfo: ["foodItemRows": importedRows])
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
                
                // Retrieve the delete flag from the CSV
                let deleteFlag = (values[15] as NSString).boolValue
                
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
                    foodItem.delete = deleteFlag  // Only mark the item as deleted, do not actually delete
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
                    foodItem.delete = deleteFlag  // Only mark the item as deleted, do not actually delete
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
        guard columns.count == 5 else {
            print("Import Failed: CSV file was not correctly formatted")
            return
        }
        
        let fetchRequest: NSFetchRequest<NewFavoriteMeals> = NewFavoriteMeals.fetchRequest()
        let existingFavoriteMeals = try? context.fetch(fetchRequest)
        let existingFavoriteMealsDict = Dictionary(uniqueKeysWithValues: existingFavoriteMeals?.compactMap { ($0.id, $0) } ?? [])
        
        let dateFormatter = ISO8601DateFormatter()
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 5,
               let id = UUID(uuidString: values[0]) {
                
                let existingMeal = existingFavoriteMealsDict[id]
                let deleteFlag = (values[3] as NSString).boolValue
                let lastEditedString = values[2]
                
                guard let newLastEditedDate = dateFormatter.date(from: lastEditedString) else {
                    print("Invalid lastEdited date format")
                    continue
                }
                
                if let existingLastEdited = existingMeal?.lastEdited, existingLastEdited >= newLastEditedDate {
                    continue
                }
                
                let favoriteMeal = existingMeal ?? NewFavoriteMeals(context: context)
                favoriteMeal.id = id
                favoriteMeal.name = values[1]
                favoriteMeal.lastEdited = newLastEditedDate
                favoriteMeal.delete = deleteFlag
                
                let foodItemStrings = values[4].components(separatedBy: "|")
                favoriteMeal.favoriteEntries = []
                
                for itemString in foodItemStrings {
                    let itemValues = itemString.components(separatedBy: ",")
                    if itemValues.count == 4,
                       let itemId = UUID(uuidString: itemValues[0]),
                       let portionServed = Double(itemValues[2]) {
                        
                        let foodItemFavorite = FoodItemFavorite(context: context)
                        foodItemFavorite.id = itemId
                        foodItemFavorite.name = itemValues[1]
                        foodItemFavorite.portionServed = portionServed
                        foodItemFavorite.perPiece = itemValues[3] == "1"
                        
                        favoriteMeal.addToFavoriteEntries(foodItemFavorite)
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
    
    // Parse AI Meal Log CSV
    public func parseAIMealLogCSV(_ rows: [String], context: NSManagedObjectContext) async {
        guard !rows.isEmpty else {
            print("Import Failed: CSV file is empty")
            return
        }
        
        let headerColumns = rows[0].components(separatedBy: ";")
        guard headerColumns.count == 11 else {  // Ensure the count is 11 to include the delete flag
            print("Import Failed: CSV file was not correctly formatted")
            return
        }
        
        let fetchRequest: NSFetchRequest<AIMeal> = AIMeal.fetchRequest()
        let existingAIMeals = try? context.fetch(fetchRequest)
        let existingAIMealsDict = Dictionary(uniqueKeysWithValues: existingAIMeals?.compactMap { ($0.id, $0) } ?? [])
        
        // Shared date formatter for parsing both mealDate and lastEdited
        let dateFormatter = ISO8601DateFormatter()
        
        for row in rows[1...] {
            let values = parseCSVRow(row)
            if values.count == 11,  // Ensure the row has 11 columns
               let id = UUID(uuidString: values[0]),
               !values.dropFirst().allSatisfy({ $0.isEmpty || $0 == "0" }) { // Ensure no blank or all-zero rows
                
                // Retrieve the delete flag from the CSV
                let deleteFlag = (values[9] as NSString).boolValue
                
                // Retrieve existing food item if available
                let existingItem = existingAIMealsDict[id]
                
                // Parse mealDate and lastEdited
                let mealDateString = values[7]
                let lastEditedString = values[8]
                let parsedMealDate = dateFormatter.date(from: mealDateString)
                let parsedLastEditedDate = dateFormatter.date(from: lastEditedString)
                
                if let newLastEditedDate = parsedLastEditedDate {
                    if let existingLastEdited = existingItem?.lastEdited,
                       existingLastEdited >= newLastEditedDate {
                        // Skip if existing item is more recent or same as the one being imported
                        continue
                    }
                    
                    // Update or create a new AIMeal
                    let aiMeal = existingItem ?? AIMeal(context: context)
                    aiMeal.id = id
                    aiMeal.name = values[1]
                    aiMeal.totalCarbs = Double(values[2]) ?? 0.0
                    aiMeal.totalFat = Double(values[3]) ?? 0.0
                    aiMeal.totalProtein = Double(values[4]) ?? 0.0
                    aiMeal.totalOriginalWeight = Double(values[5]) ?? 0.0
                    aiMeal.totalAdjustedWeight = Double(values[6]) ?? 0.0
                    aiMeal.mealDate = parsedMealDate ?? Date()  // Use current date as fallback if parsing fails
                    aiMeal.lastEdited = newLastEditedDate
                    aiMeal.delete = deleteFlag  // Only mark the item as deleted, do not actually delete
                    aiMeal.response = values[10]
                }
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save AI Meal Log: \(error)")
        }
    }

    private func parseCSVRow(_ row: String) -> [String] {
        var values: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in row {
            if char == "\"" {
                insideQuotes.toggle() // Toggle the insideQuotes flag
            } else if char == ";" && !insideQuotes {
                // End of a field when not inside quotes
                values.append(currentField)
                currentField = ""
            } else {
                // Append character to the current field
                currentField.append(char)
            }
        }
        // Append the last field
        values.append(currentField)
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    // Parse Carb Ratio Schedule CSV
    public func parseCarbRatioScheduleCSV(_ rows: [String], context: NSManagedObjectContext) async {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 3 else {
            print("Import Failed: CSV file was not correctly formatted")
            return
        }
        
        // Fetch existing schedules and create a dictionary for quick lookup
        let fetchRequest: NSFetchRequest<CarbRatioSchedule> = CarbRatioSchedule.fetchRequest()
        let existingSchedules = try? context.fetch(fetchRequest)
        let existingSchedulesDict = Dictionary(uniqueKeysWithValues: existingSchedules?.map { ($0.hour, $0) } ?? [])
        
        let dateFormatter = ISO8601DateFormatter()
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 3,
               let hour = Int16(values[0]),
               let carbRatio = Double(values[1]),
               let lastEdited = dateFormatter.date(from: values[2]),
               hour >= 0, hour < 24 {
                
                let existingSchedule = existingSchedulesDict[hour]
                
                // Check if the current row has a newer lastEdited date than the existing schedule
                if let existingLastEdited = existingSchedule?.lastEdited, existingLastEdited >= lastEdited {
                    continue
                }
                
                // Create a new schedule or update the existing one
                let carbRatioSchedule = existingSchedule ?? CarbRatioSchedule(context: context)
                carbRatioSchedule.hour = hour
                carbRatioSchedule.carbRatio = carbRatio
                carbRatioSchedule.lastEdited = lastEdited
            }
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
        guard columns.count == 3 else {
            print("Import Failed: CSV file was not correctly formatted")
            return
        }
        
        // Fetch existing schedules and create a dictionary for quick lookup
        let fetchRequest: NSFetchRequest<StartDoseSchedule> = StartDoseSchedule.fetchRequest()
        let existingSchedules = try? context.fetch(fetchRequest)
        let existingSchedulesDict = Dictionary(uniqueKeysWithValues: existingSchedules?.map { ($0.hour, $0) } ?? [])
        
        let dateFormatter = ISO8601DateFormatter()
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 3,
               let hour = Int16(values[0]),
               let startDose = Double(values[1]),
               let lastEdited = dateFormatter.date(from: values[2]),
               hour >= 0, hour < 24 {
                
                let existingSchedule = existingSchedulesDict[hour]
                
                // Check if the current row has a newer lastEdited date than the existing schedule
                if let existingLastEdited = existingSchedule?.lastEdited, existingLastEdited >= lastEdited {
                    continue
                }
                
                // Create a new schedule or update the existing one
                let startDoseSchedule = existingSchedule ?? StartDoseSchedule(context: context)
                startDoseSchedule.hour = hour
                startDoseSchedule.startDose = startDose
                startDoseSchedule.lastEdited = lastEdited
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Save Failed: Failed to save Start Dose Schedules: \(error)")
        }
    }
    
    
    // Parse Meal History CSV
    private func cleanCSVValue(_ value: String) -> String {
        // Clean up each value by trimming and removing control characters
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .controlCharacters)
            .joined()
    }
    
    public func parseMealHistoryCSV(_ rows: [String], context: NSManagedObjectContext) async {
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 9 else { // Updated count to 9 to include lastEdited
            print("Import Failed: CSV file was not correctly formatted")
            return
        }
        
        let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
        do {
            let existingMealHistories = try context.fetch(fetchRequest)
            let existingMealHistoriesDict = Dictionary(uniqueKeysWithValues: existingMealHistories.compactMap { ($0.id, $0) })
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            let lastEditedFormatter = ISO8601DateFormatter() // Use ISO8601 for lastEdited field
            
            for row in rows[1...] {
                let values = row.components(separatedBy: ";").map(cleanCSVValue)
                if values.count == 9, // Updated count to 9
                   !values.allSatisfy({ $0.isEmpty || $0 == "0" }) {
                    
                    if let id = UUID(uuidString: values[0]) {
                        let existingItem = existingMealHistoriesDict[id]
                        
                        let mealDateString = values[1]
                        let lastEditedString = values[8] // Get lastEdited value from CSV
                        
                        guard let newMealDate = dateFormatter.date(from: mealDateString),
                              let newLastEditedDate = lastEditedFormatter.date(from: lastEditedString) else {
                            print("Invalid date format in CSV")
                            continue
                        }
                        
                        // Determine if we should replace the existing item based on lastEdited dates
                        if let existingLastEdited = existingItem?.lastEdited {
                            // Skip updating if the existing item's lastEdited date is newer
                            if existingLastEdited >= newLastEditedDate {
                                continue
                            }
                        } else if existingItem != nil && existingItem?.lastEdited == nil {
                            // Allow update if the existing item has no lastEdited date but CSV item does
                            existingItem?.lastEdited = newLastEditedDate
                        }
                        
                        let deleteFlag = values[6] == "true"
                        let mealHistory = existingItem ?? MealHistory(context: context)
                        
                        // Assign the parsed values to the mealHistory
                        mealHistory.id = id
                        mealHistory.mealDate = newMealDate
                        mealHistory.lastEdited = newLastEditedDate // Set the new lastEdited date
                        mealHistory.totalNetCarbs = Double(values[2]) ?? 0.0
                        mealHistory.totalNetFat = Double(values[3]) ?? 0.0
                        mealHistory.totalNetProtein = Double(values[4]) ?? 0.0
                        mealHistory.totalNetBolus = Double(values[5]) ?? 0.0
                        mealHistory.delete = deleteFlag
                        
                        // Remove existing food entries if updating
                        if let existingItem = existingItem {
                            existingItem.removeFromFoodEntries(existingItem.foodEntries ?? NSSet())
                        }
                        
                        // Parse food entries from CSV
                        let foodEntriesValues = values[7].components(separatedBy: "|")
                        for foodEntryValue in foodEntriesValues {
                            let foodEntryParts = foodEntryValue.components(separatedBy: ",").map(cleanCSVValue)
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
            
            // Save the context after parsing
            try context.save()
        } catch {
            print("Import Failed: Error fetching or saving data: \(error)")
        }
    }
    
    private func parseOngoingMealCSV(_ rows: [String]) -> [FoodItemRowData] {
        var foodItemRows = [FoodItemRowData]()
        
        let columns = rows[0].components(separatedBy: ";")
        guard columns.count == 8 else {
            print("Import Failed: CSV file was not correctly formatted")
            return []
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for row in rows[1...] {
            let values = row.components(separatedBy: ";")
            if values.count == 8 {
                let mealDate = dateFormatter.date(from: values[7])
                
                let foodItemRow = FoodItemRowData(
                    foodItemID: UUID(uuidString: values[0]),
                    portionServed: Double(values[1]) ?? 0.0,
                    notEaten: Double(values[2]) ?? 0.0,
                    registeredCarbsSoFar: Double(values[3]) ?? 0.0,
                    registeredFatSoFar: Double(values[4]) ?? 0.0,
                    registeredProteinSoFar: Double(values[5]) ?? 0.0,
                    registeredBolusSoFar: Double(values[6]) ?? 0.0,
                    mealDate: mealDate
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
        userDefaultsData["remoteSecretCode"] = UserDefaultsRepository.remoteSecretCode
        
        userDefaultsData["useStartDosePercentage"] = UserDefaultsRepository.useStartDosePercentage.description
        userDefaultsData["startDoseFactor"] = String(UserDefaultsRepository.startDoseFactor)
        userDefaultsData["maxCarbs"] = String(UserDefaultsRepository.maxCarbs)
        userDefaultsData["maxBolus"] = String(UserDefaultsRepository.maxBolus)
        userDefaultsData["overrideFactor"] = String(UserDefaultsRepository.overrideFactor)
        userDefaultsData["overrideName"] = UserDefaultsRepository.overrideName ?? ""
        
        userDefaultsData["useMmol"] = UserDefaultsRepository.useMmol.description
        userDefaultsData["overrideStartTime"] = UserDefaultsRepository.overrideStartTime?.description ?? ""
        userDefaultsData["overrideFactorUsed"] = UserDefaultsRepository.overrideFactorUsed
        userDefaultsData["dabasAPISecret"] = UserDefaultsRepository.dabasAPISecret
        userDefaultsData["nightscoutURL"] = ObservableUserDefaults.shared.url.value
        userDefaultsData["nightscoutToken"] = UserDefaultsRepository.token.value
        userDefaultsData["gptAPIKey"] = UserDefaultsRepository.gptAPIKey
        
        userDefaultsData["allowSharingOngoingMeals"] = UserDefaultsRepository.allowSharingOngoingMeals.description
        userDefaultsData["allowViewingOngoingMeals"] = UserDefaultsRepository.allowViewingOngoingMeals.description
        userDefaultsData["schoolFoodURL"] = UserDefaultsRepository.schoolFoodURL ?? ""
        userDefaultsData["excludeWords"] = UserDefaultsRepository.excludeWords ?? ""
        userDefaultsData["topUps"] = UserDefaultsRepository.topUps ?? ""

        // Add keyId and APNS key
        userDefaultsData["keyId"] = Storage.shared.keyId.value
        let apnsKey = Storage.shared.apnsKey.value
        if !apnsKey.isEmpty {
            let escapedKey = apnsKey.replacingOccurrences(of: "\n", with: "\\n")
            userDefaultsData["apnsKey"] = escapedKey
        }
        
        // Convert to CSV
        let csvString = userDefaultsData.map { "\($0.key);\($0.value)" }.joined(separator: "\n")
        
        // Generate filename
        let caregiverName = UserDefaultsRepository.caregiverName.replacingOccurrences(of: " ", with: "_")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = "UserDefaults_\(caregiverName)_\(timestamp).csv"
        
        await saveUserDefaultsCSV(data: csvString, fileName: fileName)
        showAlert(title: NSLocalizedString("Export lyckades", comment: "Export lyckades"), message: NSLocalizedString("Användarinställningarna har exporterats.", comment: "Användarinställningarna har exporterats."))
    }

    @objc private func importUserDefaultsFromCSV() async {
        await presentDocumentPicker(for: "UserDefaults")
    }

    private func parseUserDefaultsCSV(_ rows: [String]) {
        for row in rows {
            let values = splitCSVLine(row)
            guard values.count == 2 else { continue }

            let key = values[0]
            var value = values[1]

            // Handle multiline APNS Key
            if key == "apnsKey" {
                let unescapedKey = value.replacingOccurrences(of: "\\n", with: "\n")
                Storage.shared.apnsKey.value = unescapedKey
                continue
            }

            switch key {
            case "twilioSIDString":
                UserDefaultsRepository.twilioSIDString = value
            case "twilioSecretString":
                UserDefaultsRepository.twilioSecretString = value
            case "twilioFromNumberString":
                UserDefaultsRepository.twilioFromNumberString = value
            case "remoteSecretCode":
                UserDefaultsRepository.remoteSecretCode = value
            case "useStartDosePercentage":
                UserDefaultsRepository.useStartDosePercentage = Bool(value) ?? false
            case "startDoseFactor":
                UserDefaultsRepository.startDoseFactor = Double(value) ?? 0.5
            case "maxCarbs":
                UserDefaultsRepository.maxCarbs = Double(value) ?? 30.0
            case "maxBolus":
                UserDefaultsRepository.maxBolus = Double(value) ?? 1.0
            case "overrideFactor":
                UserDefaultsRepository.overrideFactor = Double(value) ?? 1.0
            case "overrideName":
                UserDefaultsRepository.overrideName = value
            case "useMmol":
                UserDefaultsRepository.useMmol = Bool(value) ?? false
            case "overrideStartTime":
                if let date = ISO8601DateFormatter().date(from: value) {
                    UserDefaultsRepository.overrideStartTime = date
                }
            case "overrideFactorUsed":
                UserDefaultsRepository.overrideFactorUsed = value
            case "dabasAPISecret":
                UserDefaultsRepository.dabasAPISecret = value
            case "nightscoutURL":
                UserDefaultsRepository.nightscoutURL = value
            case "nightscoutToken":
                UserDefaultsRepository.nightscoutToken = value
            case "gptAPIKey":
                UserDefaultsRepository.gptAPIKey = value
            case "allowSharingOngoingMeals":
                UserDefaultsRepository.allowSharingOngoingMeals = Bool(value) ?? false
            case "allowViewingOngoingMeals":
                UserDefaultsRepository.allowViewingOngoingMeals = Bool(value) ?? true
            case "schoolFoodURL":
                UserDefaultsRepository.schoolFoodURL = value
            case "excludeWords":
                UserDefaultsRepository.excludeWords = value
            case "topUps":
                UserDefaultsRepository.topUps = value
            case "keyId":
                Storage.shared.keyId.value = value
            default:
                break
            }
        }
        NotificationCenter.default.post(name: .didImportUserDefaults, object: nil)
    }

    private func splitCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var isEscaped = false

        for char in line {
            if char == "\\" && !isEscaped {
                isEscaped = true
                continue
            }
            if char == ";" && !isEscaped {
                result.append(currentField)
                currentField = ""
                continue
            }
            currentField.append(char)
            isEscaped = false
        }

        result.append(currentField)
        return result
    }}

// Document Picker Delegate Methods
extension DataSharingViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            if let entityName = controller.accessibilityHint {
                if entityName == "UserDefaults" {
                    Task {
                        let csvData = try String(contentsOf: url, encoding: .utf8)
                        let rows = csvData.components(separatedBy: "\n").filter { !$0.isEmpty }
                        parseUserDefaultsCSV(rows)
                        showAlert(title: NSLocalizedString("Import lyckades", comment: "Import lyckades"), message: NSLocalizedString("Användarinställningarna har importerats.", comment: "Användarinställningarna har importerats."))
                    }
                } else {
                    Task { await parseCSV(at: url, for: entityName) }
                }
            }
        } else {
            print("Failed to access security-scoped resource.")
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
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
        var csvString = "foodItemID;portionServed;notEaten;registeredCarbsSoFar;registeredFatSoFar;registeredProteinSoFar;registeredBolusSoFar;mealDate\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for row in foodItemRows {
            let foodItemID = row.foodItemID?.uuidString ?? ""
            let portionServed = row.portionServed
            let notEaten = row.notEaten
            let registeredCarbsSoFar = row.registeredCarbsSoFar
            let registeredFatSoFar = row.registeredFatSoFar
            let registeredProteinSoFar = row.registeredProteinSoFar
            let registeredBolusSoFar = row.registeredBolusSoFar
            let mealDate = row.mealDate.map { dateFormatter.string(from: $0) } ?? ""
            
            //print("Mealdate for row in CSV: \(mealDate)") // Debug print to verify formatted date
            
            csvString += "\(foodItemID);\(portionServed);\(notEaten);\(registeredCarbsSoFar);\(registeredFatSoFar);\(registeredProteinSoFar);\(registeredBolusSoFar);\(mealDate)\n"
        }
        
        return csvString
    }
    
    
    
    
    public func saveCSV(data: String, fileName: String) async {
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
    public func saveUserDefaultsCSV(data: String, fileName: String) async {
        let tempDirectory = NSURL(fileURLWithPath: NSTemporaryDirectory())
        let tempFilePath = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempFilePath!, atomically: true, encoding: .utf8)
            
            let fileManager = FileManager.default
            let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent(NSLocalizedString("Documents/CarbsCounter/Användarinställningar", comment: "Documents/CarbsCounter/Användarinställningar"))
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
}
