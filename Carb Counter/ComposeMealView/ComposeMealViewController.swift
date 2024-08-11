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
import QuartzCore
import SwiftUI


class ComposeMealViewController: UIViewController, FoodItemRowViewDelegate, UITextFieldDelegate, TwilioRequestable, MealViewControllerDelegate, RSSFeedDelegate {
    static weak var current: ComposeMealViewController?
    static var shared: ComposeMealViewController?
    
    ///Views
    var foodItemRows: [FoodItemRowView] = []
    var searchableDropdownViewController: SearchableDropdownViewController!
    var stackView: UIStackView!
    var scrollView: UIScrollView!
    var contentView: UIView!
    var addButtonRowView: AddButtonRowView!
    private var scrollViewBottomConstraint: NSLayoutConstraint?
    //private var contentViewBottomConstraint: NSLayoutConstraint?
    private var addButtonRowViewBottomConstraint: NSLayoutConstraint?
    
    ///Buttons
    var clearAllButton: UIBarButtonItem!
    var saveFavoriteButton: UIButton!
    var addFromSearchableDropdownButton: UIBarButtonItem!
    
    ///Summary labels
    var totalBolusAmountLabel: UILabel!
    var totalNetCarbsLabel: UILabel!
    var totalNetFatLabel: UILabel!
    var totalNetProteinLabel: UILabel!
    
    ///Treatment labels
    var crLabel: UILabel!
    var nowCRLabel: UILabel!
    var startAmountContainer: UIView!
    var totalStartAmountLabel: UILabel!
    var totalStartBolusLabel: UILabel!
    var remainsContainer: UIView!
    var remainsLabel: UILabel!
    var totalRemainsLabel: UILabel!
    var totalRemainsBolusLabel: UILabel!
    var registeredContainer: UIView!
    var totalRegisteredLabel: UITextField!
    
    ///Meal food item rows  labels
    var foodItemLabel: UILabel!
    var portionServedLabel: UILabel!
    var notEatenLabel: UILabel!
    var netCarbsLabel: UILabel!
    
    ///Data and states
    var foodItems: [FoodItem] = []
    var matchedFoodItems: [FoodItem] = []
    var scheduledStartDose = Double(20)
    var scheduledCarbRatio = Double(25)
    var allowShortcuts: Bool = false
    var saveMealToHistory: Bool = false
    var zeroBolus: Bool = false
    var lateBreakfast: Bool = false
    var lateBreakfastFactor = Double(1.5)
    private var lateBreakfastTimer: Timer?
    private let lateBreakfastDuration: TimeInterval = 90 * 60 // 90 minutes in seconds
    var startDoseGiven: Bool = false
    var remainingDoseGiven: Bool = false
    var dataSharingVC: DataSharingViewController?
    var mealEmojis: String? = "🍴"
    var mealDate: Date?
    var registeredFatSoFar = Double(0.0)
    var registeredProteinSoFar = Double(0.0)
    var registeredBolusSoFar = Double(0.0)
    var registeredCarbsSoFar = Double(0.0)
    
    ///Meal monitoring
    var exportTimer: Timer?
    private var isEditingMeal = false {
        didSet {
            if isEditingMeal {
                UserDefaultsRepository.allowViewingOngoingMeals = false
                startAutoSaveToCSV()
            } else {
                UserDefaultsRepository.allowViewingOngoingMeals = true
                stopAutoSaveToCSV()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadValuesFromUserDefaults()
        initializeUIElements()
        ComposeMealViewController.current = self
        ComposeMealViewController.shared = self
        
        ///Create the gradient view
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
        
        title = "Måltid"
        
        ///Setup the fixed header containing summary and headline
        let fixedHeaderContainer = UIView()
        fixedHeaderContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fixedHeaderContainer)
        NSLayoutConstraint.activate([
            fixedHeaderContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            fixedHeaderContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fixedHeaderContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fixedHeaderContainer.heightAnchor.constraint(equalToConstant: 143)
        ])
        
        ///Reset lateBreakfast to false
        UserDefaultsRepository.lateBreakfast = false
        lateBreakfast = false
        
        /// Ensure addButtonRowView is initialized
        addButtonRowView = AddButtonRowView()
        updatePlaceholderValuesForCurrentHour()
        lateBreakfastFactor = UserDefaultsRepository.lateBreakfastFactor
        lateBreakfast = UserDefaultsRepository.lateBreakfast
        addButtonRowView.lateBreakfastSwitch.isOn = lateBreakfast
        if lateBreakfast {
            scheduledCarbRatio /= lateBreakfastFactor
        }
        updateScheduledValuesUI()
        
        setupSummaryView(in: fixedHeaderContainer)
        setupTreatmentView(in: fixedHeaderContainer)
        setupHeadline(in: fixedHeaderContainer)
        setupScrollView(below: fixedHeaderContainer)
        setupAddButtonRowView() 
        
        /// Initializing
        clearAllButton = UIBarButtonItem(title: "Avsluta måltid", style: .plain, target: self, action: #selector(clearAllButtonTapped))
        clearAllButton.tintColor = .red
        navigationItem.rightBarButtonItem = clearAllButton
        
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
        
        ///Inital fetch
        self.fetchFoodItems()
        totalRegisteredLabel.delegate = self
        loadFoodItemsFromCoreData()
        NotificationCenter.default.addObserver(self, selector: #selector(allowShortcutsChanged), name: Notification.Name("AllowShortcutsChanged"), object: nil)
        allowShortcuts = UserDefaultsRepository.allowShortcuts
        
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
        saveFavoriteButton.isEnabled = false
        saveFavoriteButton.tintColor = .gray
        
        let stackView = UIStackView(arrangedSubviews: [historyButton, showFavoriteMealsButton, saveFavoriteButton])
        stackView.axis = .horizontal
        stackView.spacing = 20
        
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
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(lateBreakfastLabelTapped))
        addButtonRowView.lateBreakfastLabel.addGestureRecognizer(tapGesture)
        
        // Register for keyboard notifications
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
            
        
        NotificationCenter.default.addObserver(self, selector: #selector(allowViewingOngoingMealsChanged), name: .allowViewingOngoingMealsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didTakeoverRegistration(_:)), name: .didTakeoverRegistration, object: nil)
        addButtonRowView.lateBreakfastSwitch.addTarget(self, action: #selector(lateBreakfastSwitchChanged(_:)), for: .valueChanged)
        totalRegisteredLabel.addTarget(self, action: #selector(totalRegisteredLabelDidChange), for: .editingChanged)
        dataSharingVC = DataSharingViewController()
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
        
        // Check if the late breakfast switch should be off
        if let startTime = UserDefaultsRepository.lateBreakfastStartTime {
            print("Override CR was activated: \(startTime)")
            let timeInterval = Date().timeIntervalSince(startTime)
            if timeInterval >= lateBreakfastDuration {
                addButtonRowView.lateBreakfastSwitch.isOn = false
                lateBreakfastSwitchChanged(addButtonRowView.lateBreakfastSwitch)
            } else {
                lateBreakfastTimer = Timer.scheduledTimer(timeInterval: lateBreakfastDuration - timeInterval, target: self, selector: #selector(turnOffLateBreakfastSwitch), userInfo: nil, repeats: false)
            }
        }
        
        // Ensure updateTotalNutrients is called after all initializations
        updateTotalNutrients()
        
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else { return }
        
        // Call the desired function
        print("Data import triggered")
        Task {
            await
            dataSharingVC.importAllCSVFiles()
        }
        fetchFoodItems()
        checkIfEditing()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if lateBreakfast {
            scheduledCarbRatio *= lateBreakfastFactor // Reset scheduledCarbRatio when leaving view
        }
        UserDefaultsRepository.scheduledCarbRatio = scheduledCarbRatio //Save carb ratio in user defaults
    }
    
    ///function to initialize UI elements
    private func initializeUIElements() {
        if totalRegisteredLabel == nil {
            totalRegisteredLabel = UITextField()
            totalRegisteredLabel.placeholder = "..."
            totalRegisteredLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            totalRegisteredLabel.textColor = .white
            totalRegisteredLabel.textAlignment = .right
            totalRegisteredLabel.keyboardType = .decimalPad
            //print("Debug - Initialized totalRegisteredLabel")
        }
        
        if clearAllButton == nil {
            clearAllButton = UIBarButtonItem(title: "Avsluta måltid", style: .plain, target: self, action: #selector(clearAllButtonTapped))
            clearAllButton.tintColor = .red
            navigationItem.rightBarButtonItem = clearAllButton
            //print("Debug - Initialized clearAllButton")
        }
        
        if saveFavoriteButton == nil {
            saveFavoriteButton = UIButton(type: .system)
            saveFavoriteButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
            saveFavoriteButton.addTarget(self, action: #selector(saveFavoriteMeals), for: .touchUpInside)
            saveFavoriteButton.isEnabled = false
            saveFavoriteButton.tintColor = .gray
            //print("Debug - Initialized saveFavoriteButton")
        }
    }
    
    private func formatNumberWithoutTrailingZero(_ number: Double) -> String {
        let formattedNumber = String(format: "%.1f", number)
        return formattedNumber.hasSuffix(".0") ? String(formattedNumber.dropLast(2)) : formattedNumber
    }
    
    private func getMealEmojis() -> String {
        return (mealEmojis ?? "🍽️").filter { !$0.isWhitespaceOrNewline }
    }
    
    private func createEmojiString() {
        let emojis = foodItemRows.compactMap { $0.selectedFoodItem?.emoji }
        if emojis.isEmpty {
            mealEmojis = "🍴" // Default emoji if no emojis are available
        } else {
            mealEmojis = removeDuplicateEmojis(from: emojis.joined().filter { !$0.isWhitespaceOrNewline })
        }
        print("mealEmojis updated: \(mealEmojis ?? "")")
    }
    
    private func removeDuplicateEmojis(from string: String) -> String {
        var uniqueEmojis = Set<Character>()
        return string.filter { uniqueEmojis.insert($0).inserted }
    }
    
    @objc private func totalRegisteredLabelDidChange(_ textField: UITextField) {
        if let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
            textField.text = text.replacingOccurrences(of: ",", with: ".")
        }

        if let text = totalRegisteredLabel.text, text.isEmpty {
            saveMealToHistory = false // Set false when totalRegisteredLabel becomes empty by manual input
            startDoseGiven = false
            remainingDoseGiven = false
            
            // Reset the variables to 0.0 and save to UserDefaults
            resetVariablesToDefault()
        } else {
            saveMealToHistory = true // Set true when totalRegisteredLabel becomes non-empty by manual input
            
            // If there's text in totalRegisteredLabel, try to convert it to a Double and assign it to registeredCarbsSoFar
            if let text = totalRegisteredLabel.text, let carbsValue = Double(text) {
                registeredCarbsSoFar = carbsValue
            } else {
                // If conversion fails, default to 0.0
                registeredCarbsSoFar = 0.0
            }
            
            // Save the current values to UserDefaults
            saveValuesToUserDefaults()
        }

        // Call additional update methods
        updateTotalNutrients()
        updateHeadlineVisibility()
        updateRemainsBolus()
        updateClearAllButtonState()
        saveToCoreData()
    }
    
    public func updateSaveFavoriteButtonState() {
        guard let saveFavoriteButton = saveFavoriteButton else {
            return
        }
        let isEnabled = !foodItemRows.isEmpty
        saveFavoriteButton.isEnabled = isEnabled
        saveFavoriteButton.tintColor = isEnabled ? .label : .gray
    }
    
    @objc private func registeredContainerTapped() {
        totalRegisteredLabel.becomeFirstResponder()
        hideAllDeleteButtons()
    }
    
    @objc private func allowViewingOngoingMealsChanged() {
        print("allowViewingOngoingMeals changed to: \(UserDefaultsRepository.allowViewingOngoingMeals)")
    }
    
    @objc private func showMealHistory() {
        let mealHistoryVC = MealHistoryViewController()
        navigationController?.pushViewController(mealHistoryVC, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .allowViewingOngoingMealsChanged, object: nil)
        if ComposeMealViewController.current === self {
            ComposeMealViewController.current = nil
        }
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
    
    func didSelectFoodItems(_ foodItems: [FoodItem]) {
        // clearAllFoodItems() // Uncomment this if you want to reset before adding new items

        // Update your UI with the newly selected food items
        populateWithMatchedFoodItems(foodItems)
        
        // Print the selected food items (for debugging purposes)
        print("Selected food items: \(foodItems)")

    }
    
    func populateWithMatchedFoodItems(_ matchedFoodItems: [FoodItem]) {
        // clearAllFoodItems() // Uncomment if you want to reset the view before adding new items
        
        for matchedFoodItem in matchedFoodItems {
            if let existingFoodItem = foodItems.first(where: { $0.name == matchedFoodItem.name }) {
                // If the item is already present, configure and add its row view
                let rowView = FoodItemRowView()
                rowView.foodItems = foodItems
                rowView.delegate = self
                rowView.translatesAutoresizingMaskIntoConstraints = false
                let index = stackView.arrangedSubviews.isEmpty ? 0 : stackView.arrangedSubviews.count - 1
                stackView.insertArrangedSubview(rowView, at: index)
                foodItemRows.append(rowView)
                
                // Set the selected food item in the row view
                rowView.setSelectedFoodItem(existingFoodItem)
                rowView.portionServedTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
                
                // Set up the delete and value change handlers
                rowView.onDelete = { [weak self] in
                    self?.removeFoodItemRow(rowView)
                }
                
                rowView.onValueChange = { [weak self] in
                    self?.updateTotalNutrients()
                    self?.updateHeadlineVisibility()
                }
                
                // Calculate nutrients based on the selected food item and portion size
                rowView.calculateNutrients()
            } else {
                // Handle the case where a matched food item is not found in the current foodItems list
                print("Food item with name \(matchedFoodItem.name ?? "") not found in foodItems.")
            }
        }
        
        // Update UI elements and visibility based on the newly added food items
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
    
    func populateWithFavoriteMeal(_ favoriteMeal: FavoriteMeals) {
        //clearAllFoodItems() //Commented out to keep current registeredsofar carbs and bolus as well as food item rows even when adding a favorite meal
        
        guard let itemsString = favoriteMeal.items as? String else {
            print("Error: Unable to cast favoriteMeal.items to String.")
            return
        }
        
        print("Items String: \(itemsString)")
        
        guard let data = itemsString.data(using: .utf8) else {
            print("Error: Unable to convert itemsString to Data.")
            return
        }
        
        do {
            guard let items = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                print("Error: Unable to cast deserialized JSON to [[String: Any]].")
                return
            }
            
            for item in items {
                if let name = item["name"] as? String,
                   let portionServedString = item["portionServed"] as? String,
                   let portionServed = Double(portionServedString) {
                    //print("Item name: \(name), Portion Served: \(portionServed)")
                    if let foodItem = foodItems.first(where: { $0.name == name }) {
                        //print("Food Item Found: \(foodItem.name ?? "")")
                        let rowView = FoodItemRowView()
                        rowView.foodItems = foodItems
                        rowView.delegate = self
                        rowView.translatesAutoresizingMaskIntoConstraints = false
                        let index = stackView.arrangedSubviews.isEmpty ? 0 : stackView.arrangedSubviews.count - 1
                        stackView.insertArrangedSubview(rowView, at: index)
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
        } catch {
            print("Error deserializing JSON: \(error)")
        }
        
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
    
    func populateWithMealHistory(_ mealHistory: MealHistory) {
        //clearAllFoodItems() //Commented out to keep registeredsofar carbs and bolus as well as food item rows even when adding a history meal
        
        for foodEntry in mealHistory.foodEntries?.allObjects as? [FoodItemEntry] ?? [] {
            if let foodItem = foodItems.first(where: { $0.name == foodEntry.entryName }) {
                let rowView = FoodItemRowView()
                rowView.foodItems = foodItems
                rowView.delegate = self
                rowView.translatesAutoresizingMaskIntoConstraints = false
                let index = stackView.arrangedSubviews.isEmpty ? 0 : stackView.arrangedSubviews.count - 1
                stackView.insertArrangedSubview(rowView, at: index)
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
        guard clearAllButton != nil else {
            //print("clearAllButton is nil")
            return
        }
        view.endEditing(true)
        
        let alertController = UIAlertController(title: "Avsluta Måltid", message: "Bekräfta att du vill rensa alla valda livsmedel och inmatade värden för denna måltid. \nÅtgärden kan inte ångras.", preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        let yesAction = UIAlertAction(title: "Rensa", style: .destructive) { _ in
            if self.saveMealToHistory {
                self.saveMealHistory() // Save MealHistory if the flag is true
            }
            self.clearAllFoodItems()
            self.updateRemainsBolus()
            self.updateTotalNutrients()
            self.clearAllButton.isEnabled = false
            self.clearAllFoodItemRowsFromCoreData()
            self.startDoseGiven = false
            self.remainingDoseGiven = false
            self.isEditingMeal = false
            //print("Clear button tapped and isEditingMeal set to false")
            self.stopAutoSaveToCSV()
            if UserDefaultsRepository.allowSharingOngoingMeals {
                self.exportBlankCSV()
            }
            self.lateBreakfastTimer?.invalidate()
            self.turnOffLateBreakfastSwitch()
        }
        alertController.addAction(cancelAction)
        alertController.addAction(yesAction)
        present(alertController, animated: true, completion: nil)
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
        
        // Reset the variables to 0.0 and save to UserDefaults
        resetVariablesToDefault()
        
        updateRemainsBolus()
        
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
        remainsLabel.text = "+ RESTERANDE"
    }
    
    private func exportBlankCSV() {
        let blankCSVString = "foodItemID;portionServed;notEaten;registeredCarbsSoFar;registeredFatSoFar;registeredProteinSoFar;registeredBolusSoFar\n"
        saveCSV(data: blankCSVString, fileName: "OngoingMeal.csv")
        print("Blank ongoing meal CSV export done")
    }
    
    private func saveCSV(data: String, fileName: String) {
        guard let dataSharingVC = dataSharingVC else { return }
        Task {
            await
            dataSharingVC.saveCSV(data: data, fileName: fileName)
        }
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        adjustForKeyboard(notification: notification, keyboardShowing: true)
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        adjustForKeyboard(notification: notification, keyboardShowing: false)
    }

    private func adjustForKeyboard(notification: NSNotification, keyboardShowing: Bool) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height

        if keyboardShowing {
            // Adjust constraints when the keyboard is shown
            scrollViewBottomConstraint?.constant = -(keyboardHeight + 50)
            addButtonRowViewBottomConstraint?.constant = -(keyboardHeight - 88)
        } else {
            // Reset constraints when the keyboard is hidden
            scrollViewBottomConstraint?.constant = -150
            addButtonRowViewBottomConstraint?.constant = -10
        }

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    
    private func setupScrollView(below header: UIView) {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)
        
        scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -150)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollViewBottomConstraint!,
            
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),

            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
        
        setupStackView()
    }
    
    private func setupStackView() {
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
        
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
    
    private func setupAddButtonRowView() {
        addButtonRowView = AddButtonRowView()
        addButtonRowView.translatesAutoresizingMaskIntoConstraints = false
        addButtonRowView.addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        view.addSubview(addButtonRowView)
        
        addButtonRowViewBottomConstraint = addButtonRowView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        
        NSLayoutConstraint.activate([
            addButtonRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            addButtonRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            addButtonRowViewBottomConstraint!,
            addButtonRowView.heightAnchor.constraint(equalToConstant: 55)
        ])
    }
    
    private func setupSummaryView(in container: UIView) {
        let colors: [CGColor] = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor
        ]
        let summaryView = GradientView(colors: colors)
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(summaryView)
        
        let bolusContainer = createContainerView(backgroundColor: .systemBlue)
        summaryView.addSubview(bolusContainer)
        
        let bolusLabel = createLabel(text: "BOLUS", fontSize: 9, weight: .bold, color: .white)
        totalBolusAmountLabel = createLabel(text: "0.00 E", fontSize: 18, weight: .bold, color: .white)
        let bolusStack = UIStackView(arrangedSubviews: [bolusLabel, totalBolusAmountLabel])
        let bolusPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(bolusStack, in: bolusContainer, padding: bolusPadding)
        
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
        
        let carbsTapGesture = UITapGestureRecognizer(target: self, action: #selector(showCarbsInfo))
        carbsContainer.isUserInteractionEnabled = true
        carbsContainer.addGestureRecognizer(carbsTapGesture)
        
        let fatContainer = createContainerView(backgroundColor: .systemBrown)
        summaryView.addSubview(fatContainer)
        
        let netFatLabel = createLabel(text: "FETT", fontSize: 9, weight: .bold, color: .white)
        totalNetFatLabel = createLabel(text: "0.0 g", fontSize: 18, weight: .semibold, color: .white)
        let fatStack = UIStackView(arrangedSubviews: [netFatLabel, totalNetFatLabel])
        let fatPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(fatStack, in: fatContainer, padding: fatPadding)
        
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
    
    @objc private func showAddFoodItemViewController() {
        let addFoodItemVC = AddFoodItemViewController()
        addFoodItemVC.delegate = self
        navigationController?.pushViewController(addFoodItemVC, animated: true)
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
        let colors: [CGColor] = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor
        ]
        let treatmentView = GradientView(colors: colors)
        treatmentView.translatesAutoresizingMaskIntoConstraints = false
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
        
        let crTapGesture = UITapGestureRecognizer(target: self, action: #selector(showCRInfo))
        crContainer.isUserInteractionEnabled = true
        crContainer.addGestureRecognizer(crTapGesture)
        
        remainsContainer = createContainerView(backgroundColor: .systemGreen, borderColor: .white, borderWidth: 2)
        treatmentView.addSubview(remainsContainer)
        let remainsTapGesture = UITapGestureRecognizer(target: self, action: #selector(remainContainerTapped))
        remainsContainer.addGestureRecognizer(remainsTapGesture)
        remainsContainer.isUserInteractionEnabled = true
        
        remainsLabel = createLabel(text: "HELA DOSEN", fontSize: 9, weight: .bold, color: .white)
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
        
        startAmountContainer = createContainerView(backgroundColor: .systemPurple, borderColor: .white, borderWidth: 2)
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
        
        registeredContainer = createContainerView(backgroundColor: .systemGray2, borderColor: .white, borderWidth: 2)
        treatmentView.addSubview(registeredContainer)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(registeredContainerTapped))
        registeredContainer.addGestureRecognizer(tapGesture)
        registeredContainer.isUserInteractionEnabled = true
        let registeredLabel = createLabel(text: "REGGADE KH", fontSize: 9, weight: .bold, color: .white)
        totalRegisteredLabel = createTextField(placeholder: "...", fontSize: 18, weight: .semibold, color: .white)
        
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
    
    @objc private func allowShortcutsChanged() {
        allowShortcuts = UserDefaultsRepository.allowShortcuts
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
    
    /// Core data functions
    
    func startAutoSaveToCSV() {
        if UserDefaultsRepository.allowSharingOngoingMeals {
            exportTimer?.invalidate()
            exportTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(exportToCSV), userInfo: nil, repeats: true)
            print("Auto-save to CSV started with a 30-second interval.")
        }
    }
    
    func stopAutoSaveToCSV() {
        exportTimer?.invalidate()
        exportTimer = nil
        print("Auto-save to CSV stopped.")
    }
    
    @objc func exportToCSV() {
        Task {
            await DataSharingViewController().exportOngoingMealToCSV()
        }
    }
    private func loadFoodItemsFromCoreData() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItemRow> = FoodItemRow.fetchRequest()
        
        do {
            let savedFoodItems = try context.fetch(fetchRequest)
            // clearAllFoodItems() //Not needed?
            
            for savedFoodItem in savedFoodItems {
                if let foodItemID = savedFoodItem.foodItemID,
                   let foodItem = foodItems.first(where: { $0.id == foodItemID }) {
                    
                    let rowView = FoodItemRowView()
                    rowView.foodItems = foodItems
                    rowView.delegate = self
                    rowView.translatesAutoresizingMaskIntoConstraints = false
                    rowView.foodItemRow = savedFoodItem
                    
                    rowView.setSelectedFoodItem(foodItem)
                    
                    let portionServedValue = formatNumber(savedFoodItem.portionServed)
                    rowView.portionServedTextField.text = portionServedValue == "0" ? nil : portionServedValue
                    
                    let notEatenValue = formatNumber(savedFoodItem.notEaten)
                    rowView.notEatenTextField.text = notEatenValue == "0" ? nil : notEatenValue
                    
                    let index = stackView.arrangedSubviews.isEmpty ? 0 : stackView.arrangedSubviews.count - 1
                    stackView.insertArrangedSubview(rowView, at: index)
                    foodItemRows.append(rowView)
                    
                    rowView.onDelete = { [weak self] in
                        self?.removeFoodItemRow(rowView)
                    }
                    
                    rowView.onValueChange = { [weak self] in
                        self?.updateTotalNutrients()
                    }
                    
                    rowView.calculateNutrients()
                }
            }
            loadValuesFromUserDefaults()
            
            // Set totalRegisteredLabel based on registeredCarbsSoFar
            let formattedLastValue = formatNumber(registeredCarbsSoFar)
            totalRegisteredLabel.text = formattedLastValue == "0" ? nil : formattedLastValue
            
            // Check if the formatted number is greater than 0
            if let textValue = totalRegisteredLabel.text, let numberValue = Double(textValue.replacingOccurrences(of: ",", with: "")), numberValue > 0 {
                saveMealToHistory = true // Set true when totalRegisteredLabel becomes non-empty
            } else {
                saveMealToHistory = false // Reset if the value is not greater than 0
            }
            
            // Ensure UI elements are initialized
            initializeUIElements()
            
            updateTotalNutrients()
            updateClearAllButtonState()
            updateSaveFavoriteButtonState()
            updateHeadlineVisibility()
        } catch {
            print("Debug - Failed to fetch FoodItemRows: \(error)")
        }
    }
    
    public func fetchFoodItems() {
        let context = CoreDataStack.shared.context
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        do {
            let foodItems = try context.fetch(fetchRequest).sorted { ($0.name ?? "") < ($1.name ?? "") }
            DispatchQueue.main.async {
                self.foodItems = foodItems
                self.searchableDropdownViewController?.updateFoodItems(foodItems)
                print("fetchfooditems ran")
            }
        } catch {
            DispatchQueue.main.async {
                print("Failed to fetch food items: \(error)")
            }
        }
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
    
    func saveToCoreData() {
        let context = CoreDataStack.shared.context
        
        for rowView in foodItemRows {
            if let foodItemRow = rowView.foodItemRow {
                foodItemRow.portionServed = Double(rowView.portionServedTextField.text ?? "0") ?? 0
                foodItemRow.notEaten = Double(rowView.notEatenTextField.text ?? "0") ?? 0
                foodItemRow.foodItemID = rowView.selectedFoodItem?.id

            } else {
                let foodItemRow = FoodItemRow(context: context)
                foodItemRow.portionServed = Double(rowView.portionServedTextField.text ?? "0") ?? 0
                foodItemRow.notEaten = Double(rowView.notEatenTextField.text ?? "0") ?? 0
                foodItemRow.foodItemID = rowView.selectedFoodItem?.id

                rowView.foodItemRow = foodItemRow

            }
        }
        
        do {
            try context.save()
            //print("Debug - Successfully saved FoodItemRows to Core Data")
        } catch {
            print("Debug - Failed to save FoodItemRows: \(error)")
        }
    }
    
    private func saveMealHistory() {
        guard !foodItemRows.isEmpty else {
            print("No food items to save.")
            return
        }
        
        let context = CoreDataStack.shared.context
        
        let mealHistory = MealHistory(context: context)
        mealHistory.id = UUID()
        mealHistory.mealDate = mealDate ?? Date()
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
        Task {
            await dataSharingVC.exportMealHistoryToCSV()
            print("Meal history export triggered")
        }
        
        saveMealToHistory = false // Reset the flag after saving
        mealDate = nil // Reset mealDate to nil after saving
    }
    
    @objc private func saveFavoriteMeals() {
        guard saveFavoriteButton != nil else {
            //print("saveFavoriteButton is nil")
            return
        }
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
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: items, options: [])
                let jsonString = String(data: jsonData, encoding: .utf8)
                favoriteMeals.items = jsonString as? NSObject
            } catch {
                print("Failed to serialize items to JSON: \(error)")
            }
            
            CoreDataStack.shared.saveContext()
            
            // Ensure dataSharingVC is instantiated
            guard let dataSharingVC = self.dataSharingVC else { return }
            
            // Call the desired function
            Task {
                await dataSharingVC.exportFavoriteMealsToCSV()
                print("Favorite meals export triggered")
            }
            
            let confirmAlert = UIAlertController(title: "Lyckades", message: "Måltiden har sparats som favorit.", preferredStyle: .alert)
            confirmAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(confirmAlert, animated: true)
        }
        
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        
        nameAlert.addAction(saveAction)
        nameAlert.addAction(cancelAction)
        
        present(nameAlert, animated: true)
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
        checkIfEditing()
    }
    
    private func hideAllDeleteButtons() {
        for row in foodItemRows {
            row.hideDeleteButton()
        }
    }
    ///OngoingMeal monitoring
    func startEditing() {
        guard !isEditingMeal else {
            return
        }
        isEditingMeal = true
        print("Start editing triggered. isEditingMeal set to \(isEditingMeal)")
        startAutoSaveToCSV()
    }
    
    func stopEditing() {
        print("Stop editing triggered. Checking if still editing...")
        checkIfEditing()
    }
    
    private func checkIfEditing() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItemRow> = FoodItemRow.fetchRequest()
        do {
            let foodItemRows = try context.fetch(fetchRequest)
            isEditingMeal = !foodItemRows.isEmpty
            print("Checked if editing. isEditingMeal set to \(isEditingMeal) with \(foodItemRows.count) food item rows.")
            if !isEditingMeal {
                stopAutoSaveToCSV()
            }
        } catch {
            print("Failed to fetch food item rows: \(error)")
        }
    }
    
    func exportFoodItemRows() -> [FoodItemRowData] {
        var foodItemRowData: [FoodItemRowData] = []
        
        for rowView in foodItemRows {
            if let foodItem = rowView.selectedFoodItem {
                let portionServed = Double(rowView.portionServedTextField.text ?? "") ?? 0.0
                let notEaten = Double(rowView.notEatenTextField.text ?? "") ?? 0.0
                let registeredCarbsSoFar = registeredCarbsSoFar
                let registeredFatSoFar = registeredFatSoFar
                let registeredProteinSoFar = registeredProteinSoFar
                let registeredBolusSoFar = registeredBolusSoFar
                
                let rowData = FoodItemRowData(
                    foodItemID: foodItem.id,
                    portionServed: portionServed,
                    notEaten: notEaten,
                    registeredCarbsSoFar: registeredCarbsSoFar,
                    registeredFatSoFar: registeredFatSoFar,
                    registeredProteinSoFar: registeredProteinSoFar,
                    registeredBolusSoFar: registeredBolusSoFar
                )
                foodItemRowData.append(rowData)
            }
        }
        
        return foodItemRowData
    }
    
    func saveValuesToUserDefaults() {
        UserDefaults.standard.set(registeredFatSoFar, forKey: "registeredFatSoFar")
        UserDefaults.standard.set(registeredProteinSoFar, forKey: "registeredProteinSoFar")
        UserDefaults.standard.set(registeredBolusSoFar, forKey: "registeredBolusSoFar")
        UserDefaults.standard.set(registeredCarbsSoFar, forKey: "registeredCarbsSoFar")
        UserDefaults.standard.synchronize() // Ensure the values are written to disk immediately
    }
    
    func loadValuesFromUserDefaults() {
        registeredFatSoFar = UserDefaults.standard.double(forKey: "registeredFatSoFar")
        registeredProteinSoFar = UserDefaults.standard.double(forKey: "registeredProteinSoFar")
        registeredBolusSoFar = UserDefaults.standard.double(forKey: "registeredBolusSoFar")
        registeredCarbsSoFar = UserDefaults.standard.double(forKey: "registeredCarbsSoFar")
    }
    
    private func resetVariablesToDefault() {
        registeredFatSoFar = 0.0
        registeredProteinSoFar = 0.0
        registeredBolusSoFar = 0.0
        registeredCarbsSoFar = 0.0
        
        // Save the reset values to UserDefaults
        saveValuesToUserDefaults()
        
        print("Variables reset to 0.0 and saved to UserDefaults")
    }
    
    @objc private func didTakeoverRegistration(_ notification: Notification) {
        if let importedRows = notification.userInfo?["foodItemRows"] as? [FoodItemRowData] {
            
            // Find the maximum registeredCarbsSoFar (and fat, protein & bolus so far) from the imported rows
            let maxregisteredCarbsSoFar = importedRows.map { $0.registeredCarbsSoFar }.max() ?? 0.0
            let maxRegisteredFatSoFar = importedRows.map { $0.registeredFatSoFar }.max() ?? 0.0
            let maxRegisteredProteinSoFar = importedRows.map { $0.registeredProteinSoFar }.max() ?? 0.0
            let maxRegisteredBolusSoFar = importedRows.map { $0.registeredBolusSoFar }.max() ?? 0.0
            
            for row in importedRows {
                if let foodItem = getFoodItemByID(row.foodItemID) {
                    addFoodItemRow(with: foodItem, portionServed: row.portionServed, notEaten: row.notEaten)
                }
            }
            
            // Set the totalRegisteredLabel text to the maximum registeredCarbsSoFar, and update the fat, protein and bolus so far variables
            totalRegisteredLabel.text = String(format: "%.0f", maxregisteredCarbsSoFar)
            registeredFatSoFar = maxRegisteredFatSoFar
            registeredProteinSoFar = maxRegisteredProteinSoFar
            registeredBolusSoFar = maxRegisteredBolusSoFar
            
            
            updateTotalNutrients()
            updateClearAllButtonState()
            updateSaveFavoriteButtonState()
            updateHeadlineVisibility()
        }
    }
    
    private func getFoodItemByID(_ id: UUID?) -> FoodItem? {
        guard let id = id else { return nil }
        
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let items = try context.fetch(fetchRequest)
            return items.first
        } catch {
            print("Failed to fetch FoodItem with id \(id): \(error)")
            return nil
        }
    }
    
    private func clearCurrentRows() {
        for row in foodItemRows {
            stackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        foodItemRows.removeAll()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
    
    private func addRow(for foodItem: FoodItem, portionServed: Double, notEaten: Double) {
        let rowView = FoodItemRowView()
        rowView.selectedFoodItem = foodItem
        rowView.portionServedTextField.text = "\(portionServed)"
        rowView.notEatenTextField.text = "\(notEaten)"
        
        foodItemRows.append(rowView)
        stackView.addArrangedSubview(rowView)
    }
    
    /// Registration of meal and remote commands
    @objc private func lateBreakfastSwitchToggled(_ sender: UISwitch) {
        if sender.isOn {
            handleLateBreakfastSwitchOn()
            self.startLateBreakfastTimer()
        }
    }
    
    private func handleLateBreakfastSwitchOn() {
        guard let overrideName = UserDefaultsRepository.lateBreakfastOverrideName else {
            print("No override name available")
            return
        }
        if UserDefaultsRepository.allowShortcuts {
            let caregiverName = UserDefaultsRepository.caregiverName
            let remoteSecretCode = UserDefaultsRepository.remoteSecretCode
            let combinedString = "Remote Override\n\(overrideName)\nInlagt av: \(caregiverName)\nHemlig kod: \(remoteSecretCode)"
            
            let alertTitle = "Aktivera override"
            let alertMessage = "\nVill du aktivera overriden \n'\(overrideName)' i iAPS/Trio?"
            
            let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
            let yesAction = UIAlertAction(title: "Ja", style: .default) { _ in
                self.sendOverrideRequest(combinedString: combinedString)
            }
            alertController.addAction(cancelAction)
            alertController.addAction(yesAction)
            present(alertController, animated: true, completion: nil)
        } else {
            let alertController = UIAlertController(title: "Manuell aktivering", message: "\nKom ihåg att aktivera overriden \n'\(overrideName)' i iAPS/Trio", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        }
    }
    
    private func startLateBreakfastTimer() {
        let currentDate = Date()
        UserDefaultsRepository.lateBreakfastStartTime = currentDate
        print("Override timer started at: \(currentDate)")
        lateBreakfastTimer?.invalidate()
        lateBreakfastTimer = Timer.scheduledTimer(timeInterval: lateBreakfastDuration, target: self, selector: #selector(turnOffLateBreakfastSwitch), userInfo: nil, repeats: false)
    }
    
    @objc private func turnOffLateBreakfastSwitch() {
        print("Override timer off")
        addButtonRowView.lateBreakfastSwitch.isOn = false
        lateBreakfastSwitchChanged(addButtonRowView.lateBreakfastSwitch)
    }
    
    private func sendOverrideRequest(combinedString: String) {
        if UserDefaultsRepository.method == "iOS Shortcuts" {
            guard let encodedString = combinedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                print("Failed to encode URL string")
                return
            }
            let urlString = "shortcuts://run-shortcut?name=CC%20Override&input=text&text=\(encodedString)"
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        } else {
            authenticateUser { [weak self] authenticated in
                guard let self = self else { return }
                if authenticated {
                    self.twilioRequest(combinedString: combinedString) { result in
                        switch result {
                        case .success:
                            AudioServicesPlaySystemSound(SystemSoundID(1322))
                            let alertController = UIAlertController(title: "Lyckades!", message: "\nKommandot levererades till iAPS/Trio", preferredStyle: .alert)
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

    @objc private func startAmountContainerTapped() {
        if mealDate == nil {
            mealDate = Date()
        }
        hideAllDeleteButtons()
        createEmojiString()
        
        let khValue = formatValue(totalStartAmountLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0")
        let fatValue = "0"
        let proteinValue = "0"
        let bolusValue = formatValue(totalStartBolusLabel.text?.replacingOccurrences(of: "E", with: "") ?? "0")
        let emojis = self.foodItemRows.isEmpty ? "⏱️" : self.getMealEmojis()
        let method: String
        if UserDefaultsRepository.method == "iOS Shortcuts" {
            method = "iOS Shortcuts"
        } else {
            method = "SMS API"
        }
        
        let bolusSoFar = String(format: "%.2f", registeredBolusSoFar)
        let bolusTotal = totalBolusAmountLabel.text?.replacingOccurrences(of: " E", with: "") ?? "0"
        let carbsSoFar = String(format: "%.0f", registeredCarbsSoFar)
        let carbsTotal = totalNetCarbsLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0"
        let fatSoFar = String(format: "%.0f", registeredFatSoFar)
        let fatTotal = totalNetFatLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0"
        let proteinSoFar = String(format: "%.0f", registeredProteinSoFar)
        let proteinTotal = totalNetProteinLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0"
        
        let cr = nowCRLabel.text?.replacingOccurrences(of: " g/E", with: "") ?? "0"
        
        let startDose = true
        let remainDose = false
        
        if !allowShortcuts {
            //Use alert when manually registering
            let alertController = UIAlertController(title: "Manuell registrering", message: "\nRegistrera nu den angivna startdosen för måltiden \(khValue) g kh och \(bolusValue) E insulin i iAPS/Trio", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                self.updateRegisteredAmount(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: bolusValue, startDose: true)
                self.startDoseGiven = true
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let mealVC = storyboard.instantiateViewController(withIdentifier: "MealViewController") as? MealViewController {
                mealVC.delegate = self
                let navigationController = UINavigationController(rootViewController: mealVC)
                navigationController.modalPresentationStyle = .pageSheet
                
                /*if #available(iOS 15.0, *) {
                 navigationController.sheetPresentationController?.detents = [.medium(), .large()]
                 }*/
                
                present(navigationController, animated: true, completion: {
                    mealVC.populateMealViewController(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: bolusValue, emojis: emojis, bolusSoFar: bolusSoFar, bolusTotal: bolusTotal, carbsSoFar: carbsSoFar, carbsTotal: carbsTotal, fatSoFar: fatSoFar, fatTotal: fatTotal, proteinSoFar: proteinSoFar, proteinTotal: proteinTotal, method: method, startDose: startDose, remainDose: remainDose, cr: cr)
                })
            }
        }
    }
    
    @objc private func remainContainerTapped() {
        if mealDate == nil {
            mealDate = Date()
        }
        hideAllDeleteButtons()
        createEmojiString()
        let remainsValue = Double(totalRemainsLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
        let bolusRemainsValue = Double(totalRemainsBolusLabel.text?.replacingOccurrences(of: "E", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
        
        if bolusRemainsValue < 0 {
            let bolusText = totalRemainsBolusLabel.text?.replacingOccurrences(of: "E", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ",", with: ".") ?? "0"
            let crText = nowCRLabel.text?.replacingOccurrences(of: " g/E", with: "").replacingOccurrences(of: ",", with: ".") ?? "0"
            if let bolusValue = Double(bolusText), let crValue = Double(crText) {
                let khValue = bolusValue * crValue
                let formattedKhValue = formatValue(String(format: "%.0f",khValue))
                let alert = UIAlertController(title: "Varning", message: "\nDu har registrerat mer insulin än det beräknade behovet! \n\nSe till att komplettera med \(formattedKhValue)g kolhydrater för att undvika ett lågt blodsocker!", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(okAction)
                present(alert, animated: true, completion: nil)
                return
            } else {
                print("Invalid input for calculation")
            }
        }
        else if remainsValue < 0 {
            let khValue = totalRemainsLabel.text?.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ",", with: ".") ?? "0"
            let alert = UIAlertController(title: "Varning", message: "\nDu har registrerat mer kolhydrater än vad som har ätits! \n\nSe till att komplettera med \(khValue) kolhydrater för att undvika ett lågt blodsocker!", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
            return
            
        }
        let khValue = formatValue(totalRemainsLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0")
        
        let totalFatValue = Double(totalNetFatLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0") ?? 0.0
        let fatValue = formatValue("\(totalFatValue - registeredFatSoFar)")
        
        let totalProteinValue = Double(totalNetProteinLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0") ?? 0.0
        let proteinValue = formatValue("\(totalProteinValue - registeredProteinSoFar)")
        
        let bolusValue = formatValue(totalRemainsBolusLabel.text?.replacingOccurrences(of: "E", with: "") ?? "0")
        
        var adjustedKhValue = khValue
        var adjustedBolusValue = self.zeroBolus ? "0.0" : bolusValue
        var showAlert = false
        
        if let maxCarbs = UserDefaultsRepository.maxCarbs as Double?,
           let khValueDouble = Double(khValue),
           khValueDouble > maxCarbs {
            adjustedKhValue = String(format: "%.0f", maxCarbs)
            if let carbRatio = Double(nowCRLabel.text?.replacingOccurrences(of: " g/E", with: "") ?? "0"),
               let currentBolusValue = Double(bolusValue) {
                let calculatedBolusValue = maxCarbs / carbRatio
                adjustedBolusValue = self.zeroBolus ? "0.0" : String(format: "%.2f", min(calculatedBolusValue, currentBolusValue))
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
            let maxCarbsAlert = UIAlertController(title: "Maxgräns", message: "\nMåltidsregistreringen överskrider de inställda maxgränserna för kolhydrater och/eller bolus. \n\nDoseringen justeras därför ner till den tillåtna maxnivån i nästa steg...", preferredStyle: .alert)
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
        let method: String
        if UserDefaultsRepository.method == "iOS Shortcuts" {
            method = "iOS Shortcuts"
        } else {
            method = "SMS API"
        }
        
        let emojis: String
        if self.startDoseGiven == true {
            emojis = "🍽️"
        } else {
            emojis = "\(self.getMealEmojis())🍽️"
        }
        
        let bolusSoFar = String(format: "%.2f", registeredBolusSoFar)
        let bolusTotal = totalBolusAmountLabel.text?.replacingOccurrences(of: " E", with: "") ?? "0"
        let carbsSoFar = String(format: "%.0f", registeredCarbsSoFar)
        let carbsTotal = totalNetCarbsLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0"
        let fatSoFar = String(format: "%.0f", registeredFatSoFar)
        let fatTotal = totalNetFatLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0"
        let proteinSoFar = String(format: "%.0f", registeredProteinSoFar)
        let proteinTotal = totalNetProteinLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0"
        
        let cr = nowCRLabel.text?.replacingOccurrences(of: " g/E", with: "") ?? "0"
        
        let startDose = true
        let remainDose = true
        
        if !allowShortcuts {
            var alertMessage = "\nRegistrera nu de kolhydrater som ännu inte registrerats i iAPS/Trio, och ge en bolus enligt summeringen nedan:\n\n• \(khValue) g kolhydrater"
            
            if let fat = Double(fatValue), fat > 0 {
                alertMessage += "\n• \(fatValue) g fett"
            }
            if let protein = Double(proteinValue), protein > 0 {
                alertMessage += "\n• \(proteinValue) g protein"
            }
            
            alertMessage += "\n• \(finalBolusValue) E insulin"
            
            let alertController = UIAlertController(title: "Manuell registrering", message: alertMessage, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                self.updateRegisteredAmount(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: finalBolusValue, startDose: false)
                self.remainingDoseGiven = true
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
            
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let mealVC = storyboard.instantiateViewController(withIdentifier: "MealViewController") as? MealViewController {
                mealVC.delegate = self
                let navigationController = UINavigationController(rootViewController: mealVC)
                navigationController.modalPresentationStyle = .pageSheet
                
                /*if #available(iOS 15.0, *) {
                 navigationController.sheetPresentationController?.detents = [.medium(), .large()]
                 }*/
                
                present(navigationController, animated: true, completion: {
                    mealVC.populateMealViewController(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: bolusValue, emojis: emojis, bolusSoFar: bolusSoFar, bolusTotal: bolusTotal, carbsSoFar: carbsSoFar, carbsTotal: carbsTotal, fatSoFar: fatSoFar, fatTotal: fatTotal, proteinSoFar: proteinSoFar, proteinTotal: proteinTotal, method: method, startDose: startDose, remainDose: remainDose, cr: cr)
                })
            }
        }
    }
    
    func didUpdateMealValues(khValue: String, fatValue: String, proteinValue: String, bolusValue: String, startDose: Bool) {
        print("updateRegisteredAmount function ran from delegate")
        updateRegisteredAmount(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: bolusValue, startDose: startDose)
    }
    
    public func updateRegisteredAmount(khValue: String, fatValue: String, proteinValue: String, bolusValue: String, startDose: Bool) {
        print("updateRegisteredAmount function ran")
        // Print the received values to verify they are passed correctly
        /*print("Received KH Value: \(khValue)")
        print("Received Fat Value: \(fatValue)")
        print("Received Protein Value: \(proteinValue)")
        print("Received Bolus Value: \(bolusValue)")
        print("Received Start Dose: \(startDose)")*/
        
        // Set the startDoseGiven variable based on the received startDose value
        self.startDoseGiven = startDose
        
        // Print the startDoseGiven value to confirm it is set correctly
        //print("Start Dose Given is set to: \(self.startDoseGiven)")
        
        let currentRegisteredValue = Double(totalRegisteredLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
        let remainsValue = Double(khValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let newRegisteredValue = currentRegisteredValue + remainsValue
        
        // Print the updated registeredCarbsSoFar
        //print("Updated Total Registered Value: \(newRegisteredValue)g")
        
        let fatDoubleValue = Double(fatValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let proteinDoubleValue = Double(proteinValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let bolusDoubleValue = Double(bolusValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let carbsDoubleValue = Double(khValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        
        registeredFatSoFar += fatDoubleValue
        registeredProteinSoFar += proteinDoubleValue
        registeredBolusSoFar += bolusDoubleValue
        registeredCarbsSoFar += carbsDoubleValue
        
        totalRegisteredLabel.text = String(format: "%.0f", registeredCarbsSoFar).replacingOccurrences(of: ",", with: ".")
        
        // Print the accumulated values for fat, protein, and bolus
        print("Accumulated Fat So Far: \(registeredFatSoFar)g")
        print("Accumulated Protein So Far: \(registeredProteinSoFar)g")
        print("Accumulated Bolus So Far: \(registeredBolusSoFar)E")
        print("Accumulated Carbs So Far: \(registeredCarbsSoFar)g")
        
        saveValuesToUserDefaults()
        saveToCoreData()
        updateTotalNutrients()
        clearAllButton.isEnabled = true
        
        if totalRegisteredLabel.text == "" {
            saveMealToHistory = false // Set false when totalRegisteredLabel becomes empty by send input
        } else {
            saveMealToHistory = true // Set true when totalRegisteredLabel becomes non-empty by send input
        }
        
        if UserDefaultsRepository.allowSharingOngoingMeals {
            self.exportToCSV()
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
    
    public func updateTotalNutrients() {
        let totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }
        
        guard let totalNetCarbsLabel = totalNetCarbsLabel else {
            print("Error: totalNetCarbsLabel is nil")
            return
        }

        totalNetCarbsLabel.text = String(format: "%.0f g", totalNetCarbs)
        
        let totalNetFat = foodItemRows.reduce(0.0) { $0 + $1.netFat }
        totalNetFatLabel.text = String(format: "%.0f g", totalNetFat)
        
        let totalNetProtein = foodItemRows.reduce(0.0) { $0 + $1.netProtein }
        totalNetProteinLabel.text = String(format: "%.0f g", totalNetProtein)
        
        let totalBolus = totalNetCarbs / scheduledCarbRatio
        let roundedBolus = roundDownToNearest05(totalBolus)
        totalBolusAmountLabel.text = formatNumber(roundedBolus) + " E"
        
        if  UserDefaultsRepository.useStartDosePercentage {
            let startDoseFactor = UserDefaultsRepository.startDoseFactor
            let totalStartAmount = totalNetCarbs * startDoseFactor
            totalStartAmountLabel.text = String(format: "%.0fg", totalStartAmount)
            let startBolus = totalStartAmount / scheduledCarbRatio
            let roundedStartBolus = roundDownToNearest05(startBolus)
            totalStartBolusLabel.text = formatNumber(roundedStartBolus) + "E"
        } else {
            if totalNetCarbs > 0 && totalNetCarbs <= scheduledStartDose {
                totalStartAmountLabel.text = String(format: "%.0fg", totalNetCarbs)
                let startBolus = totalNetCarbs / scheduledCarbRatio
                let roundedStartBolus = roundDownToNearest05(startBolus)
                totalStartBolusLabel.text = formatNumber(roundedStartBolus) + "E"
            } else {
                totalStartAmountLabel.text = String(format: "%.0fg", scheduledStartDose)
                let startBolus = scheduledStartDose / scheduledCarbRatio
                let roundedStartBolus = roundDownToNearest05(startBolus)
                totalStartBolusLabel.text = formatNumber(roundedStartBolus) + "E"
            }
        }
        
        updateRemainsBolus()
        updateSaveFavoriteButtonState()
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
    
    private func updateRemainsBolus() {
        let totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }
        let totalCarbsValue = Double(totalNetCarbs)
        let remainsTextString = self.startDoseGiven ? "+ KVAR ATT GE" : "+ HELA DOSEN"
        let remainsBolus = roundDownToNearest05(totalCarbsValue / scheduledCarbRatio) - registeredBolusSoFar
        
        if let registeredText = totalRegisteredLabel.text, let registeredValue = Double(registeredText) {
            let remainsValue = totalCarbsValue - registeredValue
            totalRemainsLabel.text = String(format: "%.0fg", remainsValue)
            
            let remainsBolus = roundDownToNearest05(totalCarbsValue / scheduledCarbRatio) - registeredBolusSoFar
            totalRemainsBolusLabel.text = String(format: "%.2fE", remainsBolus)
            
            if remainsValue < -0.5 || remainsBolus < -0.05 {
                remainsLabel.text = "ÖVERDOS!"
            } else {
                remainsLabel.text = remainsTextString
            }
            
            switch (remainsValue, remainsBolus) {
            case (-0.5...0.5, -0.05...0.05):
                remainsContainer.backgroundColor = .systemGreen
            case let (x, y) where x > 0.5 || y > 0.05:
                remainsContainer.backgroundColor = .systemOrange
            default:
                remainsContainer.backgroundColor = .systemRed
            }
        } else {
            totalRemainsLabel.text = String(format: "%.0fg", totalCarbsValue)
            
            totalRemainsBolusLabel?.text = formatNumber(remainsBolus) + "E"
            
            remainsContainer?.backgroundColor = .systemGray
            remainsLabel?.text = remainsTextString
        }
        
        let remainsText = totalRemainsLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0"
        let remainsValue = Double(remainsText) ?? 0.0
        
        switch (remainsValue, remainsBolus) {
        case (-0.5...0.5, -0.05...0.05):
            remainsContainer.backgroundColor = .systemGreen
        case let (x, y) where x > 0.5 || y > 0.05:
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
        
        let font = UIFont.systemFont(ofSize: 9)
        
        foodItemLabel = UILabel()
        foodItemLabel.text = "LIVSMEDEL"
        foodItemLabel.textAlignment = .left
        foodItemLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        foodItemLabel.font = font
        foodItemLabel.textColor = .gray
        
        portionServedLabel = UILabel()
        portionServedLabel.text = "PORTION"
        portionServedLabel.textAlignment = .left
        portionServedLabel.widthAnchor.constraint(equalToConstant: 69).isActive = true
        portionServedLabel.font = font
        portionServedLabel.textColor = .gray
        
        notEatenLabel = UILabel()
        notEatenLabel.text = "LÄMNAT"
        notEatenLabel.textAlignment = .left
        notEatenLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        notEatenLabel.font = font
        notEatenLabel.textColor = .gray
        
        netCarbsLabel = UILabel()
        netCarbsLabel.text = "KOLHYDR."
        netCarbsLabel.textAlignment = .right
        netCarbsLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
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
            headlineStackView.bottomAnchor.constraint(equalTo: headlineContainer.bottomAnchor, constant: -5)
        ])
    }
    
    public func updateHeadlineVisibility() {
        let isHidden = foodItemRows.isEmpty
        foodItemLabel.isHidden = isHidden
        portionServedLabel.isHidden = isHidden
        notEatenLabel.isHidden = isHidden
        netCarbsLabel.isHidden = isHidden
    }
    
    private func handleSelectedFoodItems(_ items: [FoodItem]) {
        for item in items {
            addFoodItemRow(with: item) // Defaults to portionServed: nil and notEaten: nil
        }
        updateTotalNutrients()
        updateHeadlineVisibility()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
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
        let index = stackView.arrangedSubviews.isEmpty ? 0 : stackView.arrangedSubviews.count - 1
        stackView.insertArrangedSubview(rowView, at: index)
        foodItemRows.append(rowView)
        
        //print("Added row at index: \(index), Total rows now: \(foodItemRows.count)")

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
        
        if !isEditingMeal {
            startEditing()
        }
        rowView.calculateNutrients()
    }
    
    private func addFoodItemRow(with foodItem: FoodItem, portionServed: Double? = nil, notEaten: Double? = nil) {
        let rowView = FoodItemRowView()
        rowView.foodItems = foodItems
        rowView.delegate = self
        rowView.translatesAutoresizingMaskIntoConstraints = false
        let index = stackView.arrangedSubviews.isEmpty ? 0 : stackView.arrangedSubviews.count - 1
        stackView.insertArrangedSubview(rowView, at: index)
        foodItemRows.append(rowView)
        rowView.setSelectedFoodItem(foodItem)
        
        // Only set the text fields if the values are not nil
        if let portionServed = portionServed {
            rowView.portionServedTextField.text = formattedValue(portionServed)
        }
        if let notEaten = notEaten {
            rowView.notEatenTextField.text = formattedValue(notEaten)
        }
        
        rowView.portionServedTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        rowView.notEatenTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        rowView.onDelete = { [weak self] in
            self?.removeFoodItemRow(rowView)
        }
        
        rowView.onValueChange = { [weak self] in
            self?.updateTotalNutrients()
            self?.updateHeadlineVisibility()
        }
        rowView.calculateNutrients()
    }
    
    @objc private func addButtonTapped() {
        let dropdownVC = SearchableDropdownViewController()
        dropdownVC.onDoneButtonTapped = { [weak self] selectedItems in
            self?.handleSelectedFoodItems(selectedItems)
        }
        let navigationController = UINavigationController(rootViewController: dropdownVC)
        navigationController.modalPresentationStyle = .formSheet
        present(navigationController, animated: true, completion: nil)
        
        hideAllDeleteButtons()
    }

    private func removeFoodItemRow(_ rowView: FoodItemRowView) {
        stackView.removeArrangedSubview(rowView)
        rowView.removeFromSuperview()
        if let index = foodItemRows.firstIndex(of: rowView) {
            foodItemRows.remove(at: index)
        }
        //moveAddButtonRowToEnd()
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
        
        // Check if foodItemRows is empty and allowSharingOngoingMeals is true before exporting blank CSV
        if foodItemRows.isEmpty {
            startDoseGiven = false
            remainingDoseGiven = false
            if UserDefaultsRepository.allowSharingOngoingMeals {
                exportBlankCSV()
            }
        }
    }
    
    private func addDoneButtonToKeyboard() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let symbolImage = UIImage(systemName: "keyboard.chevron.compact.down")
        let cancelButton = UIButton(type: .system)
        cancelButton.setImage(symbolImage, for: .normal)
        cancelButton.tintColor = .label
        cancelButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        let cancelBarButtonItem = UIBarButtonItem(customView: cancelButton)
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
        
        toolbar.setItems([cancelBarButtonItem, flexSpace, doneButton], animated: false)
        
        totalRegisteredLabel?.inputAccessoryView = toolbar
    }
    
    @objc private func doneButtonTapped() {
        totalRegisteredLabel?.resignFirstResponder()
        navigationItem.rightBarButtonItem = clearAllButton
        clearAllButton.isHidden = false
    }
    
    @objc private func cancelButtonTapped() {
        totalRegisteredLabel?.resignFirstResponder()
    }
    
    public func updateClearAllButtonState() {
        guard let clearAllButton = clearAllButton else {
            return
        }
        clearAllButton.isEnabled = !foodItemRows.isEmpty || !(totalRegisteredLabel.text?.isEmpty ?? true)
    }
    
    private func updateScheduledValuesUI() {
        guard let nowCRLabel = nowCRLabel,
              let totalStartAmountLabel = totalStartAmountLabel,
              let totalStartBolusLabel = totalStartBolusLabel else {
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
        guard let currentIndex = foodItemRows.firstIndex(of: rowView) else {
            print("Row not found in foodItemRows")
            return
        }

        let nextIndex = (currentIndex + 1) % foodItemRows.count
        //print("Current Index: \(currentIndex), Next Index: \(nextIndex), Total Rows: \(foodItemRows.count)")

        let nextRowView = foodItemRows[nextIndex]
        //print("Attempting to move to row: \(nextIndex)")

        DispatchQueue.main.async {
            if currentTextField == rowView.portionServedTextField {
                if nextRowView.portionServedTextField.becomeFirstResponder() {
                    //print("Successfully made portionServedTextField first responder for row \(nextIndex)")
                } else {
                    print("Failed to make portionServedTextField first responder for row \(nextIndex)")
                }
            } else if currentTextField == rowView.notEatenTextField {
                if nextRowView.notEatenTextField.becomeFirstResponder() {
                    //print("Successfully made notEatenTextField first responder for row \(nextIndex)")
                } else {
                    print("Failed to make notEatenTextField first responder for row \(nextIndex)")
                }
            }
            self.scrollView.scrollRectToVisible(nextRowView.frame, animated: true)
        }
    }
    
    @objc internal func rssButtonTapped() {
        let rssFeedVC = RSSFeedViewController()
                rssFeedVC.delegate = self
                let navigationController = UINavigationController(rootViewController: rssFeedVC)
                navigationController.modalPresentationStyle = .formSheet
                present(navigationController, animated: true, completion: nil)
        
        hideAllDeleteButtons()
            }
    
    @objc private func lateBreakfastSwitchChanged(_ sender: UISwitch) {
        lateBreakfast = sender.isOn
        UserDefaultsRepository.lateBreakfast = lateBreakfast
        
        if lateBreakfast {
            scheduledCarbRatio /= lateBreakfastFactor
        } else {
            updatePlaceholderValuesForCurrentHour()
        }
        
        updateScheduledValuesUI()
        updateTotalNutrients()
    }

    class AddButtonRowView: UIView {
        let addButton: UIButton = {
            let button = UIButton(type: .system)
            button.setTitle("+ VÄLJ I LISTA", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .systemBlue
            button.translatesAutoresizingMaskIntoConstraints = false
            button.layer.cornerRadius = 8
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.white.cgColor
            button.clipsToBounds = true
            return button
        }()
        
        let rssButton: UIButton = {
            let button = UIButton(type: .system)
            button.setTitle("+ SKOLMATEN", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .systemBlue.withAlphaComponent(0.3)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.layer.cornerRadius = 8
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.white.cgColor
            button.clipsToBounds = true
            button.addTarget(self, action: #selector(rssButtonTapped), for: .touchUpInside)
            return button
        }()
        
        let lateBreakfastSwitch: UISwitch = {
            let toggle = UISwitch()
            toggle.onTintColor = .systemBlue
            toggle.translatesAutoresizingMaskIntoConstraints = false
            toggle.addTarget(self, action: #selector(lateBreakfastSwitchToggled(_:)), for: .valueChanged)
            return toggle
        }()
        
        let lateBreakfastLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
            label.text = "     OVERRIDE     "
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false
            label.isUserInteractionEnabled = true
            return label
        }()
        
        let lateBreakfastContainer: UIView = {
            let view = UIView()
            view.backgroundColor = .systemBlue.withAlphaComponent(0.35)
            view.layer.cornerRadius = 8
            view.layer.borderWidth = 2
            view.layer.borderColor = UIColor.white.cgColor
            view.clipsToBounds = true
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupView()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupView() {
            // Create the container for the lateBreakfastSwitch and label
            let lateBreakfastContainer = UIView()
            lateBreakfastContainer.translatesAutoresizingMaskIntoConstraints = false
            lateBreakfastContainer.backgroundColor = .systemBlue.withAlphaComponent(0.35)
            lateBreakfastContainer.layer.cornerRadius = 8
            lateBreakfastContainer.layer.borderWidth = 2
            lateBreakfastContainer.layer.borderColor = UIColor.white.cgColor
            lateBreakfastContainer.clipsToBounds = true

            // Add label and switch to the container
            lateBreakfastContainer.addSubview(lateBreakfastLabel)
            lateBreakfastContainer.addSubview(lateBreakfastSwitch)

            // Adjust the switch's transform to make it smaller
            lateBreakfastSwitch.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)

            // Create the horizontal stack view (HStack)
            let stackView = UIStackView(arrangedSubviews: [addButton, rssButton, lateBreakfastContainer])
            stackView.axis = .horizontal
            stackView.alignment = .fill
            stackView.distribution = .fillEqually
            stackView.spacing = 8
            stackView.translatesAutoresizingMaskIntoConstraints = false

            // Add the stack view to the main view
            addSubview(stackView)

            // Set up constraints for the stack view
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                stackView.heightAnchor.constraint(equalToConstant: 44),
                stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
                
                // Align lateBreakfastLabel inside the container
                lateBreakfastLabel.topAnchor.constraint(equalTo: lateBreakfastContainer.topAnchor, constant: 4),
                lateBreakfastLabel.centerXAnchor.constraint(equalTo: lateBreakfastContainer.centerXAnchor),

                // Align lateBreakfastSwitch inside the container
                lateBreakfastSwitch.bottomAnchor.constraint(equalTo: lateBreakfastContainer.bottomAnchor),
                lateBreakfastSwitch.centerXAnchor.constraint(equalTo: lateBreakfastContainer.centerXAnchor),
            ])
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

class GradientView: UIView {
    
    private let gradientLayer = CAGradientLayer()
    
    init(colors: [CGColor]) {
        super.init(frame: .zero)
        gradientLayer.colors = colors
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

///Add popovers for info instead of alerts

struct InfoPopoverView: View {
    let title: String
    let message: String
    
    let backgroundColor = Color(red: 90/255, green: 104/255, blue: 125/255)
    
    var body: some View {
        ZStack {
            backgroundColor.opacity(0.7)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 12)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
            .padding()
        }
        .edgesIgnoringSafeArea(.all)
    }
}

class InfoPopoverHostingController: UIHostingController<InfoPopoverView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: InfoPopoverView(title: "", message: ""))
    }
    
    init(title: String, message: String) {
        let view = InfoPopoverView(title: title, message: message)
        super.init(rootView: view)
        modalPresentationStyle = .popover
        popoverPresentationController?.delegate = self
        
        // Dynamically calculate preferredContentSize
        let width: CGFloat = 300
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.layoutIfNeeded()
        let size = hostingController.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        preferredContentSize = CGSize(width: width, height: size.height)
    }
}

extension InfoPopoverHostingController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        dismiss(animated: true, completion: nil)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

extension ComposeMealViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

extension ComposeMealViewController {
    private func presentPopover(title: String, message: String, sourceView: UIView) {
        let popoverController = InfoPopoverHostingController(title: title, message: message)
        popoverController.modalPresentationStyle = .popover
        popoverController.popoverPresentationController?.sourceView = sourceView
        popoverController.popoverPresentationController?.sourceRect = sourceView.bounds
        popoverController.popoverPresentationController?.permittedArrowDirections = .any
        popoverController.popoverPresentationController?.delegate = self
        present(popoverController, animated: true, completion: nil)
    }
    
    @objc private func showBolusInfo() {
        presentPopover(title: "Bolus Total", message: "Den beräknade mängden insulin som krävs för att täcka kolhydraterna i måltiden.", sourceView: totalBolusAmountLabel)
    }
    
    @objc private func showCarbsInfo() {
        presentPopover(title: "Kolhydrater Totalt", message: "Den beräknade summan av alla kolhydrater i måltiden.", sourceView: totalNetCarbsLabel)
    }
    
    @objc private func showFatInfo() {
        presentPopover(title: "Fett Totalt", message: "Den beräknade summan av all fett i måltiden. \n\nFett kräver också insulin, men med några timmars fördröjning.", sourceView: totalNetFatLabel)
    }
    
    @objc private func showProteinInfo() {
        presentPopover(title: "Protein Totalt", message: "Den beräknade summan av all protein i måltiden. \n\nProtein kräver också insulin, men med några timmars fördröjning.", sourceView: totalNetProteinLabel)
    }
    
    @objc private func showCRInfo() {
        presentPopover(title: "Insulinkvot", message: "Även kallad Carb Ratio (CR)\n\nVärdet motsvarar hur stor mängd kolhydrater som 1 E insulin täcker.\n\n Exempel:\nCR 25 innebär att det behövs 2 E insulin till 50 g kolhydrater.", sourceView: nowCRLabel)
    }
    
    @objc private func lateBreakfastLabelTapped() {
        if let startTime = UserDefaultsRepository.lateBreakfastStartTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            let formattedDate = formatter.string(from: startTime)
            presentPopover(title: "Senaste override", message: "Aktiverades \(formattedDate)", sourceView: addButtonRowView.lateBreakfastLabel)
        } else {
            presentPopover(title: "Senaste override", message: "Ingen tidigare aktivering hittades.", sourceView: addButtonRowView.lateBreakfastLabel)
        }
    }
}

public extension Character {
    var isWhitespaceOrNewline: Bool {
        return isWhitespace || isNewline
    }
}
