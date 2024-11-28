//
//  AnalysisModalViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-24.
//

import UIKit
import CoreData

class AnalysisModalViewController: UIViewController {
    
    var gptCarbs: Int = 0
    var gptFat: Int = 0
    var gptProtein: Int = 0
    var gptTotalWeight: Int = 0
    var gptName: String = "Analyserad måltid"
    var savedResponse: String = ""
    var fromAnalysisLog: Bool = false
    
    // Warning label for dynamic text updates
    private var warningLabel: UILabel!
    
    // Label for the dynamically updated adjusted weight
    private let weightLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.text = "100 % av ursprunglig portion: 0 g" // Initial placeholder
        label.textColor = .label
        return label
    }()
    
    private let slider = UISlider()
    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("+ Lägg till i måltid", for: .normal)
        let systemFont = UIFont.systemFont(ofSize: 19, weight: .semibold)
        if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            button.titleLabel?.font = UIFont(descriptor: roundedDescriptor, size: 19)
        } else {
            button.titleLabel?.font = systemFont
        }
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // References to dynamically updated labels
    private var portionLabel: UILabel!
    private var fatLabel: UILabel!
    private var proteinLabel: UILabel!
    private var carbsLabel: UILabel!
    
    private var adjustedCarbs: Int = 0
    private var adjustedFat: Int = 0
    private var adjustedProtein: Int = 0
    private var adjustedWeight: Int = 0
    
    var dataSharingVC: DataSharingViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        setupNavigationBar()
        updateBackgroundForCurrentMode()
        setupCloseButton()
        setupUI()
        updateAdjustments() // Initialize adjustments
        dataSharingVC = DataSharingViewController()
        if fromAnalysisLog {
            //print("DEBUG: Opened from analysis log")
            adjustForAnalysisLog()
        }
    }
    
    private func setupNavigationBar() {
        title = gptName // Set the title to the meal name
    }
    
    private func setupContainer(_ container: UIView, title: String, valueLabel: UILabel) {
        let titleLabel = createLabel(text: NSLocalizedString(title, comment: title), fontSize: 9, weight: .bold, color: .white)
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }
    
    private func createContainerView(backgroundColor: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = backgroundColor
        container.layer.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }
    
    private func createLabel(text: String, fontSize: CGFloat = 18, weight: UIFont.Weight = .bold, color: UIColor = .white) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func setupUI() {
        // Summary Container at the Top
        let summaryContainer = UIView()
        summaryContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(summaryContainer)
        
        // Create and configure container views
        let portionContainer = createContainerView(backgroundColor: .systemGray3)
        portionLabel = createLabel(text: "\(adjustedWeight) g") // Save reference
        setupContainer(portionContainer, title: "PORTION", valueLabel: portionLabel)
        
        let fatContainer = createContainerView(backgroundColor: .systemBrown)
        fatLabel = createLabel(text: "\(adjustedFat) g") // Save reference
        setupContainer(fatContainer, title: "FETT", valueLabel: fatLabel)
        
        let proteinContainer = createContainerView(backgroundColor: .systemBrown)
        proteinLabel = createLabel(text: "\(adjustedProtein) g") // Save reference
        setupContainer(proteinContainer, title: "PROTEIN", valueLabel: proteinLabel)
        
        let carbsContainer = createContainerView(backgroundColor: .systemOrange)
        carbsLabel = createLabel(text: "\(adjustedCarbs) g") // Save reference
        setupContainer(carbsContainer, title: "KOLHYDRATER", valueLabel: carbsLabel)
        
        // Horizontal stack for the containers
        let hStack = UIStackView(arrangedSubviews: [portionContainer, fatContainer, proteinContainer, carbsContainer])
        hStack.axis = .horizontal
        hStack.spacing = 8
        hStack.distribution = .fillEqually
        hStack.translatesAutoresizingMaskIntoConstraints = false
        summaryContainer.addSubview(hStack)
        
        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: summaryContainer.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: summaryContainer.trailingAnchor),
            hStack.topAnchor.constraint(equalTo: summaryContainer.topAnchor),
            hStack.bottomAnchor.constraint(equalTo: summaryContainer.bottomAnchor),
            summaryContainer.heightAnchor.constraint(equalToConstant: 45)
        ])
        
        // Add the summary container to the view
        NSLayoutConstraint.activate([
            summaryContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            summaryContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            summaryContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
        ])
        
        // Warning Box
        let warningContainer = UIView()
        warningContainer.backgroundColor = .systemRed
        warningContainer.layer.cornerRadius = 8
        warningContainer.layer.borderWidth = 2
        warningContainer.layer.borderColor = UIColor.white.cgColor
        warningContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(warningContainer)
        
        warningLabel = UILabel()
        warningLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        warningLabel.textColor = .white
        warningLabel.numberOfLines = 0
        warningLabel.textAlignment = .center
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        warningLabel.text = """
                ⚠️  Obs! Ingredienser, portioner och näringsvärden 
                är grova uppskattningar gjorda av ChatGPT. 
                • Träffsäkerheten i bildanalyserna varierar.
                • Kontrollera innehållet noga innan bolus. 
                • Använd reglaget nedan för grova justeringar, 
                  eller gör finjusteringar direkt i måltidsvyn.
                """
        warningContainer.addSubview(warningLabel)
        
        NSLayoutConstraint.activate([
            warningLabel.leadingAnchor.constraint(equalTo: warningContainer.leadingAnchor, constant: 8),
            warningLabel.trailingAnchor.constraint(equalTo: warningContainer.trailingAnchor, constant: -8),
            warningLabel.topAnchor.constraint(equalTo: warningContainer.topAnchor, constant: 8),
            warningLabel.bottomAnchor.constraint(equalTo: warningContainer.bottomAnchor, constant: -8)
        ])
        
        NSLayoutConstraint.activate([
            warningContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            warningContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            warningContainer.topAnchor.constraint(equalTo: summaryContainer.bottomAnchor, constant: 16)
        ])
        
        // Weight Label with Tap Gesture
        weightLabel.text = "\(Int(slider.value)) % av ursprunglig portion: \(gptTotalWeight) g"
        weightLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        weightLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(weightLabel)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(weightLabelTapped))
        weightLabel.isUserInteractionEnabled = true
        weightLabel.addGestureRecognizer(tapGesture)
        
        // Slider
        slider.minimumValue = 0
        slider.maximumValue = 200
        slider.value = 100
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(slider)
        
        // Add-to-Meal Button
        addButton.addTarget(self, action: #selector(addToMeal), for: .touchUpInside)
        addButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        addButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Weight label above the slider
            weightLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            weightLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            weightLabel.bottomAnchor.constraint(equalTo: slider.topAnchor, constant: -10),
            
            // Slider
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            slider.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -20),
            
            // Add-to-Meal Button
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    @objc private func weightLabelTapped() {
        slider.value = 100 // Reset slider to 100
        updateAdjustments() // Update adjusted values
    }
    
    private func setupCloseButton() {
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    private func updateBackgroundForCurrentMode() {
        // Remove any existing gradient views before updating
        view.subviews.filter { $0 is GradientView }.forEach { $0.removeFromSuperview() }
        
        // Update the background based on the current interface style
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .systemBackground
            // Create the gradient view for dark mode
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
        } else {
            // In light mode, set a solid background
            view.backgroundColor = .systemGray6
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackgroundForCurrentMode()
        }
    }
    
    @objc private func sliderValueChanged(_ sender: UISlider) {
        // Trigger adjustments and UI updates
        updateAdjustments()
    }
    
    private func updateAdjustments() {
        let percentage = Int(slider.value)
        adjustedWeight = gptTotalWeight * percentage / 100
        adjustedCarbs = gptCarbs * percentage / 100
        adjustedFat = gptFat * percentage / 100
        adjustedProtein = gptProtein * percentage / 100
        
        // Update the weight label with percentage and original portion
        weightLabel.text = "\(percentage) % av ursprunglig portion: \(gptTotalWeight) g"
        
        // Update container labels directly
        portionLabel.text = "\(adjustedWeight) g"
        carbsLabel.text = "\(adjustedCarbs) g"
        fatLabel.text = "\(adjustedFat) g"
        proteinLabel.text = "\(adjustedProtein) g"
        
        // Debugging logs
        // Daniel: Keeping for future debugging // print("Slider Adjustments Updated:")
        // Daniel: Keeping for future debugging // print("Adjusted Weight: \(adjustedWeight) g")
        // Daniel: Keeping for future debugging // print("Adjusted Carbs: \(adjustedCarbs) g")
        // Daniel: Keeping for future debugging // print("Adjusted Fat: \(adjustedFat) g")
        // Daniel: Keeping for future debugging // print("Adjusted Protein: \(adjustedProtein) g")
    }
    
    private func adjustForAnalysisLog() {
        // Update warning text
        warningLabel.text = """
            ⚠️ Obs! Ingredienser, portioner och näringsvärden 
            är grova uppskattningar gjorda av ChatGPT. 
            • Träffsäkerheten i bildanalyserna varierar.
            • Kontrollera innehållet noga innan bolus. 
            • Gör eventuella justeringar direkt i måltidsvyn.
            """
        
        // Hide the slider and weight label
        slider.isHidden = true
        weightLabel.isHidden = true
    }
    
    @objc private func addToMeal() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItemTemporary> = FoodItemTemporary.fetchRequest()
        
        do {
            let existingTemporaryItems = try context.fetch(fetchRequest)
            
            if !existingTemporaryItems.isEmpty {
                // Daniel: Keeping for future debugging // print("DEBUG: Found existing FoodItemTemporary entries")
                showReplaceOrAddAlert(existingItems: existingTemporaryItems)
            } else {
                print("DEBUG: No existing FoodItemTemporary entries")
                saveNewTemporaryFoodItems(replacing: true)
            }
            
            // Add the new AIMeal after processing temporary items
            saveNewAIMealEntry()
            
            // Conditionally trigger the export after saving the new meal
            if UserDefaultsRepository.allowCSVSync {
                Task {
                    await exportAIMealLog()
                }
            } else {
                print("CSV export is disabled in settings.")
            }
            
        } catch {
            print("DEBUG: Error fetching FoodItemTemporary entries: \(error.localizedDescription)")
        }
    }
    
    private func saveNewAIMealEntry() {
        let context = CoreDataStack.shared.context
        
        // Create a new AIMeal entry
        let newMeal = AIMeal(context: context)
        newMeal.response = savedResponse
        newMeal.name = gptName
        newMeal.totalCarbs = Double(adjustedCarbs)
        newMeal.totalFat = Double(adjustedFat)
        newMeal.totalProtein = Double(adjustedProtein)
        newMeal.totalAdjustedWeight = Double(adjustedWeight)
        newMeal.totalOriginalWeight = Double(gptTotalWeight)
        newMeal.delete = false
        newMeal.lastEdited = Date()
        newMeal.id = UUID()
        newMeal.mealDate = Date()
        
        do {
            try context.save()
            // Daniel: Keeping for future debugging // print("DEBUG: AIMeal entry saved successfully")
        } catch {
            print("DEBUG: Error saving AIMeal entry: \(error.localizedDescription)")
        }
    }
    
    private func exportAIMealLog() async {
        guard let dataSharingVC = dataSharingVC else {
            print("DEBUG: dataSharingVC is not available.")
            return
        }
        print("DEBUG: Exporting AI Meals to CSV.")
        await dataSharingVC.exportAIMealLogToCSV()
        print("DEBUG: AI Meals export completed.")
    }
    
    
    private func showReplaceOrAddAlert(existingItems: [FoodItemTemporary]) {
        let alert = UIAlertController(
            title: NSLocalizedString("Lägg till eller ersätt?", comment: "Lägg till eller ersätt?"),
            message: NSLocalizedString("\nObs! Det finns redan temporära måltidsdata i Core Data.\n\nVill du addera de nya matvarorna till de befintliga, eller vill du ersätta de befintliga med de nya?", comment: "\nObs! Det finns redan temporära måltidsdata i Core Data.\n\nVill du addera de nya matvarorna till de befintliga, eller vill du ersätta de befintliga med de nya?"),
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Ersätt", comment: "Ersätt"), style: .destructive, handler: { [weak self] _ in
            // Daniel: Keeping for future debugging // print("DEBUG: User chose to replace existing FoodItemTemporary entries")
            self?.saveNewTemporaryFoodItems(replacing: true)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Addera", comment: "Addera"), style: .default, handler: { [weak self] _ in
            // Daniel: Keeping for future debugging // print("DEBUG: User chose to add to existing FoodItemTemporary entries")
            self?.saveNewTemporaryFoodItems(replacing: false)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel, handler: { _ in
            // Daniel: Keeping for future debugging // print("DEBUG: User canceled the action")
        }))
        
        present(alert, animated: true)
    }
    private func saveNewTemporaryFoodItems(replacing: Bool) {
        let context = CoreDataStack.shared.context
        
        if replacing {
            let fetchRequest: NSFetchRequest<FoodItemTemporary> = FoodItemTemporary.fetchRequest()
            do {
                let existingItems = try context.fetch(fetchRequest)
                for item in existingItems {
                    context.delete(item)
                }
            } catch {
                print("DEBUG: Error clearing existing FoodItemTemporary entries: \(error.localizedDescription)")
            }
        }
        
        guard !savedResponse.isEmpty else { return }
        let csvData = parseCSV(savedResponse)
        
        var totalMatchedCarbs = 0
        var totalMatchedFat = 0
        var totalMatchedProtein = 0
        var allMatched = true
        
        let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "FoodItem")
        fetchRequest.predicate = NSPredicate(format: "(delete == NO OR delete == nil) AND (perPiece == NO OR perPiece == nil)")
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = ["id", "name"]
        
        do {
            let foodItemDictionaries = try context.fetch(fetchRequest)
            let foodItems: [(id: UUID, name: String)] = foodItemDictionaries.compactMap { dict in
                if let id = dict["id"] as? UUID, let name = dict["name"] as? String {
                    return (id: id, name: name)
                }
                return nil
            }
            
            let percentageMultiplier = Double(slider.value) / 100.0
            
            // Check for an exact match
            if let gptMatchedItem = foodItems.first(where: { $0.name.caseInsensitiveCompare(gptName) == .orderedSame }) {
                let temporaryItem = FoodItemTemporary(context: context)
                temporaryItem.entryId = gptMatchedItem.id
                temporaryItem.entryPortionServed = Double(adjustedWeight)
                
                print("DEBUG: Exact match found for \(gptName). Using \(gptMatchedItem.name) with ID \(gptMatchedItem.id)")
            } else {
                print("DEBUG: No exact match found, moving on")
                
                let alertController = UIAlertController(
                    title: NSLocalizedString("Välj om du vill:", comment: "Create a new meal? or match ingredients"),
                    message: String(format: NSLocalizedString("\n1. Skapa en helt ny måltid '%@' och lägga till den i måltidslistan (och i databasen). \n\n2. Försöka matcha alla måltidens individuella livsmedel och lägga till dem i måltidslistan med flera rader?", comment: "Create a new meal with name?"), gptName),
                    preferredStyle: .actionSheet
                )
                
                let createAction = UIAlertAction(title: NSLocalizedString("Skapa ny måltid", comment: "Create meal"), style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    
                    // Create the new FoodItem
                    self.createNewFoodItem(context: context, percentageMultiplier: percentageMultiplier)
                    
                    // After saving, show success view and dismiss the modal
                    DispatchQueue.main.async {
                        //NotificationCenter.default.post(name: NSNotification.Name("TemporaryFoodItemsAdded"), object: nil)
                        self.showSuccessView()
                        self.dismiss(animated: true)
                    }
                }
                
                let matchItemsAction = UIAlertAction(title: NSLocalizedString("Matcha livsmedel", comment: "Match food items"), style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    
                    // Match ingredients
                    self.matchIngredients(csvData: csvData, foodItems: foodItems, percentageMultiplier: percentageMultiplier)
                    
                    // After matching, show success view and dismiss the modal
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("TemporaryFoodItemsAdded"), object: nil)
                        self.showSuccessView()
                        self.dismiss(animated: true)
                    }
                }
                
                let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel"), style: .cancel)
                
                alertController.addAction(createAction)
                alertController.addAction(matchItemsAction)
                alertController.addAction(cancelAction)
                
                DispatchQueue.main.async {
                    self.present(alertController, animated: true)
                }
                
                return // Prevent further execution after presenting the alert
            }
            
            // Handle unmatched nutrients
            if !allMatched {
                handleUnmatchedNutrients(context: context, percentageMultiplier: percentageMultiplier, totalMatchedCarbs: totalMatchedCarbs, totalMatchedFat: totalMatchedFat, totalMatchedProtein: totalMatchedProtein)
            }
            
            try context.save()
            NotificationCenter.default.post(name: NSNotification.Name("TemporaryFoodItemsAdded"), object: nil)
            showSuccessView()
            dismiss(animated: true)
        } catch {
            print("DEBUG: Error saving new FoodItemTemporary entries: \(error.localizedDescription)")
        }
    }
    
    private func createNewFoodItem(context: NSManagedObjectContext, percentageMultiplier: Double) {
        // Calculate nutrients
        let calculatedCarbs = Int(round(Double(adjustedCarbs) / Double(adjustedWeight) * 100))
        let calculatedFat = Int(round(Double(adjustedFat) / Double(adjustedWeight) * 100))
        let calculatedProtein = Int(round(Double(adjustedProtein) / Double(adjustedWeight) * 100))
        
        // Create a new FoodItem
        let newFoodItem = FoodItem(context: context)
        let newFoodItemID = UUID()
        newFoodItem.id = newFoodItemID
        newFoodItem.name = gptName
        newFoodItem.carbohydrates = Double(calculatedCarbs)
        newFoodItem.carbsPP = 0
        newFoodItem.fat = Double(calculatedFat)
        newFoodItem.fatPP = 0
        newFoodItem.netCarbs = 0
        newFoodItem.netFat = 0
        newFoodItem.netProtein = 0
        newFoodItem.perPiece = false
        newFoodItem.protein = Double(calculatedProtein)
        newFoodItem.proteinPP = 0
        newFoodItem.count = 0
        newFoodItem.notes = NSLocalizedString("Måltid skapad av ChatGPT", comment: "Meal created by ChatGPT")
        newFoodItem.lastEdited = Date()
        newFoodItem.delete = false
        newFoodItem.emoji = "🤖"
        
        do {
            // Save the new FoodItem first
            try context.save()
            print("DEBUG: New FoodItem \(gptName) created successfully")
            
            // Add the FoodItemTemporary entry
            let temporaryItem = FoodItemTemporary(context: context)
            temporaryItem.entryId = newFoodItemID
            temporaryItem.entryPortionServed = Double(adjustedWeight)
            
            // Save the FoodItemTemporary entry
            try context.save()
            print("DEBUG: Temporary FoodItem \(gptName) added successfully")
            
            // Delay to ensure data is saved before notifying observers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: NSNotification.Name("TemporaryFoodItemsAdded"), object: nil)
            }
        } catch {
            print("DEBUG: Error creating new FoodItem or TemporaryFoodItem \(gptName): \(error.localizedDescription)")
        }
    }
    
    private func matchIngredients(csvData: [[String]], foodItems: [(id: UUID, name: String)], percentageMultiplier: Double) {
        var totalMatchedCarbs = 0
        var totalMatchedFat = 0
        var totalMatchedProtein = 0
        var allMatched = true
        
        let context = CoreDataStack.shared.context
        
        for ingredient in csvData {
            guard ingredient.count >= 7 else { continue }
            
            let matvara = ingredient[2]
            let portionServed = Double(ingredient[3]) ?? 0.0
            let carbs = Int(ingredient[4]) ?? 0
            let fat = Int(ingredient[5]) ?? 0
            let protein = Int(ingredient[6]) ?? 0
            
            if let matchedItem = fuzzySearchForCSV(query: matvara, in: foodItems).first {
                let adjustedPortionServed = Int(round(portionServed * percentageMultiplier))
                
                let temporaryItem = FoodItemTemporary(context: context)
                temporaryItem.entryId = matchedItem.id
                temporaryItem.entryPortionServed = Double(adjustedPortionServed)
                
                totalMatchedCarbs += carbs
                totalMatchedFat += fat
                totalMatchedProtein += protein
            } else {
                print("DEBUG: No match found for \(matvara)")
                allMatched = false
            }
        }
        
        if !allMatched {
            handleUnmatchedNutrients(context: context, percentageMultiplier: percentageMultiplier, totalMatchedCarbs: totalMatchedCarbs, totalMatchedFat: totalMatchedFat, totalMatchedProtein: totalMatchedProtein)
        }
    }
    
    private func handleUnmatchedNutrients(context: NSManagedObjectContext, percentageMultiplier: Double, totalMatchedCarbs: Int, totalMatchedFat: Int, totalMatchedProtein: Int) {
        let adjustedCarbs = max(0, gptCarbs - totalMatchedCarbs)
        let adjustedFat = max(0, gptFat - totalMatchedFat)
        let adjustedProtein = max(0, gptProtein - totalMatchedProtein)
        
        let nutrientNames = ["𐓙 Kolhydrater", "𐓙 Fett", "𐓙 Protein"]
        let nutrientItemsFetch: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        nutrientItemsFetch.predicate = NSPredicate(format: "name IN %@ AND (delete == NO OR delete == nil)", nutrientNames)
        
        do {
            // Fetch existing nutrient items
            let nutrientItems = try context.fetch(nutrientItemsFetch)
            var nutrientItemsDict = Dictionary(uniqueKeysWithValues: nutrientItems.compactMap { ($0.name ?? "", $0.id) })
            
            // Create missing nutrient items if necessary
            for nutrientName in nutrientNames {
                if !nutrientItemsDict.keys.contains(nutrientName) {
                    let newFoodItem = FoodItem(context: context)
                    let newFoodItemID = UUID()
                    newFoodItem.id = newFoodItemID
                    newFoodItem.name = nutrientName
                    
                    switch nutrientName {
                    case "𐓙 Kolhydrater":
                        newFoodItem.carbohydrates = 100
                        newFoodItem.fat = 0
                        newFoodItem.protein = 0
                    case "𐓙 Fett":
                        newFoodItem.carbohydrates = 0
                        newFoodItem.fat = 100
                        newFoodItem.protein = 0
                    case "𐓙 Protein":
                        newFoodItem.carbohydrates = 0
                        newFoodItem.fat = 0
                        newFoodItem.protein = 100
                    default:
                        continue
                    }
                    
                    newFoodItem.carbsPP = 0
                    newFoodItem.fatPP = 0
                    newFoodItem.proteinPP = 0
                    newFoodItem.netCarbs = 0
                    newFoodItem.netFat = 0
                    newFoodItem.netProtein = 0
                    newFoodItem.perPiece = false
                    newFoodItem.count = 0
                    newFoodItem.notes = NSLocalizedString("Används för övriga livsmedel från AI-analyserad bild", comment: "")
                    newFoodItem.lastEdited = Date()
                    newFoodItem.delete = false
                    newFoodItem.emoji = "🤖"
                    
                    try context.save()
                    print("DEBUG: Created missing nutrient item: \(nutrientName)")
                    
                    // Add the newly created nutrient item to the dictionary
                    nutrientItemsDict[nutrientName] = newFoodItem.id
                }
            }
            
            // Create FoodItemTemporary entries for unmatched nutrients
            for (name, portionServed) in [("𐓙 Kolhydrater", adjustedCarbs),
                                          ("𐓙 Fett", adjustedFat),
                                          ("𐓙 Protein", adjustedProtein)] {
                if let nutrientId = nutrientItemsDict[name] {
                    let temporaryItem = FoodItemTemporary(context: context)
                    temporaryItem.entryId = nutrientId
                    let adjustedPortionServed = Int(round(Double(portionServed) * percentageMultiplier))
                    temporaryItem.entryPortionServed = Double(adjustedPortionServed)
                    print("DEBUG: Created temporary item for \(name) with portion \(adjustedPortionServed)")
                } else {
                    print("DEBUG: Failed to find or create nutrient \(name)")
                }
            }
            
            try context.save()
            print("DEBUG: Unmatched nutrients handled successfully")
        } catch {
            print("DEBUG: Error handling unmatched nutrients: \(error.localizedDescription)")
        }
    }
    
    private func fuzzySearchForCSV(query: String, in items: [(id: UUID, name: String)]) -> [(id: UUID, name: String)] {
        // Daniel: Keeping for future debugging // print("DEBUG: Starting fuzzySearchForCSV with query: \(query)")
        
        // Log all available FoodItems
        let foodItemNames = items.map { $0.name }
        // Daniel: Keeping for future debugging // print("DEBUG: Available FoodItems: \(foodItemNames)")
        
        // Check for exact case-sensitive match first
        if let exactMatch = items.first(where: { $0.name == query }) {
            // Daniel: Keeping for future debugging // print("DEBUG: Exact case-sensitive match found: \(exactMatch.name)")
            return [exactMatch]
        }
        
        // Check for case-insensitive match next
        if let caseInsensitiveMatch = items.first(where: { $0.name.caseInsensitiveCompare(query) == .orderedSame }) {
            // Daniel: Keeping for future debugging // print("DEBUG: Case-insensitive match found: \(caseInsensitiveMatch.name)")
            return [caseInsensitiveMatch]
        }
        
        // Fuzzy matching as fallback
        let threshold = 0.8
        let matchedItems = items.filter { item in
            let name = item.name
            
            // Boost matches that start with the same letters
            let startsWithScore = name.lowercased().hasPrefix(query.lowercased()) ? 1.0 : 0.0
            let fuzzyScore = name.fuzzyMatch(query)
            
            // Log individual scores
            // Daniel: Keeping for future debugging // print("DEBUG: Evaluating \(name): startsWithScore = \(startsWithScore), fuzzyScore = \(fuzzyScore)")
            
            // Calculate a combined score with higher weight for prefix matches
            let combinedScore = (fuzzyScore * 0.9) + (startsWithScore * 0.1)
            // Daniel: Keeping for future debugging // print("DEBUG: Combined score for \(name): \(combinedScore)")
            
            return combinedScore > threshold
        }
        
        // Log results of fuzzy matching
        let matchedNames = matchedItems.map { $0.name }
        // Daniel: Keeping for future debugging // print("DEBUG: Fuzzy matched items: \(matchedNames)")
        
        return matchedItems
    }
    
    // Parse CSV function
    private func parseCSV(_ csvString: String) -> [[String]] {
        var ingredients: [[String]] = []
        
        // Debug: Print the raw CSV string
        // Daniel: Keeping for future debugging // print("Raw CSV String:\n\(csvString)")
        
        // Locate the start of the CSV block by finding the header
        guard let csvStartIndex = csvString.range(of: "Måltid, MåltidTotalViktGram, Matvara, MatvaraViktGram, MatvaraKolhydraterGram, MatvaraFettGram, MatvaraProteinGram") else {
            print("No valid CSV header found in response.")
            return ingredients
        }
        
        // Extract the CSV portion starting from the header
        let csvBlock = csvString[csvStartIndex.lowerBound...]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.starts(with: "This is a basic estimation") } // Exclude unrelated text
        
        print("Filtered CSV Lines: \(csvBlock)")
        
        // Skip the header (first line)
        for (index, line) in csvBlock.enumerated() {
            if index == 0 { continue } // Skip header row
            
            // Remove quotes and split by commas
            let components = line
                .replacingOccurrences(of: "\"", with: "") // Remove double quotes
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            
            print("Line \(index): \(components)")
            
            if components.count >= 7 {
                ingredients.append(Array(components))
                print("Ingredient Added: \(ingredients.last ?? [])")
            }
        }
        
        print("Final Ingredients List: \(ingredients)")
        return ingredients
    }
    private func showSuccessView() {
        let successView = SuccessView()
        
        // Use the key window to display the success view
        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            successView.showInView(keyWindow)
            // Daniel: Keeping for future debugging // print("DEBUG: SuccessView displayed")
        } else {
            print("DEBUG: Key window not found for displaying SuccessView")
        }
    }
}
