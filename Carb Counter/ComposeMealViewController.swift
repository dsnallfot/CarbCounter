//
//  ComposeMealViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-17.
import UIKit
import CoreData

class ComposeMealViewController: UIViewController, FoodItemRowViewDelegate, AddFoodItemDelegate, UITextFieldDelegate {
    
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
    
    var scheduledStartDose = Double(20)
    var scheduledCarbRatio = Double(30)
    
    var foodItemLabel: UILabel!
    var portionServedLabel: UILabel!
    var notEatenLabel: UILabel!
    var netCarbsLabel: UILabel!
    
    var clearAllButton: UIBarButtonItem!
    var saveFavoriteButton: UIBarButtonItem!
    
    var allowShortcuts: Bool = false
    
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
        
        // Setup summary view
        setupSummaryView(in: fixedHeaderContainer)
        
        // Setup treatment view
        setupTreatmentView(in: fixedHeaderContainer)
        
        // Setup headline
        setupHeadline(in: fixedHeaderContainer)
        
        // Setup scroll view
        setupScrollView(below: fixedHeaderContainer)
        
        // Initialize "Clear All" button
        clearAllButton = UIBarButtonItem(title: "Rensa allt", style: .plain, target: self, action: #selector(clearAllButtonTapped))
        clearAllButton.tintColor = .red // Set the button color to red
        navigationItem.rightBarButtonItem = clearAllButton
        
        // Ensure searchableDropdownView is properly initialized
        setupSearchableDropdownView()
        
        // Fetch food items and add the add button row
        fetchFoodItems()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
        
        // Add observer for text changes in totalRegisteredLabel
        totalRegisteredLabel.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        // Set the delegate for the text field
        totalRegisteredLabel.delegate = self
        
        // Observe changes to allowShortcuts
        NotificationCenter.default.addObserver(self, selector: #selector(allowShortcutsChanged), name: Notification.Name("AllowShortcutsChanged"), object: nil)
        
        // Load allowShortcuts from UserDefaults
        allowShortcuts = UserDefaults.standard.bool(forKey: "allowShortcuts")
        
        // Add Favorites button
        let showFavoriteMealsImage = UIImage(systemName: "star")
        let showFavoriteMealsButton = UIBarButtonItem(image: showFavoriteMealsImage, style: .plain, target: self, action: #selector(showFavoriteMeals))
        
        // Add Save Favorite button
        let saveFavoriteImage = UIImage(systemName: "plus.circle")
        saveFavoriteButton = UIBarButtonItem(image: saveFavoriteImage, style: .plain, target: self, action: #selector(saveFavoriteMeals))
        saveFavoriteButton.isEnabled = false // Initially disabled
        
        // Set both buttons on the left side
        navigationItem.leftBarButtonItems = [showFavoriteMealsButton, saveFavoriteButton]
        
        // Add observers for keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.endEditing(true)
        updatePlaceholderValuesForCurrentHour()
        updateScheduledValuesUI()
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
        saveFavoriteButton.isEnabled = !foodItemRows.isEmpty
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
        
        let nameAlert = UIAlertController(title: "Spara favoritmåltid", message: "Ange ett namn på favoritmåltiden:", preferredStyle: .alert)
        nameAlert.addTextField { textField in
            textField.placeholder = "Namn"
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.autocapitalizationType = .none
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
                    let item = [
                        "name": foodItem.name ?? "",
                        "portionServed": row.portionServedTextField.text ?? ""
                    ]
                    items.append(item)
                }
            }
            favoriteMeals.items = items as NSObject
            
            CoreDataStack.shared.saveContext()
            
            let confirmAlert = UIAlertController(title: "Lyckades", message: "Måltiden har sparats som favorit.", preferredStyle: .alert)
            confirmAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(confirmAlert, animated: true)
        }
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        
        nameAlert.addAction(saveAction)
        nameAlert.addAction(cancelAction)
        
        present(nameAlert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func showFavoriteMeals() {
        let favoriteMealsVC = FavoriteMealsViewController()
        navigationController?.pushViewController(favoriteMealsVC, animated: true)
    }
    
    func populateWithFavoriteMeal(_ favoriteMeal: FavoriteMeals) {
        clearAllFoodItems()
        
        guard let items = favoriteMeal.items as? [[String: Any]] else { return }
        
        for item in items {
            if let name = item["name"] as? String,
               let portionServed = item["portionServed"] as? String {
                if let foodItem = foodItems.first(where: { $0.name == name }) {
                    let rowView = FoodItemRowView()
                    rowView.foodItems = foodItems
                    rowView.delegate = self
                    rowView.translatesAutoresizingMaskIntoConstraints = false
                    stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count - 1)
                    foodItemRows.append(rowView)
                    rowView.setSelectedFoodItem(foodItem)
                    rowView.portionServedTextField.text = portionServed
                    rowView.portionServedTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
                    
                    rowView.onDelete = { [weak self] in
                        self?.removeFoodItemRow(rowView)
                    }
                    
                    rowView.onValueChange = { [weak self] in
                        self?.updateTotalNutrients()
                        self?.updateHeadlineVisibility()
                    }
                    rowView.calculateNutrients()
                }
            }
        }
        updateTotalNutrients()
        updateClearAllButtonState()
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        if let text = textField.text {
            textField.text = text.replacingOccurrences(of: ",", with: ".")
        }
        updateTotalNutrients()
        updateHeadlineVisibility()
    }
    
    @objc private func clearAllButtonTapped() {
        view.endEditing(true)
        
        let alertController = UIAlertController(title: "Rensa allt", message: "Vill du rensa allt?", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        let yesAction = UIAlertAction(title: "Ja", style: .destructive) { _ in
            self.clearAllFoodItems()
            self.totalRegisteredLabel.text = ""
            self.updateTotalNutrients()
            self.clearAllButton.isEnabled = false // Disable the "Clear All" button
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
        updateSaveFavoriteButtonState() // Add this line
        updateHeadlineVisibility()
    }
    
    private func setupScrollView(below header: UIView) {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .systemBackground
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
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
        
        fetchFoodItems()
        updateClearAllButtonState()
        updateHeadlineVisibility()
        addAddButtonRow()
    }
    
    private func setupSummaryView(in container: UIView) {
        let summaryView = UIView()
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        summaryView.backgroundColor = .systemBackground
        container.addSubview(summaryView)
        
        let bolusContainer = createContainerView(backgroundColor: .systemBlue)
        summaryView.addSubview(bolusContainer)
        
        let bolusLabel = createLabel(text: "TOT BOLUS", fontSize: 10, weight: .bold, color: .white)
        totalBolusAmountLabel = createLabel(text: "0.00 E", fontSize: 18, weight: .bold, color: .white)
        let bolusStack = UIStackView(arrangedSubviews: [bolusLabel, totalBolusAmountLabel])
        let bolusPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(bolusStack, in: bolusContainer, padding: bolusPadding)
        
        let carbsContainer = createContainerView(backgroundColor: .systemOrange)
        summaryView.addSubview(carbsContainer)
        
        let summaryLabel = createLabel(text: "TOT KH", fontSize: 10, weight: .bold, color: .white)
        totalNetCarbsLabel = createLabel(text: "0.0 g", fontSize: 18, weight: .semibold, color: .white)
        let carbsStack = UIStackView(arrangedSubviews: [summaryLabel, totalNetCarbsLabel])
        let carbsPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(carbsStack, in: carbsContainer, padding: carbsPadding)
        
        let fatContainer = createContainerView(backgroundColor: .systemBrown)
        summaryView.addSubview(fatContainer)
        
        let netFatLabel = createLabel(text: "TOT FETT", fontSize: 10, weight: .bold, color: .white)
        totalNetFatLabel = createLabel(text: "0.0 g", fontSize: 18, weight: .semibold, color: .white)
        let fatStack = UIStackView(arrangedSubviews: [netFatLabel, totalNetFatLabel])
        let fatPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(fatStack, in: fatContainer, padding: fatPadding)
        
        let proteinContainer = createContainerView(backgroundColor: .systemBrown)
        summaryView.addSubview(proteinContainer)
        
        let netProteinLabel = createLabel(text: "TOT PROTEIN", fontSize: 10, weight: .bold, color: .white)
        totalNetProteinLabel = createLabel(text: "0.0 g", fontSize: 18, weight: .semibold, color: .white)
        let proteinStack = UIStackView(arrangedSubviews: [netProteinLabel, totalNetProteinLabel])
        let proteinPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(proteinStack, in: proteinContainer, padding: proteinPadding)
        
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
    
    private func setupTreatmentView(in container: UIView) {
        let treatmentView = UIView()
        treatmentView.translatesAutoresizingMaskIntoConstraints = false
        treatmentView.backgroundColor = .systemBackground
        container.addSubview(treatmentView)
        
        let crContainer = createContainerView(backgroundColor: .systemCyan)
        treatmentView.addSubview(crContainer)
        
        crLabel = createLabel(text: "INSULINKVOT", fontSize: 10, weight: .bold, color: .white)
        
        if scheduledCarbRatio.truncatingRemainder(dividingBy: 1) == 0 {
            nowCRLabel = createLabel(text: String(format: "%.0f g/E", scheduledCarbRatio), fontSize: 18, weight: .bold, color: .white)
        } else {
            nowCRLabel = createLabel(text: String(format: "%.1f g/E", scheduledCarbRatio), fontSize: 18, weight: .bold, color: .white)
        }
        
        let crStack = UIStackView(arrangedSubviews: [crLabel, nowCRLabel])
        crStack.axis = .vertical
        crStack.spacing = 4
        let crPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(crStack, in: crContainer, padding: crPadding)
        
        remainsContainer = createContainerView(backgroundColor: .systemGreen, borderColor: .label, borderWidth: 2)
        treatmentView.addSubview(remainsContainer)
        let remainsTapGesture = UITapGestureRecognizer(target: self, action: #selector(remainContainerTapped))
        remainsContainer.addGestureRecognizer(remainsTapGesture)
        remainsContainer.isUserInteractionEnabled = true
        
        remainsLabel = createLabel(text: "ÅTERSTÅR", fontSize: 10, weight: .bold, color: .white)
        totalRemainsLabel = createLabel(text: "0g", fontSize: 12, weight: .semibold, color: .white)
        totalRemainsBolusLabel = createLabel(text: "0.00E", fontSize: 12, weight: .semibold, color: .white)
        
        let remainsValuesStack = UIStackView(arrangedSubviews: [totalRemainsLabel, totalRemainsBolusLabel])
        remainsValuesStack.axis = .horizontal
        remainsValuesStack.spacing = 3
        
        let remainsStack = UIStackView(arrangedSubviews: [remainsLabel, remainsValuesStack])
        remainsStack.axis = .vertical
        remainsStack.spacing = 7
        let remainsPadding = UIEdgeInsets(top: 4, left: 2, bottom: 7, right: 2)
        setupStackView(remainsStack, in: remainsContainer, padding: remainsPadding)
        
        let startAmountContainer = createContainerView(backgroundColor: .systemPurple, borderColor: .label, borderWidth: 2)
        treatmentView.addSubview(startAmountContainer)
        let startAmountTapGesture = UITapGestureRecognizer(target: self, action: #selector(startAmountContainerTapped))
        startAmountContainer.addGestureRecognizer(startAmountTapGesture)
        startAmountContainer.isUserInteractionEnabled = true
        
        let startAmountLabel = createLabel(text: "GE STARTDOS", fontSize: 10, weight: .bold, color: .white)
        totalStartAmountLabel = createLabel(text: String(format: "%.0fg", scheduledStartDose), fontSize: 12, weight: .semibold, color: .white)
        totalStartBolusLabel = createLabel(text: "0.00E", fontSize: 12, weight: .semibold, color: .white)
        
        let startAmountValuesStack = UIStackView(arrangedSubviews: [totalStartAmountLabel, totalStartBolusLabel])
        startAmountValuesStack.axis = .horizontal
        startAmountValuesStack.spacing = 3
        
        let startAmountStack = UIStackView(arrangedSubviews: [startAmountLabel, startAmountValuesStack])
        startAmountStack.axis = .vertical
        startAmountStack.spacing = 7
        let startAmountPadding = UIEdgeInsets(top: 4, left: 2, bottom: 7, right: 2)
        setupStackView(startAmountStack, in: startAmountContainer, padding: startAmountPadding)
        
        let registeredContainer = createContainerView(backgroundColor: .tertiarySystemBackground, borderColor: .label, borderWidth: 2)
        treatmentView.addSubview(registeredContainer)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(registeredContainerTapped))
        registeredContainer.addGestureRecognizer(tapGesture)
        registeredContainer.isUserInteractionEnabled = true
        let registeredLabel = createLabel(text: "REGGADE KH", fontSize: 10, weight: .bold, color: .label)
        totalRegisteredLabel = createTextField(placeholder: "...", fontSize: 18, weight: .semibold, color: .label)
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
    
    @objc private func allowShortcutsChanged() {
            allowShortcuts = UserDefaults.standard.bool(forKey: "allowShortcuts")
        }

    @objc private func startAmountContainerTapped() {
        var khValue = totalStartAmountLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0"
        var bolusValue = totalStartBolusLabel.text?.replacingOccurrences(of: "E", with: "") ?? "0"
        
        if allowShortcuts {
            let alertController = UIAlertController(title: "Registrera startdos", message: "Vill du registrera startdosen i iAPS?", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
            let yesAction = UIAlertAction(title: "Ja", style: .default) { _ in
                // Replace "." with ","
                khValue = khValue.replacingOccurrences(of: ".", with: ",")
                bolusValue = bolusValue.replacingOccurrences(of: ".", with: ",")
                
                // Update totalRegisteredLabel with the value from totalStartAmountLabel
                self.totalRegisteredLabel.text = khValue.replacingOccurrences(of: ",", with: ".")
                self.updateTotalNutrients()
                self.clearAllButton.isEnabled = true
                
                let urlString = "shortcuts://run-shortcut?name=Startdos&input=text&text=kh_\(khValue)_bolus_\(bolusValue)"
                
                if let url = URL(string: urlString) {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            }
            alertController.addAction(cancelAction)
            alertController.addAction(yesAction)
            present(alertController, animated: true, completion: nil)
        } else {
            let alertController = UIAlertController(title: "Registrera startdos", message: "Registrera nu den angivna startdosen \(khValue) g kh och \(bolusValue) E insulin i iAPS", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                // Update totalRegisteredLabel with the value from totalStartAmountLabel
                self.totalRegisteredLabel.text = khValue.replacingOccurrences(of: ",", with: ".")
                self.updateTotalNutrients()
                self.clearAllButton.isEnabled = true
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
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

        var khValue = totalRemainsLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0"
        var bolusValue = totalRemainsBolusLabel.text?.replacingOccurrences(of: "E", with: "") ?? "0"
        
        if allowShortcuts {
            let alertController = UIAlertController(title: "Registrera återstående dos", message: "Vill du registrera återstående dos i iAPS?", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
            let yesAction = UIAlertAction(title: "Ja", style: .default) { _ in
                // Replace "." with ","
                khValue = khValue.replacingOccurrences(of: ".", with: ",")
                bolusValue = bolusValue.replacingOccurrences(of: ".", with: ",")
                
                // Calculate new value for totalRegisteredLabel
                let currentRegisteredValue = Double(self.totalRegisteredLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
                let remainsValue = Double(khValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                let newRegisteredValue = currentRegisteredValue + remainsValue
                
                self.totalRegisteredLabel.text = String(format: "%.0f", newRegisteredValue).replacingOccurrences(of: ",", with: ".")
                self.updateTotalNutrients()
                self.clearAllButton.isEnabled = true
                
                let urlString = "shortcuts://run-shortcut?name=Slutdos&input=text&text=kh_\(khValue)_bolus_\(bolusValue)"
                
                if let url = URL(string: urlString) {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            }
            alertController.addAction(cancelAction)
            alertController.addAction(yesAction)
            present(alertController, animated: true, completion: nil)
        } else {
            let alertController = UIAlertController(title: "Registrera återstående dos", message: "Registrera nu den återstående dosen \(khValue) g kh och \(bolusValue) E insulin i iAPS", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                // Calculate new value for totalRegisteredLabel
                let currentRegisteredValue = Double(self.totalRegisteredLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
                let remainsValue = Double(khValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                let newRegisteredValue = currentRegisteredValue + remainsValue
                
                self.totalRegisteredLabel.text = String(format: "%.0f", newRegisteredValue).replacingOccurrences(of: ",", with: ".")
                self.updateTotalNutrients()
                self.clearAllButton.isEnabled = true
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
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
    
    private func updateTotalNutrients() {
        let totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }
        totalNetCarbsLabel?.text = String(format: "%.1f g", totalNetCarbs)
        
        let totalNetFat = foodItemRows.reduce(0.0) { $0 + $1.netFat }
        totalNetFatLabel?.text = String(format: "%.1f g", totalNetFat)
        
        let totalNetProtein = foodItemRows.reduce(0.0) { $0 + $1.netProtein }
        totalNetProteinLabel?.text = String(format: "%.1f g", totalNetProtein)
        
        let totalBolus = totalNetCarbs / scheduledCarbRatio
        let roundedBolus = roundToNearest05(totalBolus)
        totalBolusAmountLabel?.text = String(format: "%.2f E", roundedBolus)
        
        if totalNetCarbs > 0 && totalNetCarbs <= scheduledStartDose {
            totalStartAmountLabel?.text = String(format: "%.0fg", totalNetCarbs)
        } else {
            totalStartAmountLabel?.text = String(format: "%.0fg", scheduledStartDose)
        }
        
        let totalStartAmount = Double(totalStartAmountLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0") ?? 0.0
        let startBolus = roundToNearest05(totalStartAmount / scheduledCarbRatio)
        totalStartBolusLabel.text = String(format: "%.2fE", startBolus)
        
        updateRemainsBolus()
    }
    
    private func roundToNearest05(_ value: Double) -> Double {
        return (value * 20.0).rounded() / 20.0
    }
    
    @objc private func registeredLabelDidChange() {
        updateRemainsBolus()
    }
    
    private func updateRemainsBolus() {
        let totalCarbsText = totalNetCarbsLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0"
        let totalCarbsValue = Double(totalCarbsText) ?? 0.0
        
        if let registeredText = totalRegisteredLabel.text, let registeredValue = Double(registeredText) {
            let remainsValue = totalCarbsValue - registeredValue
            totalRemainsLabel.text = String(format: "%.0fg", remainsValue)
            
            let remainsBolus = roundToNearest05(remainsValue / scheduledCarbRatio)
            totalRemainsBolusLabel.text = String(format: "%.2fE", remainsBolus)
            
            if remainsValue < -0.5 {
                remainsLabel.text = "ÖVERDOS!"
            } else {
                remainsLabel.text = "ÅTERSTÅR"
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
            
            let remainsBolus = roundToNearest05(totalCarbsValue / scheduledCarbRatio)
            totalRemainsBolusLabel.text = String(format: "%.2fE", remainsBolus)
            
            remainsContainer.backgroundColor = .systemGray
            remainsLabel.text = "ÅTERSTÅR"
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
        notEatenLabel.text = "     LÄMNAT"
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
            headlineStackView.topAnchor.constraint(equalTo: headlineContainer.topAnchor, constant: 8),
            headlineStackView.bottomAnchor.constraint(equalTo: headlineContainer.bottomAnchor, constant: -8)
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
            searchableDropdownView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 112),
            searchableDropdownView.heightAnchor.constraint(equalToConstant: 275)
        ])
        
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
        }
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
    
    private func fetchFoodItems() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        do {
            foodItems = try context.fetch(fetchRequest).sorted { ($0.name ?? "") < ($1.name ?? "") }
            searchableDropdownView?.updateFoodItems(foodItems)
        } catch {
            print("Failed to fetch food items: \(error)")
        }
    }
    
    private func addFoodItemRow(with foodItem: FoodItem? = nil) {
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
        updateSaveFavoriteButtonState() // Add this line
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
                searchableDropdownView.heightAnchor.constraint(equalToConstant: 400)
            ])
        }
        
        searchableDropdownView.isHidden = false
        DispatchQueue.main.async {
            self.searchableDropdownView.searchBar.becomeFirstResponder()
        }
        
        // Only disable the "Clear All" button if there are no food items present
        if foodItemRows.isEmpty {
            clearAllButton.isEnabled = false
        }
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
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
        toolbar.setItems([flexSpace, doneButton], animated: false)
        
        totalRegisteredLabel?.inputAccessoryView = toolbar
    }
    
    @objc private func doneButtonTapped() {
        totalRegisteredLabel?.resignFirstResponder()
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardFrame.height, right: 0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    private func updateClearAllButtonState() {
        guard let clearAllButton = clearAllButton else {
            print("clearAllButton is nil")
            return
        }
        clearAllButton.isEnabled = !foodItemRows.isEmpty || !(totalRegisteredLabel.text?.isEmpty ?? true)
    }
    
    private func updateScheduledValuesUI() {
        if scheduledCarbRatio.truncatingRemainder(dividingBy: 1) == 0 {
            nowCRLabel.text = String(format: "%.0f g/E", scheduledCarbRatio)
        } else {
            nowCRLabel.text = String(format: "%.1f g/E", scheduledCarbRatio)
        }
        
        totalStartAmountLabel.text = String(format: "%.0fg", scheduledStartDose)
        
        let totalStartAmount = Double(totalStartAmountLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0") ?? 0.0
        let startBolus = roundToNearest05(totalStartAmount / scheduledCarbRatio)
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
    
    func didAddFoodItem() {
        fetchFoodItems()
    }
    
    class AddButtonRowView: UIView {
        let addButton: UIButton = {
            let button = UIButton(type: .system)
            button.setTitle("+ Välj livsmedel", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            button.setTitleColor(.systemBlue, for: .normal)
            button.translatesAutoresizingMaskIntoConstraints = false
            return button
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
            
            NSLayoutConstraint.activate([
                addButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
                addButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                addButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
                addButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
            ])
        }
    }
}
