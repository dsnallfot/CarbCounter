//
//  ComposeMealViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-17.

import UIKit
import CoreData
import AudioToolbox
import LocalAuthentication
import CloudKit

class ComposeMealViewController: UIViewController, FoodItemRowViewDelegate, /*AddFoodItemDelegate,*/ UITextFieldDelegate, TwilioRequestable {
    
    var foodItemRows: [FoodItemRowView] = []
    var stackView: UIStackView!
    var scrollView: UIScrollView!
    var contentView: UIView!
    var foodItems: [FoodItem] = []
    var addButtonRowView: AddButtonRowView!
    var totalNetCarbsLabel: UILabel!
    var totalNetFatLabel: UILabel!
    var totalNetProteinLabel: UILabel!
    var searchableDropdownView: SearchableDropdownView!
    
    var nowCRLabel: UILabel!
    var totalBolusAmountLabel: UILabel!
    var totalStartAmountLabel: UILabel!
    var totalRegisteredLabel: UITextField!
    var totalRemainsLabel: UILabel!
    var totalStartBolusLabel: UILabel!
    var totalRemainsBolusLabel: UILabel!
    var remainsLabel: UILabel!
    var crLabel: UILabel!
    var remainsContainer: UIView!
    var startAmountContainer: UIView!
    var registeredContainer: UIView!
    
    var scheduledStartDose = Double(20)
    var scheduledCarbRatio = Double(25)
    
    var foodItemLabel: UILabel!
    var portionServedLabel: UILabel!
    var notEatenLabel: UILabel!
    var netCarbsLabel: UILabel!
    
    var clearAllButton: UIBarButtonItem!
    var saveFavoriteButton: UIButton!
    var addFromSearchableDropdownButton: UIBarButtonItem!
    
    var searchableDropdownBottomConstraint: NSLayoutConstraint!
    
    var allowShortcuts: Bool = false
    var saveMealToHistory: Bool = false
    var zeroBolus: Bool = false
    var lateBreakfast: Bool = false
    var lateBreakfastFactor = Double(1.5)
    
    var dataSharingVC: DataSharingViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Måltid"
        
        // Setup the fixed header containing summary and headline
        let fixedHeaderContainer = UIView()
        fixedHeaderContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fixedHeaderContainer)
        
        NSLayoutConstraint.activate([
            fixedHeaderContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            fixedHeaderContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fixedHeaderContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fixedHeaderContainer.heightAnchor.constraint(equalToConstant: 155) // Adjust height as needed
        ])
        
        // Reset lateBreakfast to false
        UserDefaults.standard.set(false, forKey: "lateBreakfast")
        lateBreakfast = false
        
        // Ensure addButtonRowView is initialized
        addButtonRowView = AddButtonRowView()
        
        updatePlaceholderValuesForCurrentHour() //Make sure carb ratio and start dose schedules are updated
        
        lateBreakfastFactor = UserDefaultsRepository.lateBreakfastFactor // Fetch factor for calculating late breakfast CR
        
        lateBreakfast = UserDefaults.standard.bool(forKey: "lateBreakfast")
        addButtonRowView.lateBreakfastSwitch.isOn = lateBreakfast
        
        if lateBreakfast {
            scheduledCarbRatio /= lateBreakfastFactor // If latebreakfast switch is on, calculate new CR
        }
        
        updateScheduledValuesUI() // Update labels
        
        // Setup summary view
        setupSummaryView(in: fixedHeaderContainer)
        
        // Setup treatment view
        setupTreatmentView(in: fixedHeaderContainer)
        
        // Setup headline
        setupHeadline(in: fixedHeaderContainer)
        
        // Setup scroll view
        setupScrollView(below: fixedHeaderContainer)
        
        // Initialize "Clear All" button
        clearAllButton = UIBarButtonItem(title: "Rensa måltid", style: .plain, target: self, action: #selector(clearAllButtonTapped))
        clearAllButton.tintColor = .red // Set the button color to red
        navigationItem.rightBarButtonItem = clearAllButton
        
        // Initialize "Add from SearchableDropdown" button
        addFromSearchableDropdownButton = UIBarButtonItem(title: "Visa måltid", style: .plain, target: self, action: #selector(addFromSearchableDropdownButtonTapped))
        
        // Ensure searchableDropdownView is properly initialized
        setupSearchableDropdownView()
        
        // Fetch food items and add the add button row
        fetchFoodItems()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
        
        // Add observer for text changes in totalRegisteredLabel
        totalRegisteredLabel.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        // Add target to totalRegisteredLabel to handle changes
        totalRegisteredLabel.addTarget(self, action: #selector(totalRegisteredLabelChanged), for: .editingChanged)
        
        // Set the delegate for the text field
        totalRegisteredLabel.delegate = self
        
        // Observe changes to allowShortcuts
        NotificationCenter.default.addObserver(self, selector: #selector(allowShortcutsChanged), name: Notification.Name("AllowShortcutsChanged"), object: nil)
        
        // Load allowShortcuts from UserDefaults
        allowShortcuts = UserDefaults.standard.bool(forKey: "allowShortcuts")
        
        // Create buttons
        let calendarImage = UIImage(systemName: "calendar")
        let historyButton = UIButton(type: .system)
        historyButton.setImage(calendarImage, for: .normal)
        historyButton.addTarget(self, action: #selector(showMealHistory), for: .touchUpInside)
        
        let showFavoriteMealsImage = UIImage(systemName: "star")
        let showFavoriteMealsButton = UIButton(type: .system)
        showFavoriteMealsButton.setImage(showFavoriteMealsImage, for: .normal)
        showFavoriteMealsButton.addTarget(self, action: #selector(showFavoriteMeals), for: .touchUpInside)
        
        let saveFavoriteImage = UIImage(systemName: "plus.circle")
        saveFavoriteButton = UIButton(type: .system)
        saveFavoriteButton.setImage(saveFavoriteImage, for: .normal)
        saveFavoriteButton.addTarget(self, action: #selector(saveFavoriteMeals), for: .touchUpInside)
        saveFavoriteButton.isEnabled = false // Initially disabled
        saveFavoriteButton.tintColor = .gray // Change appearance to indicate disabled state
        
        // Create stack view
        let stackView = UIStackView(arrangedSubviews: [historyButton, showFavoriteMealsButton, saveFavoriteButton])
        stackView.axis = .horizontal
        stackView.spacing = 20 // Adjust this value to decrease the spacing
        
        // Create custom view
        let customView = UIView()
        customView.addSubview(stackView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: customView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: customView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: customView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: customView.bottomAnchor)
        ])
        
        let customBarButtonItem = UIBarButtonItem(customView: customView)
        navigationItem.leftBarButtonItem = customBarButtonItem
        
        // Add observers for keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        addButtonRowView.lateBreakfastSwitch.addTarget(self, action: #selector(lateBreakfastSwitchChanged(_:)), for: .valueChanged)
        
        // Instantiate DataSharingViewController programmatically
        dataSharingVC = DataSharingViewController()
        
        loadFoodItemsFromCoreData()
        
        //print("setupSummaryView ran")
        //print("setupScrollView ran")
        //print("setupStackView ran")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.endEditing(true)
        
        updatePlaceholderValuesForCurrentHour() //Make sure carb ratio and start dose schedules are updated
        
        lateBreakfastFactor = UserDefaultsRepository.lateBreakfastFactor // Fetch factor for calculating late breakfast CR
        
        if lateBreakfast {
            scheduledCarbRatio /= lateBreakfastFactor // If latebreakfast switch is on, calculate new CR
        }
        updateScheduledValuesUI() // Update labels
        
        updateBorderColor() // Add this line to ensure the border color updates
        addButtonRowView.updateBorderColor() // Add this line to update the border color of the AddButtonRowView
        
        // Ensure updateTotalNutrients is called after all initializations
        updateTotalNutrients()
        
        
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else { return }

        // Call the desired function
        print("Data import triggered")
        dataSharingVC.importAllCSVFiles()
        
        
        //print("viewWillAppear: totalNetCarbsLabel: \(totalNetCarbsLabel?.text ?? "nil")")
        //print("viewWillAppear: clearAllButton: \(clearAllButton != nil)")
        //print("viewWillAppear: saveFavoriteButton: \(saveFavoriteButton != nil)")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if lateBreakfast {
            scheduledCarbRatio *= lateBreakfastFactor // Reset scheduledCarbRatio when leaving view
        }
        UserDefaultsRepository.scheduledCarbRatio = scheduledCarbRatio //Save carb ratio in user defaults
    }
    
    @objc private func totalRegisteredLabelChanged() {
        saveToCoreData()
    }
    
    func saveToCoreData() {
        let context = CoreDataStack.shared.context
        
        // Save the totalRegisteredLabel value
        if let totalRegisteredText = totalRegisteredLabel.text,
           let totalRegisteredValue = Double(totalRegisteredText.replacingOccurrences(of: "g", with: "")) {
            
            for rowView in foodItemRows {
                if let foodItemRow = rowView.foodItemRow {
                    foodItemRow.portionServed = Double(rowView.portionServedTextField.text ?? "0") ?? 0
                    foodItemRow.notEaten = Double(rowView.notEatenTextField.text ?? "0") ?? 0
                    foodItemRow.foodItemID = rowView.selectedFoodItem?.id
                    foodItemRow.totalRegisteredValue = totalRegisteredValue // Save total registered value
                } else {
                    let foodItemRow = FoodItemRow(context: context)
                    foodItemRow.portionServed = Double(rowView.portionServedTextField.text ?? "0") ?? 0
                    foodItemRow.notEaten = Double(rowView.notEatenTextField.text ?? "0") ?? 0
                    foodItemRow.foodItemID = rowView.selectedFoodItem?.id
                    foodItemRow.totalRegisteredValue = totalRegisteredValue // Save total registered value
                    rowView.foodItemRow = foodItemRow
                }
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save FoodItemRows: \(error)")
        }
    }

    private func loadFoodItemsFromCoreData() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItemRow> = FoodItemRow.fetchRequest()

        do {
            let savedFoodItems = try context.fetch(fetchRequest)
            
            // Clear current food item rows to avoid duplicates
            clearAllFoodItems()
            
            for savedFoodItem in savedFoodItems {
                if let foodItemID = savedFoodItem.foodItemID, // Ensure the ID is not nil
                   let foodItem = foodItems.first(where: { $0.id == foodItemID }) { // Compare using UUID
                    
                    // Check if the item already exists
                    if !foodItemRows.contains(where: { $0.foodItemRow?.foodItemID == foodItemID }) {
                        let rowView = FoodItemRowView()
                        rowView.foodItems = foodItems
                        rowView.delegate = self
                        rowView.translatesAutoresizingMaskIntoConstraints = false
                        rowView.foodItemRow = savedFoodItem // Associate the Core Data object
                        
                        // Set the selected food item and the text fields
                        rowView.setSelectedFoodItem(foodItem)
                        rowView.portionServedTextField.text = formatNumber(savedFoodItem.portionServed)
                        rowView.notEatenTextField.text = formatNumber(savedFoodItem.notEaten)
                        
                        // Add the row view to your stack view
                        stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count - 1)
                        foodItemRows.append(rowView)
                        
                        rowView.onDelete = { [weak self] in
                            self?.removeFoodItemRow(rowView)
                        }
                        
                        rowView.onValueChange = { [weak self] in
                            self?.updateTotalNutrients()
                        }
                        
                        // Recalculate nutrients based on loaded data
                        rowView.calculateNutrients()
                    }
                }
            }
            
            // Load totalRegisteredValue from CoreData and update the label
            if let firstSavedItem = savedFoodItems.first {
                totalRegisteredLabel.text = formatNumber(firstSavedItem.totalRegisteredValue)
            }
            
            updateTotalNutrients()
            updateClearAllButtonState()
            updateSaveFavoriteButtonState()
            updateHeadlineVisibility()
        } catch {
            print("Failed to fetch FoodItemRows: \(error)")
        }
    }

    private func formatNumberWithoutTrailingZero(_ number: Double) -> String {
        let formattedNumber = String(format: "%.1f", number)
        return formattedNumber.hasSuffix(".0") ? String(formattedNumber.dropLast(2)) : formattedNumber
    }
    
    private func getCombinedEmojis() -> String {
        return searchableDropdownView?.combinedEmojis ?? "🍽️"
    }
    
    private func updatePlaceholderValuesForCurrentHour() {
        let currentHour = Calendar.current.component(.hour, from: Date())
        if let carbRatio = CoreDataHelper.shared.fetchCarbRatio(for: currentHour) {
            scheduledCarbRatio = carbRatio
        }
        if let startDose = CoreDataHelper.shared.fetchStartDose(for: currentHour) {
            scheduledStartDose = startDose
        }
    }
    
    private func updateSaveFavoriteButtonState() {
        guard let saveFavoriteButton = saveFavoriteButton else {
            print("saveFavoriteButton is nil")
            return
        }
        let isEnabled = !foodItemRows.isEmpty
        saveFavoriteButton.isEnabled = isEnabled
        saveFavoriteButton.tintColor = isEnabled ? .systemBlue : .gray // Update appearance based on state
    }
    
    @objc private func registeredContainerTapped() {
        totalRegisteredLabel.becomeFirstResponder()
    }
    
    @objc private func saveFavoriteMeals() {
        guard !foodItemRows.isEmpty else {
            let alert = UIAlertController(title: "Inga livsmedel", message: "Välj minst ett livsmedel för att spara en favorit.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let nameAlert = UIAlertController(title: "Spara som favoritmåltid", message: "Ange ett namn på måltiden:", preferredStyle: .alert)
        nameAlert.addTextField { textField in
            textField.placeholder = "Namn"
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.autocapitalizationType = .sentences
            textField.textContentType = .none
            
            if #available(iOS 11.0, *) {
                textField.inputAssistantItem.leadingBarButtonGroups = []
                textField.inputAssistantItem.trailingBarButtonGroups = []
            }
        }
        
        let saveAction = UIAlertAction(title: "Spara", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let mealName = nameAlert.textFields?.first?.text ?? "Min favoritmåltid"
            
            let favoriteMeals = FavoriteMeals(context: CoreDataStack.shared.context)
            favoriteMeals.name = mealName
            favoriteMeals.id = UUID()
            
            var items: [[String: Any]] = []
            for row in self.foodItemRows {
                if let foodItem = row.selectedFoodItem {
                    let item: [String: Any] = [
                        "name": foodItem.name ?? "",
                        "portionServed": row.portionServedTextField.text ?? "",
                        "perPiece": foodItem.perPiece
                    ]
                    items.append(item)
                }
            }
            
            // Serialize the items array to JSON
            if let jsonData = try? JSONSerialization.data(withJSONObject: items, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                favoriteMeals.items = jsonString as NSObject
            }
            
            CoreDataStack.shared.saveContext()

            // Ensure dataSharingVC is instantiated
                    guard let dataSharingVC = dataSharingVC else { return }

                    // Call the desired function
                    dataSharingVC.exportFavoriteMealsToCSV()
            print("Favorite meals export triggered")
            
            let confirmAlert = UIAlertController(title: "Lyckades", message: "Måltiden har sparats som favorit.", preferredStyle: .alert)
            confirmAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(confirmAlert, animated: true)
        }
        
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        
        nameAlert.addAction(saveAction)
        nameAlert.addAction(cancelAction)
        
        present(nameAlert, animated: true)
    }
    
    @objc private func showMealHistory() {
        let mealHistoryVC = MealHistoryViewController()
        navigationController?.pushViewController(mealHistoryVC, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func showFavoriteMeals() {
        let favoriteMealsVC = FavoriteMealsViewController()
        navigationController?.pushViewController(favoriteMealsVC, animated: true)
    }
    
    // Helper method to format the double values
    private func formattedValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    func populateWithFavoriteMeal(_ favoriteMeal: FavoriteMeals) {
        clearAllFoodItems()
        
        guard let itemsString = favoriteMeal.items as? String,
              let data = itemsString.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            print("Error: Unable to cast favoriteMeal.items to [[String: Any]].")
            return
        }
        
        for item in items {
            if let name = item["name"] as? String,
               let portionServedString = item["portionServed"] as? String,
               let portionServed = Double(portionServedString) {
                print("Item name: \(name), Portion Served: \(portionServed)")
                if let foodItem = foodItems.first(where: { $0.name == name }) {
                    print("Food Item Found: \(foodItem.name ?? "")")
                    let rowView = FoodItemRowView()
                    rowView.foodItems = foodItems
                    rowView.delegate = self
                    rowView.translatesAutoresizingMaskIntoConstraints = false
                    stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count - 1)
                    foodItemRows.append(rowView)
                    rowView.setSelectedFoodItem(foodItem)
                    rowView.portionServedTextField.text = formattedValue(portionServed)
                    rowView.portionServedTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
                    
                    rowView.onDelete = { [weak self] in
                        self?.removeFoodItemRow(rowView)
                    }
                    
                    rowView.onValueChange = { [weak self] in
                        self?.updateTotalNutrients()
                        self?.updateHeadlineVisibility()
                    }
                    rowView.calculateNutrients()
                } else {
                    print("Error: Food item with name \(name) not found in foodItems.")
                }
            } else {
                print("Error: Invalid item format. Name or Portion Served missing.")
            }
        }
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
        //print("Completed populateWithFavoriteMeal")
    }
    
    func populateWithMealHistory(_ mealHistory: MealHistory) {
        clearAllFoodItems()
        
        for foodEntry in mealHistory.foodEntries?.allObjects as? [FoodItemEntry] ?? [] {
            if let foodItem = foodItems.first(where: { $0.name == foodEntry.entryName }) {
                let rowView = FoodItemRowView()
                rowView.foodItems = foodItems
                rowView.delegate = self
                rowView.translatesAutoresizingMaskIntoConstraints = false
                stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count - 1)
                foodItemRows.append(rowView)
                rowView.setSelectedFoodItem(foodItem)
                rowView.portionServedTextField.text = formattedValue(foodEntry.entryPortionServed)
                rowView.portionServedTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
                
                rowView.onDelete = { [weak self] in
                    self?.removeFoodItemRow(rowView)
                }
                
                rowView.onValueChange = { [weak self] in
                    self?.updateTotalNutrients()
                    self?.updateHeadlineVisibility()
                }
                rowView.calculateNutrients()
            } else {
                print("Food item not found for name: \(foodEntry.entryName ?? "")")
            }
        }
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        if let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
            textField.text = text.replacingOccurrences(of: ",", with: ".")
        }
        updateTotalNutrients()
        updateHeadlineVisibility()
    }
    
    @objc private func clearAllButtonTapped() {
        view.endEditing(true)
        
        let alertController = UIAlertController(title: "Rensa Måltid", message: "Bekräfta att du vill rensa alla valda livsmedel och inmatade värden för denna måltid. \nÅtgärden kan inte ångras.", preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        let yesAction = UIAlertAction(title: "Rensa", style: .destructive) { _ in
            if self.saveMealToHistory {
                self.saveMealHistory() // Save MealHistory if the flag is true
            }
            self.clearAllFoodItems()
            self.totalRegisteredLabel.text = ""
            self.updateTotalNutrients()
            self.clearAllButton.isEnabled = false // Disable the “Clear All” button
            self.clearAllFoodItemRowsFromCoreData() // Add this line to clear Core Data entries
        }
        alertController.addAction(cancelAction)
        alertController.addAction(yesAction)
        present(alertController, animated: true, completion: nil)
    }
    
    private func clearAllFoodItemRowsFromCoreData() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = FoodItemRow.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to delete FoodItemRows: \(error)")
        }
    }
    
    func deleteFoodItemRow(_ rowView: FoodItemRowView) {
        let context = CoreDataStack.shared.context
        if let foodItemRow = rowView.foodItemRow {
            context.delete(foodItemRow)
            
            do {
                try context.save()
                removeFoodItemRow(rowView)
            } catch {
                print("Failed to delete FoodItemRow: \(error)")
            }
        }
    }
    
    private func saveMealHistory() {
        let context = CoreDataStack.shared.context
        
        let mealHistory = MealHistory(context: context)
        mealHistory.id = UUID() // Set the id attribute
        mealHistory.mealDate = Date()
        mealHistory.totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }
        mealHistory.totalNetFat = foodItemRows.reduce(0.0) { $0 + $1.netFat }
        mealHistory.totalNetProtein = foodItemRows.reduce(0.0) { $0 + $1.netProtein }
        
        for row in foodItemRows {
            if let foodItem = row.selectedFoodItem {
                let foodEntry = FoodItemEntry(context: context)
                foodEntry.entryId = UUID()
                foodEntry.entryName = foodItem.name
                foodEntry.entryCarbohydrates = foodItem.carbohydrates
                foodEntry.entryFat = foodItem.fat
                foodEntry.entryProtein = foodItem.protein
                foodEntry.entryEmoji = foodItem.emoji
                
                // Replace commas with dots for EU decimal separators
                let portionServedText = row.portionServedTextField.text?.replacingOccurrences(of: ",", with: ".") ?? "0"
                let notEatenText = row.notEatenTextField.text?.replacingOccurrences(of: ",", with: ".") ?? "0"
                
                foodEntry.entryPortionServed = Double(portionServedText) ?? 0
                foodEntry.entryNotEaten = Double(notEatenText) ?? 0
                
                foodEntry.entryCarbsPP = foodItem.carbsPP
                foodEntry.entryFatPP = foodItem.fatPP
                foodEntry.entryProteinPP = foodItem.proteinPP
                foodEntry.entryPerPiece = foodItem.perPiece
                mealHistory.addToFoodEntries(foodEntry)
            }
        }
        
        do {
            try context.save()
            print("MealHistory saved successfully!")

        } catch {
            print("Failed to save MealHistory: \(error)")
        }
        
        // Ensure dataSharingVC is instantiated
                guard let dataSharingVC = dataSharingVC else { return }

                // Call the desired function
                dataSharingVC.exportMealHistoryToCSV()
        print("Meal history export triggered")
        
        saveMealToHistory = false // Reset the flag after saving
    }
    
    private func clearAllFoodItems() {
        for row in foodItemRows {
            stackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        foodItemRows.removeAll()
        updateTotalNutrients()
        view.endEditing(true)
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
        
        // Reset the text of totalRegisteredLabel
        totalRegisteredLabel.text = ""
        // Reset the totalNetCarbsLabel and other total labels
        totalNetCarbsLabel.text = "0 g"
        totalNetFatLabel.text = "0 g"
        totalNetProteinLabel.text = "0 g"
        totalBolusAmountLabel.text = "0 E"
        totalStartAmountLabel.text = "0 g"
        totalRemainsLabel.text = "0 g"
        totalRemainsBolusLabel.text = "0 E"
        
        // Reset the startBolus amount
        totalStartBolusLabel.text = "0 E"
        
        // Reset the remainsContainer color and label
        remainsContainer.backgroundColor = .systemGray
        remainsLabel.text = "+ SLUTDOS"
    }

    
    private func setupScrollView(below header: UIView) {
        //print("setupScrollView ran")
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .systemBackground
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        setupStackView()
    }
    
    private func setupStackView() {
        //print("setupStackView ran")
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        
        //fetchFoodItems()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState() // Add this line
        updateHeadlineVisibility()
        addAddButtonRow()
    }
    
    private func setupSummaryView(in container: UIView) {
        //print("setupSummaryView ran")
        let summaryView = UIView()
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        summaryView.backgroundColor = .systemGray6//.systemBackground
        container.addSubview(summaryView)
        
        let bolusContainer = createContainerView(backgroundColor: .systemBlue)
        summaryView.addSubview(bolusContainer)
        
        let bolusLabel = createLabel(text: "BOLUS", fontSize: 9, weight: .bold, color: .white)
        totalBolusAmountLabel = createLabel(text: "0.00 E", fontSize: 18, weight: .bold, color: .white)
        let bolusStack = UIStackView(arrangedSubviews: [bolusLabel, totalBolusAmountLabel])
        let bolusPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(bolusStack, in: bolusContainer, padding: bolusPadding)
        
        // Add tap gesture for bolusContainer
        let bolusTapGesture = UITapGestureRecognizer(target: self, action: #selector(showBolusInfo))
        bolusContainer.isUserInteractionEnabled = true
        bolusContainer.addGestureRecognizer(bolusTapGesture)
        
        let carbsContainer = createContainerView(backgroundColor: .systemOrange)
        summaryView.addSubview(carbsContainer)
        
        let summaryLabel = createLabel(text: "KOLHYDRATER", fontSize: 9, weight: .bold, color: .white)
        totalNetCarbsLabel = createLabel(text: "0.0 g", fontSize: 18, weight: .semibold, color: .white)
        let carbsStack = UIStackView(arrangedSubviews: [summaryLabel, totalNetCarbsLabel])
        let carbsPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(carbsStack, in: carbsContainer, padding: carbsPadding)
        
        // Add tap gesture for carbsContainer
        let carbsTapGesture = UITapGestureRecognizer(target: self, action: #selector(showCarbsInfo))
        carbsContainer.isUserInteractionEnabled = true
        carbsContainer.addGestureRecognizer(carbsTapGesture)
        
        let fatContainer = createContainerView(backgroundColor: .systemBrown)
        summaryView.addSubview(fatContainer)
        
        let netFatLabel = createLabel(text: "FETT", fontSize: 9, weight: .bold, color: .white)
        totalNetFatLabel = createLabel(text: "0.0 g", fontSize: 18, weight: .semibold, color: .white)
        let fatStack = UIStackView(arrangedSubviews: [netFatLabel, totalNetFatLabel])
        let fatPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(fatStack, in: fatContainer, padding:fatPadding)
        // Add tap gesture for fatContainer
        let fatTapGesture = UITapGestureRecognizer(target: self, action: #selector(showFatInfo))
        fatContainer.isUserInteractionEnabled = true
        fatContainer.addGestureRecognizer(fatTapGesture)
        
        let proteinContainer = createContainerView(backgroundColor: .systemBrown)
        summaryView.addSubview(proteinContainer)
        
        let netProteinLabel = createLabel(text: "PROTEIN", fontSize: 9, weight: .bold, color: .white)
        totalNetProteinLabel = createLabel(text: "0.0 g", fontSize: 18, weight: .semibold, color: .white)
        let proteinStack = UIStackView(arrangedSubviews: [netProteinLabel, totalNetProteinLabel])
        let proteinPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(proteinStack, in: proteinContainer, padding: proteinPadding)
        
        // Add tap gesture for proteinContainer
        let proteinTapGesture = UITapGestureRecognizer(target: self, action: #selector(showProteinInfo))
        proteinContainer.isUserInteractionEnabled = true
        proteinContainer.addGestureRecognizer(proteinTapGesture)
        
        let hStack = UIStackView(arrangedSubviews: [bolusContainer, fatContainer, proteinContainer, carbsContainer])
        hStack.axis = .horizontal
        hStack.spacing = 8
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.distribution = .fillEqually
        summaryView.addSubview(hStack)
        
        NSLayoutConstraint.activate([
            summaryView.heightAnchor.constraint(equalToConstant: 60),
            summaryView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            summaryView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            summaryView.topAnchor.constraint(equalTo: container.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor, constant: -16),
            hStack.topAnchor.constraint(equalTo: summaryView.topAnchor, constant: 10),
            hStack.bottomAnchor.constraint(equalTo: summaryView.bottomAnchor, constant: -5)
        ])
    }
    
    @objc private func showBolusInfo() {
        showAlert(title: "Bolus Total", message: "Den beräknade mängden insulin som krävs för att täcka de kolhydrater som måltiden består av.")
    }
    @objc private func showCarbsInfo() {
        showAlert(title: "Kolhydrater Totalt", message: "Den beräknade summan av alla kolhydrater i måltiden.")
    }
    
    @objc private func showFatInfo() {
        showAlert(title: "Fett Totalt", message: "Den beräknade summan av all fett i måltiden. \n\nFett kräver också insulin, men med några timmars fördröjning.")
    }
    
    @objc private func showProteinInfo() {
        showAlert(title: "Protein Totalt", message: "Den beräknade summan av all protein i måltiden. \n\nProtein kräver också insulin, men med några timmars fördröjning.")
    }
    
    @objc private func showAddFoodItemViewController() {
        let addFoodItemVC = AddFoodItemViewController()
        addFoodItemVC.delegate = self
        navigationController?.pushViewController(addFoodItemVC, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    // Custom function to format the scheduledCarbRatio
    func formatScheduledCarbRatio(_ value: Double) -> String {
        let roundedValue = round(value * 10) / 10.0
        if roundedValue == floor(roundedValue) {
            return String(format: "%.0f g/E", roundedValue)
        } else {
            return String(format: "%.1f g/E", roundedValue)
        }
    }
    
    private func setupTreatmentView(in container: UIView) {
        let treatmentView = UIView()
        treatmentView.translatesAutoresizingMaskIntoConstraints = false
        treatmentView.backgroundColor = .systemGray6 //.systemBackground
        container.addSubview(treatmentView)

        let crContainer = createContainerView(backgroundColor: .systemCyan)
        treatmentView.addSubview(crContainer)

        crLabel = createLabel(text: "INSULINKVOT", fontSize: 9, weight: .bold, color: .white)

        nowCRLabel = createLabel(text: formatScheduledCarbRatio(scheduledCarbRatio), fontSize: 18, weight: .bold, color: .white)

        let crStack = UIStackView(arrangedSubviews: [crLabel, nowCRLabel])
        crStack.axis = .vertical
        crStack.spacing = 4
        let crPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(crStack, in: crContainer, padding: crPadding)

        // Add tap gesture for crContainer
        let crTapGesture = UITapGestureRecognizer(target: self, action: #selector(showCRInfo))
        crContainer.isUserInteractionEnabled = true
        crContainer.addGestureRecognizer(crTapGesture)

        remainsContainer = createContainerView(backgroundColor: .systemGreen, borderColor: .label, borderWidth: 2)
        treatmentView.addSubview(remainsContainer)
        let remainsTapGesture = UITapGestureRecognizer(target: self, action: #selector(remainContainerTapped))
        remainsContainer.addGestureRecognizer(remainsTapGesture)
        remainsContainer.isUserInteractionEnabled = true

        remainsLabel = createLabel(text: "GE RESTEN", fontSize: 9, weight: .bold, color: .white)
        totalRemainsLabel = createLabel(text: "0g", fontSize: 12, weight: .semibold, color: .white)
        totalRemainsBolusLabel = createLabel(text: "0E", fontSize: 12, weight: .semibold, color: .white)

        let remainsValuesStack = UIStackView(arrangedSubviews: [totalRemainsLabel, totalRemainsBolusLabel])
        remainsValuesStack.axis = .horizontal
        remainsValuesStack.spacing = 3

        let remainsStack = UIStackView(arrangedSubviews: [remainsLabel, remainsValuesStack])
        remainsStack.axis = .vertical
        remainsStack.spacing = 7
        let remainsPadding = UIEdgeInsets(top: 4, left: 2, bottom: 7, right: 2)
        setupStackView(remainsStack, in: remainsContainer, padding: remainsPadding)

        startAmountContainer = createContainerView(backgroundColor: .systemPurple, borderColor: .label, borderWidth: 2) // Properly initialize startAmountContainer
        treatmentView.addSubview(startAmountContainer)
        let startAmountTapGesture = UITapGestureRecognizer(target: self, action: #selector(startAmountContainerTapped))
        startAmountContainer.addGestureRecognizer(startAmountTapGesture)
        startAmountContainer.isUserInteractionEnabled = true

        let startAmountLabel = createLabel(text: "+ STARTDOS", fontSize: 9, weight: .bold, color: .white)
        totalStartAmountLabel = createLabel(text: String(format: "%.0fg", scheduledStartDose), fontSize: 12, weight: .semibold, color: .white)
        totalStartBolusLabel = createLabel(text: "0E", fontSize: 12, weight: .semibold, color: .white)

        let startAmountValuesStack = UIStackView(arrangedSubviews: [totalStartAmountLabel, totalStartBolusLabel])
        startAmountValuesStack.axis = .horizontal
        startAmountValuesStack.spacing = 3

        let startAmountStack = UIStackView(arrangedSubviews: [startAmountLabel, startAmountValuesStack])
        startAmountStack.axis = .vertical
        startAmountStack.spacing = 7
        let startAmountPadding = UIEdgeInsets(top: 4, left: 2, bottom: 7, right: 2)
        setupStackView(startAmountStack, in: startAmountContainer, padding: startAmountPadding)

        registeredContainer = createContainerView(backgroundColor: .systemGray2, borderColor: .label, borderWidth: 2) // Properly initialize registeredContainer
        treatmentView.addSubview(registeredContainer)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(registeredContainerTapped))
        registeredContainer.addGestureRecognizer(tapGesture)
        registeredContainer.isUserInteractionEnabled = true
        let registeredLabel = createLabel(text: "REGGADE KH", fontSize: 9, weight: .bold, color: .white)
        totalRegisteredLabel = createTextField(placeholder: "...", fontSize: 18, weight: .semibold, color: .white)
        totalRegisteredLabel.addTarget(self, action: #selector(registeredLabelDidChange), for: .editingChanged)

        let registeredStack = UIStackView(arrangedSubviews: [registeredLabel, totalRegisteredLabel])
        registeredStack.axis = .vertical
        registeredStack.spacing = 4
        let registeredPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(registeredStack, in: registeredContainer, padding: registeredPadding)
        let hStack = UIStackView(arrangedSubviews: [crContainer, startAmountContainer, remainsContainer, registeredContainer])
        hStack.axis = .horizontal
        hStack.spacing = 8
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.distribution = .fillEqually
        treatmentView.addSubview(hStack)

        NSLayoutConstraint.activate([
            treatmentView.heightAnchor.constraint(equalToConstant: 60),
            treatmentView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            treatmentView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            treatmentView.topAnchor.constraint(equalTo: container.topAnchor, constant: 60),

            hStack.leadingAnchor.constraint(equalTo: treatmentView.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: treatmentView.trailingAnchor, constant: -16),
            hStack.topAnchor.constraint(equalTo: treatmentView.topAnchor, constant: 5),
            hStack.bottomAnchor.constraint(equalTo: treatmentView.bottomAnchor, constant: -10)
        ])

        addDoneButtonToKeyboard()
    }
    
    @objc private func showCRInfo() {
        showAlert(title: "Insulinkvot", message: "Även kallad Carb Ratio (CR)\n\nVärdet motsvarar hur stor mängd kolhydrater som 1 E insulin täcker.\n\n Exempel:\nCR 25 innebär att det behövs 1 E insulin till 25 g kolhydrater, eller 2 E insulin till 50 g kolhydrater.")
    }
    
    @objc private func allowShortcutsChanged() {
        allowShortcuts = UserDefaults.standard.bool(forKey: "allowShortcuts")
    }
    
    // Helper function to format values and remove trailing .0
    func formatValue(_ value: String) -> String {
        let doubleValue = Double(value) ?? 0.0
        return doubleValue.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", doubleValue) : String(doubleValue)
    }
    
    // Function to get the current date in UTC format
    func getCurrentDateUTC() -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter.string(from: Date())
    }
    
    @objc private func startAmountContainerTapped() {
        var khValue = formatValue(totalStartAmountLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0")
        var bolusValue = formatValue(totalStartBolusLabel.text?.replacingOccurrences(of: "E", with: "") ?? "0")
        
        // Ask if the user wants to give a bolus
        let bolusAlertController = UIAlertController(title: "Registrera måltid", message: "Vill du även ge en bolus till måltiden?", preferredStyle: .alert)
        let noAction = UIAlertAction(title: "Nej", style: .default) { _ in
            bolusValue = "0.0"
            self.proceedWithStartAmount(khValue: khValue, bolusValue: bolusValue)
        }
        let yesAction = UIAlertAction(title: "Ja", style: .destructive) { _ in
            self.proceedWithStartAmount(khValue: khValue, bolusValue: bolusValue)
        }
        bolusAlertController.addAction(noAction)
        bolusAlertController.addAction(yesAction)
        present(bolusAlertController, animated: true, completion: nil)
    }
    
    private func proceedWithStartAmount(khValue: String, bolusValue: String) {
        if UserDefaultsRepository.method == "iOS Shortcuts" {
            if allowShortcuts {
                let alertController = UIAlertController(title: "Registrera startdos för måltid", message: "Vill du registrera startdosen för måltiden i iAPS?", preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
                let yesAction = UIAlertAction(title: "Ja", style: .default) { _ in
                    self.registerStartAmountInIAPS(khValue: khValue, bolusValue: bolusValue)
                }
                alertController.addAction(cancelAction)
                alertController.addAction(yesAction)
                present(alertController, animated: true, completion: nil)
            } else {
                let alertController = UIAlertController(title: "Manuell registrering", message: "Registrera nu den angivna startdosen för måltiden \(khValue) g kh och \(bolusValue) E insulin i iAPS", preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
                let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                    self.updateRegisteredAmount(khValue: khValue)
                }
                alertController.addAction(cancelAction)
                alertController.addAction(okAction)
                present(alertController, animated: true, completion: nil)
            }
        } else {
            let alertController = UIAlertController(title: "Registrera startdos för måltid", message: "Vill du registrera den angivna startdosen för måltiden i iAPS enligt summeringen nedan? \n\n\(khValue) g kolhydrat \n\(bolusValue) E insulin", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                self.updateRegisteredAmount(khValue: khValue)
                let caregiverName = UserDefaultsRepository.caregiverName
                let remoteSecretCode = UserDefaultsRepository.remoteSecretCode
                let emojis = self.foodItemRows.isEmpty ? "⏱️" : self.getCombinedEmojis() // Check if foodItemRows is empty and set emojis accordingly
                let currentDate = self.getCurrentDateUTC() // Get the current date in UTC format
                let combinedString = "Remote Måltid\nKolhydrater: \(khValue)g\nFett: 0g\nProtein: 0g\nNotering: \(emojis)\nDatum: \(currentDate)\nInsulin: \(bolusValue)E\nInlagt av: \(caregiverName)\nHemlig kod: \(remoteSecretCode)"
                self.sendMealRequest(combinedString: combinedString)
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        }
    }
    
    private func registerStartAmountInIAPS(khValue: String, bolusValue: String) {
        var khValue = khValue.replacingOccurrences(of: ".", with: ",")
        var bolusValue = bolusValue.replacingOccurrences(of: ".", with: ",")
        let currentRegisteredValue = Double(totalRegisteredLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
        let remainsValue = Double(khValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let newRegisteredValue = currentRegisteredValue + remainsValue
        totalRegisteredLabel.text = String(format: "%.0f", newRegisteredValue).replacingOccurrences(of: ",", with: ".")
        updateTotalNutrients()
        clearAllButton.isEnabled = true
        let urlString = "shortcuts://run-shortcut?name=Startdos&input=text&text=kh_\(khValue)_bolus_\(bolusValue)"
        
        if let url = URL(string: urlString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    @objc private func remainContainerTapped() {
        let remainsValue = Double(totalRemainsLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
        
        if remainsValue < 0 {
            let khValue = totalRemainsLabel.text?.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ",", with: ".") ?? "0"
            let alert = UIAlertController(title: "Varning", message: "Du har registrerat en större startdos än vad som slutligen åts! \n\nSe till att komplettera med minst \(khValue) kolhydrater för att undvika hypoglykemi!", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
            return
        }
        
        let khValue = formatValue(totalRemainsLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0")
        let fatValue = formatValue(totalNetFatLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0")
        let proteinValue = formatValue(totalNetProteinLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0")
        var bolusValue = formatValue(totalRemainsBolusLabel.text?.replacingOccurrences(of: "E", with: "") ?? "0")
        
        let bolusAlertController = UIAlertController(title: "Registrera måltid", message: "Vill du även ge en bolus till måltiden?", preferredStyle: .alert)
        bolusAlertController.addTextField { textField in
            textField.text = bolusValue
            textField.keyboardType = .decimalPad
            textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
        }
        let noAction = UIAlertAction(title: "Nej", style: .default) { _ in
            self.zeroBolus = true
            self.checkAndProceedWithRemainingAmount(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: "0.0")
        }
        
        let yesAction = UIAlertAction(title: "Ja", style: .destructive) { _ in
            if let textField = bolusAlertController.textFields?.first, let customBolusValue = Double(textField.text?.replacingOccurrences(of: ",", with: ".") ?? "0") {
                self.zeroBolus = false
                self.checkAndProceedWithRemainingAmount(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: String(customBolusValue))
            }
        }
        
        bolusAlertController.addAction(noAction)
        bolusAlertController.addAction(yesAction)
        present(bolusAlertController, animated: true, completion: nil)
    }
    
    private func checkAndProceedWithRemainingAmount(khValue: String, fatValue: String, proteinValue: String, bolusValue: String) {
        var adjustedKhValue = khValue
        var adjustedBolusValue = self.zeroBolus ? "0.0" : bolusValue
        var showAlert = false
        
        if let maxCarbs = UserDefaultsRepository.maxCarbs as Double?,
           let khValueDouble = Double(khValue),
           khValueDouble > maxCarbs {
            adjustedKhValue = String(format: "%.0f", maxCarbs)
            if let carbRatio = Double(nowCRLabel.text?.replacingOccurrences(of: " g/E", with: "") ?? "0") {
                adjustedBolusValue = self.zeroBolus ? "0.0" : String(format: "%.2f", maxCarbs / carbRatio)
            }
            showAlert = true
        }
        
        if let maxBolus = UserDefaultsRepository.maxBolus as Double?,
           let bolusValueDouble = Double(bolusValue),
           bolusValueDouble > maxBolus {
            adjustedBolusValue = String(format: "%.2f", maxBolus)
            showAlert = true
        }
        
        if showAlert {
            let maxCarbsAlert = UIAlertController(title: "Maxgräns", message: "Måltidsregistreringen överskrider de inställda maxgränserna för kolhydrater och/eller bolus. \n\nDoseringen justeras därför ner till den tillåtna maxnivån i nästa steg...", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                self.proceedWithRemainingAmount(khValue: adjustedKhValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: adjustedBolusValue)
            }
            maxCarbsAlert.addAction(okAction)
            present(maxCarbsAlert, animated: true, completion: nil)
        } else {
            self.proceedWithRemainingAmount(khValue: adjustedKhValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: adjustedBolusValue)
        }
    }
    
    private func proceedWithRemainingAmount(khValue: String, fatValue: String, proteinValue: String, bolusValue: String) {
        let finalBolusValue = self.zeroBolus ? "0.0" : bolusValue
        if UserDefaultsRepository.method == "iOS Shortcuts" {
            if allowShortcuts {
                let alertController = UIAlertController(title: "Registrera slutdos för måltiden", message: "Vill du registrera de kolhydrater, fett och protein som ännu inte registreras i iAPS, och ge en bolus?", preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
                let yesAction = UIAlertAction(title: "Ja", style: .default) { _ in
                    self.registerRemainingAmountInIAPS(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: finalBolusValue)
                }
                alertController.addAction(cancelAction)
                alertController.addAction(yesAction)
                present(alertController, animated: true, completion: nil)
            } else {
                var alertMessage = "Registrera nu de kolhydrater som ännu inte registreras i iAPS, och ge en bolus enligt summeringen nedan:\n\n\(khValue) g kolhydrater"
                
                if let fat = Double(fatValue), fat > 0 {
                    alertMessage += "\n\(fatValue) g fett"
                }
                if let protein = Double(proteinValue), protein > 0 {
                    alertMessage += "\n\(proteinValue) g protein"
                }
                
                alertMessage += "\n\(finalBolusValue) E insulin"
                
                let alertController = UIAlertController(title: "Manuell registrering", message: alertMessage, preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
                let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                    self.updateRegisteredAmount(khValue: khValue)
                }
                alertController.addAction(cancelAction)
                alertController.addAction(okAction)
                present(alertController, animated: true, completion: nil)
            }
        } else {
            var alertMessage = "Vill du registrera måltiden i iAPS, och ge en bolus enligt summeringen nedan:\n\n\(khValue) g kolhydrater"
            
            if let fat = Double(fatValue), fat > 0 {
                alertMessage += "\n\(fatValue) g fett"
            }
            if let protein = Double(proteinValue), protein > 0 {
                alertMessage += "\n\(proteinValue) g protein"
            }
            
            alertMessage += "\n\(finalBolusValue) E insulin"
            
            let alertController = UIAlertController(title: "Registrera slutdos för måltiden", message: alertMessage, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                self.updateRegisteredAmount(khValue: khValue)
                let caregiverName = UserDefaultsRepository.caregiverName
                let remoteSecretCode = UserDefaultsRepository.remoteSecretCode
                let emojis = "🍽️" //self.getCombinedEmojis() // Fetch the combined emojis
                let currentDate = self.getCurrentDateUTC() // Get the current date in UTC format
                let combinedString = "Remote Måltid\nKolhydrater: \(khValue)g\nFett: \(fatValue)g\nProtein: \(proteinValue)g\nNotering: \(emojis)\nDatum: \(currentDate)\nInsulin: \(finalBolusValue)E\nInlagt av: \(caregiverName)\nHemlig kod: \(remoteSecretCode)"
                self.sendMealRequest(combinedString: combinedString)
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        }
    }
    
    func registerRemainingAmountInIAPS(khValue: String, fatValue: String, proteinValue: String, bolusValue: String) {
        var khValue = khValue.replacingOccurrences(of: ".", with: ",")
        var fatValue = fatValue.replacingOccurrences(of: ".", with: ",")
        var proteinValue = proteinValue.replacingOccurrences(of: ".", with: ",")
        var bolusValue = bolusValue.replacingOccurrences(of: ".", with: ",")
        let currentRegisteredValue = Double(totalRegisteredLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
        let remainsValue = Double(khValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let newRegisteredValue = currentRegisteredValue + remainsValue
        
        totalRegisteredLabel.text = String(format:"%.0f”", newRegisteredValue).replacingOccurrences(of: ",", with: ".")
        updateTotalNutrients()
        clearAllButton.isEnabled = true
        let urlString = "shortcuts://run-shortcut?name=Slutdos&input=text&text=kh_(khValue)bolus_(bolusValue)fat_(fatValue)protein_(proteinValue)"
        if let url = URL(string: urlString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    private func sendMealRequest(combinedString: String) {
        let method = UserDefaultsRepository.method
        if method == "iOS Shortcuts" {
            print("iOS shortcuts can not be combined with Twilio SMS API")
        } else {
            authenticateUser { [weak self] authenticated in
                guard let self = self else { return }
                if authenticated {
                    self.twilioRequest(combinedString: combinedString) { result in
                        switch result {
                        case .success:
                            AudioServicesPlaySystemSound(SystemSoundID(1322))
                            let alertController = UIAlertController(title: "Lyckades!", message: "Kommandot levererades till iAPS", preferredStyle: .alert)
                            alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                                self.dismiss(animated: true, completion: nil)
                            })
                            self.present(alertController, animated: true, completion: nil)
                        case .failure(let error):
                            AudioServicesPlaySystemSound(SystemSoundID(1053))
                            let alertController = UIAlertController(title: "Fel", message: error.localizedDescription, preferredStyle: .alert)
                            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            self.present(alertController, animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }
    
    private func updateRegisteredAmount(khValue: String) {
        let currentRegisteredValue = Double(totalRegisteredLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
        let remainsValue = Double(khValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let newRegisteredValue = currentRegisteredValue + remainsValue
        totalRegisteredLabel.text = String(format: "%.0f", newRegisteredValue).replacingOccurrences(of: ",", with: ".")
        updateTotalNutrients()
        clearAllButton.isEnabled = true
        if totalRegisteredLabel.text == "" {
            saveMealToHistory = false // Set false when totalRegisteredLabel becomes empty by send input
            //print ("saveMealToHistory = false")
        } else {
            saveMealToHistory = true // Set true when totalRegisteredLabel becomes non-empty by send input
            //print ("saveMealToHistory = true")
        }
    }
    
    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate with biometrics to proceed"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        // Authentication successful
                        completion(true)
                    } else {
                        // Check for passcode authentication if biometrics fail
                        if let error = authenticationError as NSError?,
                           error.code == LAError.biometryNotAvailable.rawValue || error.code == LAError.biometryNotEnrolled.rawValue || error.code == LAError.biometryLockout.rawValue {
                            // Biometry (Face ID or Touch ID) is not available, not enrolled, or locked out, use passcode
                            self.authenticateWithPasscode(completion: completion)
                        } else {
                            // Authentication failed
                            completion(false)
                        }
                    }
                }
            }
        } else {
            // Biometry is not available, use passcode
            authenticateWithPasscode(completion: completion)
        }
    }
    
    private func authenticateWithPasscode(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        let reason = "Authenticate with passcode to proceed"
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Passcode authentication successful
                    completion(true)
                } else {
                    // Passcode authentication failed
                    completion(false)
                }
            }
        }
    }
    
    private func createContainerView(backgroundColor: UIColor, borderColor: UIColor? = nil, borderWidth: CGFloat = 0) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = backgroundColor
        containerView.layer.cornerRadius = 8
        containerView.clipsToBounds = true
        if let borderColor = borderColor {
            containerView.layer.borderColor = borderColor.cgColor
            containerView.layer.borderWidth = borderWidth
        }
        return containerView
    }
    
    private func updateBorderColor() {
        let borderColor = UIColor.label.cgColor // Update border color based on the current theme
        remainsContainer?.layer.borderColor = borderColor
        startAmountContainer?.layer.borderColor = borderColor
        registeredContainer?.layer.borderColor = borderColor
        // Add any other container views that need the border color updated
    }
    
    private func createLabel(text: String, fontSize: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        label.textAlignment = .center
        return label
    }
    
    private func createTextField(placeholder: String, fontSize: CGFloat, weight: UIFont.Weight, color: UIColor) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        textField.textColor = color
        textField.textAlignment = .right
        textField.keyboardType = .decimalPad
        return textField
    }
    
    private func setupStackView(_ stackView: UIStackView, in containerView: UIView, padding: UIEdgeInsets) {
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding.left),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding.right),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding.top),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding.bottom)
        ])
    }
    
    private func updateTotalNutrients() {
        let totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }
        
        guard let totalNetCarbsLabel = totalNetCarbsLabel else {
            print("Error: totalNetCarbsLabel is nil")
            return
        }
        //print("updateTotalNutrients ran")
        
        totalNetCarbsLabel.text = String(format: "%.0f g", totalNetCarbs)
        
        let totalNetFat = foodItemRows.reduce(0.0) { $0 + $1.netFat }
        totalNetFatLabel.text = String(format: "%.0f g", totalNetFat)
        
        let totalNetProtein = foodItemRows.reduce(0.0) { $0 + $1.netProtein }
        totalNetProteinLabel.text = String(format: "%.0f g", totalNetProtein)
        
        let totalBolus = totalNetCarbs / scheduledCarbRatio
        let roundedBolus = roundDownToNearest05(totalBolus)
        totalBolusAmountLabel.text = formatNumber(roundedBolus) + " E"
        
        if totalNetCarbs > 0 && totalNetCarbs <= scheduledStartDose {
            totalStartAmountLabel.text = String(format: "%.0fg", totalNetCarbs)
            let totalStartAmount = Double(totalStartAmountLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0") ?? 0.0
            let startBolus = totalNetCarbs / scheduledCarbRatio
            let roundedStartBolus = roundDownToNearest05(startBolus)
            totalStartBolusLabel.text = formatNumber(roundedStartBolus) + "E"
        } else {
            totalStartAmountLabel.text = String(format: "%.0fg", scheduledStartDose)
            let totalStartAmount = Double(totalStartAmountLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0") ?? 0.0
            let startBolus = totalStartAmount / scheduledCarbRatio
            let roundedStartBolus = roundDownToNearest05(startBolus)
            totalStartBolusLabel.text = formatNumber(roundedStartBolus) + "E"
        }
        
        updateRemainsBolus()
        updateSaveFavoriteButtonState() // Add this line
    }

    private func formatNumber(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else if value * 10 == floor(value * 10) {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
    private func roundDownToNearest05(_ value: Double) -> Double {
        return (value * 20.0).rounded(.down) / 20.0
    }
    
    @objc private func registeredLabelDidChange() {
        updateRemainsBolus()
        updateClearAllButtonState()
        if totalRegisteredLabel.text == "" {
            saveMealToHistory = false // Set false when totalRegisteredLabel becomes empty by manual input
            //print ("saveMealToHistory = false")
        } else {
            saveMealToHistory = true // Set true when totalRegisteredLabel becomes non-empty by manual input
            //print ("saveMealToHistory = true")
        }
    }
    
    private func updateRemainsBolus() {
        let totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }

        let totalCarbsValue = Double(totalNetCarbs)
        
        if let registeredText = totalRegisteredLabel.text, let registeredValue = Double(registeredText) {
            let remainsValue = totalCarbsValue - registeredValue
            totalRemainsLabel.text = String(format: "%.0fg", remainsValue)
            
            let remainsBolus = roundDownToNearest05(remainsValue / scheduledCarbRatio)
            totalRemainsBolusLabel.text = String(format: "%.2fE", remainsBolus)
            if remainsValue < -0.5 {
                remainsLabel.text = "ÖVERDOS!"
            } else {
                remainsLabel.text = "+ SLUTDOS"
            }
            
            switch remainsValue {
            case -0.5...0.5:
                remainsContainer.backgroundColor = .systemGreen
            case let x where x > 0.5:
                remainsContainer.backgroundColor = .systemOrange
            default:
                remainsContainer.backgroundColor = .systemRed
            }
        } else {
            totalRemainsLabel.text = String(format: "%.0fg", totalCarbsValue)
            
            let remainsBolus = roundDownToNearest05(totalCarbsValue / scheduledCarbRatio)
            totalRemainsBolusLabel?.text = formatNumber(remainsBolus) + "E"
            
            remainsContainer?.backgroundColor = .systemGray
            remainsLabel?.text = "+ SLUTDOS"
        }
        
        let remainsText = totalRemainsLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0"
        let remainsValue = Double(remainsText) ?? 0.0
        
        switch remainsValue {
        case -0.5...0.5:
            remainsContainer.backgroundColor = .systemGreen
        case let x where x > 0.5:
            remainsContainer.backgroundColor = .systemOrange
        default:
            remainsContainer.backgroundColor = .systemRed
        }
    }
    
    private func setupHeadline(in container: UIView) {
        let headlineContainer = UIView()
        headlineContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headlineContainer)
        
        NSLayoutConstraint.activate([
            headlineContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 0),
            headlineContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headlineContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headlineContainer.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        let headlineStackView = UIStackView()
        headlineStackView.axis = .horizontal
        headlineStackView.spacing = 0
        headlineStackView.distribution = .fillProportionally
        headlineStackView.translatesAutoresizingMaskIntoConstraints = false
        headlineContainer.addSubview(headlineStackView)
        
        let font = UIFont.systemFont(ofSize: 10)
        
        foodItemLabel = UILabel()
        foodItemLabel.text = "LIVSMEDEL                    "
        foodItemLabel.textAlignment = .left
        foodItemLabel.font = font
        foodItemLabel.textColor = .gray
        
        portionServedLabel = UILabel()
        portionServedLabel.text = "PORTION"
        portionServedLabel.textAlignment = .left
        portionServedLabel.font = font
        portionServedLabel.textColor = .gray
        
        notEatenLabel = UILabel()
        notEatenLabel.text = "LÄMNAT"
        notEatenLabel.textAlignment = .right
        notEatenLabel.font = font
        notEatenLabel.textColor = .gray
        
        netCarbsLabel = UILabel()
        netCarbsLabel.text = "KOLHYDRATER"
        netCarbsLabel.textAlignment = .right
        netCarbsLabel.font = font
        netCarbsLabel.textColor = .gray
        headlineStackView.addArrangedSubview(foodItemLabel)
        headlineStackView.addArrangedSubview(portionServedLabel)
        headlineStackView.addArrangedSubview(notEatenLabel)
        headlineStackView.addArrangedSubview(netCarbsLabel)
        
        NSLayoutConstraint.activate([
            headlineStackView.leadingAnchor.constraint(equalTo: headlineContainer.leadingAnchor, constant: 16),
            headlineStackView.trailingAnchor.constraint(equalTo: headlineContainer.trailingAnchor, constant: -16),
            headlineStackView.topAnchor.constraint(equalTo: headlineContainer.topAnchor, constant: 16),
            headlineStackView.bottomAnchor.constraint(equalTo: headlineContainer.bottomAnchor)//, constant: -8)
        ])
    }
    
    private func updateHeadlineVisibility() {
        let isHidden = foodItemRows.isEmpty
        foodItemLabel.isHidden = isHidden
        portionServedLabel.isHidden = isHidden
        notEatenLabel.isHidden = isHidden
        netCarbsLabel.isHidden = isHidden
    }
    
    private func setupSearchableDropdownView() {
        searchableDropdownView = SearchableDropdownView()
        searchableDropdownView.translatesAutoresizingMaskIntoConstraints = false
        searchableDropdownView.isHidden = true
        view.addSubview(searchableDropdownView)
        
        NSLayoutConstraint.activate([
            searchableDropdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchableDropdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchableDropdownView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 120)
        ])
        
        // Store the bottom constraint
        searchableDropdownBottomConstraint = searchableDropdownView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        searchableDropdownBottomConstraint.isActive = true
        
        searchableDropdownView.onDoneButtonTapped = { [weak self] selectedItems in
            self?.searchableDropdownView.isHidden = true
            
            if selectedItems.isEmpty {
                // No items were added, update the "Clear All" button state
                self?.updateClearAllButtonState()
                return
            }
            
            selectedItems.forEach { self?.addFoodItemRow(with: $0) }
            self?.clearAllButton.isEnabled = true
            self?.updateHeadlineVisibility()
            
            // Hide the dropdown and update the navigation bar
            self?.hideSearchableDropdown()
        }
    }
    
    
    func hideSearchableDropdown() {
        searchableDropdownView.isHidden = true
        navigationItem.rightBarButtonItem = clearAllButton // Show "Rensa måltid" button again
        clearAllButton.isHidden = false // Unhide the "Rensa måltid" button
    }
    
    @objc private func searchableDropdownViewDidDismiss() {
        // Ensure the "Clear All" button is updated when the dropdown is dismissed
        updateClearAllButtonState()
    }
    
    // Call this method when the dropdown view is hidden
    private func hideSearchableDropdownView() {
        searchableDropdownView.isHidden = true
        searchableDropdownView.searchBar.resignFirstResponder()
        searchableDropdownViewDidDismiss()
    }
    
    @objc private func addFromSearchableDropdownButtonTapped() {
        searchableDropdownView.completeSelection()
    }
    
    public func fetchFoodItems() {
        let context = CoreDataStack.shared.context
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        do {
            foodItems = try context.fetch(fetchRequest).sorted { ($0.name ?? "") < ($1.name ?? "") }
            searchableDropdownView?.updateFoodItems(foodItems)
            print("fetchfooditems ran")
        } catch {
            print("Failed to fetch food items: \(error)")
        }
    }
    
    func addFoodItemRow(with foodItem: FoodItem? = nil) {
        guard let stackView = stackView else {
            print("stackView is nil")
            return
        }
        
        let rowView = FoodItemRowView()
        rowView.foodItems = foodItems
        rowView.delegate = self
        rowView.translatesAutoresizingMaskIntoConstraints = false
        stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count - 1)
        foodItemRows.append(rowView)
        
        if let foodItem = foodItem {
            rowView.setSelectedFoodItem(foodItem)
        }
        
        rowView.onDelete = { [weak self] in
            self?.removeFoodItemRow(rowView)
        }
        
        rowView.onValueChange = { [weak self] in
            self?.updateTotalNutrients()
        }
        
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
    
    private func addAddButtonRow() {
        addButtonRowView = AddButtonRowView()
        addButtonRowView.translatesAutoresizingMaskIntoConstraints = false
        addButtonRowView.addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        stackView.addArrangedSubview(addButtonRowView)
    }
    
    @objc private func addButtonTapped() {
        if searchableDropdownView.superview == nil {
            view.addSubview(searchableDropdownView)
            NSLayoutConstraint.activate([
                searchableDropdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                searchableDropdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                searchableDropdownView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                searchableDropdownView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            ])
        }
        
        searchableDropdownView.isHidden = false
        navigationItem.rightBarButtonItem = addFromSearchableDropdownButton // Show "Lägg till" button
        clearAllButton.isHidden = true // Hide the "Rensa måltid" button
    }
    private func removeFoodItemRow(_ rowView: FoodItemRowView) {
        stackView.removeArrangedSubview(rowView)
        rowView.removeFromSuperview()
        if let index = foodItemRows.firstIndex(of: rowView) {
            foodItemRows.remove(at: index)
        }
        moveAddButtonRowToEnd()
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState() // Add this line
        updateHeadlineVisibility()
    }
    
    private func moveAddButtonRowToEnd() {
        stackView.removeArrangedSubview(addButtonRowView)
        stackView.addArrangedSubview(addButtonRowView)
    }
    
    private func addDoneButtonToKeyboard() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        // Create a UIButton with an SF symbol
        let symbolImage = UIImage(systemName: "keyboard.chevron.compact.down")
        let cancelButton = UIButton(type: .system)
        cancelButton.setImage(symbolImage, for: .normal)
        cancelButton.tintColor = .systemBlue // Change color if needed
        cancelButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24) // Adjust size if needed
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        let cancelBarButtonItem = UIBarButtonItem(customView: cancelButton)
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
        
        toolbar.setItems([cancelBarButtonItem, flexSpace, doneButton], animated: false)
        
        totalRegisteredLabel?.inputAccessoryView = toolbar
    }
    
    @objc private func doneButtonTapped() {
        totalRegisteredLabel?.resignFirstResponder()
        navigationItem.rightBarButtonItem = clearAllButton // Show "Rensa måltid" button again
        clearAllButton.isHidden = false // Unhide the "Rensa måltid" button
    }
    
    @objc private func cancelButtonTapped() {
        totalRegisteredLabel?.resignFirstResponder()
        searchableDropdownView.isHidden = true
        //navigationItem.rightBarButtonItem = clearAllButton // Show "Rensa måltid" button again
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let keyboardHeight = keyboardFrame.height
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        
        UIView.animate(withDuration: duration) {
            // Adjust the bottom constraint to the top of the keyboard
            self.searchableDropdownBottomConstraint.constant = -keyboardHeight + 85
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        
        UIView.animate(withDuration: duration) {
            // Reset the bottom constraint
            self.searchableDropdownBottomConstraint.constant = 0
            self.view.layoutIfNeeded()
        }
    }
    
    private func updateClearAllButtonState() {
        guard let clearAllButton = clearAllButton else {
            print("clearAllButton is nil")
            return
        }
        clearAllButton.isEnabled = !foodItemRows.isEmpty || !(totalRegisteredLabel.text?.isEmpty ?? true)
    }
    
    private func updateScheduledValuesUI() {
        guard let nowCRLabel = nowCRLabel,
              let totalStartAmountLabel = totalStartAmountLabel,
              let totalStartBolusLabel = totalStartBolusLabel else {
            print("Labels are not initialized")
            return
        }
        
        nowCRLabel.text = String(formatScheduledCarbRatio(scheduledCarbRatio))
        
        
        totalStartAmountLabel.text = String(format: "%.0fg", scheduledStartDose)
        
        let totalStartAmount = Double(totalStartAmountLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0") ?? 0.0
        let startBolus = roundDownToNearest05(totalStartAmount / scheduledCarbRatio)
        totalStartBolusLabel.text = String(format: "%.2fE", startBolus)
        updateRemainsBolus()
    }
    
    func didTapNextButton(_ rowView: FoodItemRowView, currentTextField: UITextField) {
        if let currentIndex = foodItemRows.firstIndex(of: rowView) {
            let nextIndex = currentIndex + 1
            if nextIndex < foodItemRows.count {
                let nextRowView = foodItemRows[nextIndex]
                if currentTextField == rowView.portionServedTextField {
                    nextRowView.portionServedTextField.becomeFirstResponder()
                } else if currentTextField == rowView.notEatenTextField {
                    nextRowView.notEatenTextField.becomeFirstResponder()
                }
            }
        }
    }
    /*
     func didAddFoodItem() {
     fetchFoodItems()
     }*/
    
    @objc private func lateBreakfastSwitchChanged(_ sender: UISwitch) {
        lateBreakfast = sender.isOn
        UserDefaults.standard.set(lateBreakfast, forKey: "lateBreakfast")
        
        if lateBreakfast {
            scheduledCarbRatio /= lateBreakfastFactor
        } else {
            updatePlaceholderValuesForCurrentHour()
        }
        
        updateScheduledValuesUI()
        updateTotalNutrients()
    }
    
    // Modify the AddButtonRowView class to include a checkbox
    class AddButtonRowView: UIView {
        let addButton: UIButton = {
            let button = UIButton(type: .system)
            button.setTitle("   + VÄLJ LIVSMEDEL   ", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .systemBlue
            button.translatesAutoresizingMaskIntoConstraints = false
            button.layer.cornerRadius = 14
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.label.cgColor
            button.clipsToBounds = true
            return button
        }()
        
        let lateBreakfastSwitch: UISwitch = {
            let toggle = UISwitch()
            toggle.onTintColor = .systemBlue
            toggle.translatesAutoresizingMaskIntoConstraints = false
            return toggle
        }()
        
        let lateBreakfastLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            label.text = "SEN FRUKOST"
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupView()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupView() {
            addSubview(addButton)
            addSubview(lateBreakfastSwitch)
            addSubview(lateBreakfastLabel)
            
            NSLayoutConstraint.activate([
                addButton.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -90),
                addButton.topAnchor.constraint(equalTo: topAnchor, constant: 12),
                addButton.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
                addButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
                addButton.heightAnchor.constraint(equalToConstant: 32),
                addButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
                
                //lateBreakfastSwitch.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 24),
                lateBreakfastLabel.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
                lateBreakfastLabel.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 34),
                
                lateBreakfastSwitch.centerYAnchor.constraint(equalTo: lateBreakfastLabel.centerYAnchor),
                lateBreakfastSwitch.leadingAnchor.constraint(equalTo: lateBreakfastLabel.trailingAnchor, constant: 8)
            ])
            updateBorderColor() // Ensure border color is set correctly initially
        }
        
        func updateBorderColor() {
            addButton.layer.borderColor = UIColor.label.cgColor
        }
    }
}
    
    extension ComposeMealViewController: AddFoodItemDelegate {
        func didAddFoodItem() {
            fetchFoodItems()
            updateClearAllButtonState()
            updateSaveFavoriteButtonState()
            updateHeadlineVisibility()
        }
    }

  
