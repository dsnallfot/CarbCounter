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
            //setupCloseButton()
            setupUI()
            updateAdjustments() // Initialize adjustments
            dataSharingVC = DataSharingViewController()
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
        
        // Weight Label with Tap Gesture
        weightLabel.text = "\(Int(slider.value)) % av ursprunglig portion: \(gptTotalWeight) g"
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
            weightLabel.bottomAnchor.constraint(equalTo: slider.topAnchor, constant: -30),
            
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
        print("DEBUG: Weight label tapped, resetting slider.")
        slider.value = 100 // Reset slider to 100
        updateAdjustments() // Update adjusted values
    }
    /*
    private func setupCloseButton() {
            let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
            navigationItem.leftBarButtonItem = closeButton
        }
        
        @objc private func closeButtonTapped() {
            dismiss(animated: true, completion: nil)
        }*/
    
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
        print("Slider Adjustments Updated:")
        print("Adjusted Weight: \(adjustedWeight) g")
        print("Adjusted Carbs: \(adjustedCarbs) g")
        print("Adjusted Fat: \(adjustedFat) g")
        print("Adjusted Protein: \(adjustedProtein) g")
    }
    
    @objc private func addToMeal() {
        print("DEBUG: addToMeal button tapped")
        
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItemTemporary> = FoodItemTemporary.fetchRequest()
        
        do {
            let existingTemporaryItems = try context.fetch(fetchRequest)
            
            if !existingTemporaryItems.isEmpty {
                print("DEBUG: Found existing FoodItemTemporary entries")
                showReplaceOrAddAlert(existingItems: existingTemporaryItems)
            } else {
                print("DEBUG: No existing FoodItemTemporary entries")
                saveNewTemporaryFoodItems(replacing: true)
            }
            
            // Add the new AIMeal after processing temporary items
            saveNewAIMealEntry()
            
            // Trigger the export after saving the new meal
            Task {
                await exportAIMealLog()
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
            print("DEBUG: AIMeal entry saved successfully")
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
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Ersätt", comment: "Ersätt"), style: .destructive, handler: { [weak self] _ in
            print("DEBUG: User chose to replace existing FoodItemTemporary entries")
            self?.saveNewTemporaryFoodItems(replacing: true)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Addera", comment: "Addera"), style: .default, handler: { [weak self] _ in
            print("DEBUG: User chose to add to existing FoodItemTemporary entries")
            self?.saveNewTemporaryFoodItems(replacing: false)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel, handler: { _ in
            print("DEBUG: User canceled the action")
        }))
        
        present(alert, animated: true)
    }
    private func saveNewTemporaryFoodItems(replacing: Bool) {
        let context = CoreDataStack.shared.context

        // Clear existing FoodItemTemporary entries if replacing
        if replacing {
            let fetchRequest: NSFetchRequest<FoodItemTemporary> = FoodItemTemporary.fetchRequest()
            do {
                let existingItems = try context.fetch(fetchRequest)
                for item in existingItems {
                    context.delete(item)
                }
                print("DEBUG: Cleared existing FoodItemTemporary entries")
            } catch {
                print("DEBUG: Error clearing existing FoodItemTemporary entries: \(error.localizedDescription)")
            }
        }

        // Parse CSV data
        guard !savedResponse.isEmpty else { return }
        let csvData = parseCSV(savedResponse)

        var totalMatchedCarbs = 0
        var totalMatchedFat = 0
        var totalMatchedProtein = 0
        var allMatched = true // Flag to track if all "Matvaror" are matched

        // Fetch FoodItems from Core Data, excluding those with perPiece == true
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "(delete == NO OR delete == nil) AND (perPiece == NO OR perPiece == nil)")

        do {
            let foodItems = try context.fetch(fetchRequest)

            for ingredient in csvData {
                guard ingredient.count >= 7 else {
                    print("DEBUG: Skipping malformed ingredient row: \(ingredient)")
                    continue
                }

                let matvara = ingredient[2] // Matvara
                let portionServed = Double(ingredient[3]) ?? 0.0
                let carbs = Int(ingredient[4]) ?? 0
                let fat = Int(ingredient[5]) ?? 0
                let protein = Int(ingredient[6]) ?? 0

                // Attempt to match the Matvara to a FoodItem
                if let matchedItem = fuzzySearchForCSV(query: matvara, in: foodItems).first {
                    guard let foodItemId = matchedItem.id else {
                        print("DEBUG: Skipping matched FoodItem with missing ID for \(matvara)")
                        continue
                    }

                    // Create FoodItemTemporary for matched FoodItem
                    let temporaryItem = FoodItemTemporary(context: context)
                    temporaryItem.entryId = foodItemId
                    temporaryItem.entryPortionServed = portionServed
                    print("DEBUG: Matched \(matvara) to \(matchedItem.name ?? "unknown") with ID \(foodItemId)")

                    totalMatchedCarbs += carbs
                    totalMatchedFat += fat
                    totalMatchedProtein += protein
                } else {
                    print("DEBUG: No match found for \(matvara)")
                    allMatched = false // Mark as not all matched
                }
            }

            // Only add fallback entries if not all "Matvaror" are matched
            if !allMatched {
                // Calculate remaining nutrient values for unmatched entries
                let adjustedCarbs = max(0, gptCarbs - totalMatchedCarbs)
                let adjustedFat = max(0, gptFat - totalMatchedFat)
                let adjustedProtein = max(0, gptProtein - totalMatchedProtein)

                // Fetch the predefined FoodItems for unmatched nutrients
                let nutrientNames = ["🤖 Kolhydrater", "🤖 Fett", "🤖 Protein"]
                let nutrientItemsFetch: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
                nutrientItemsFetch.predicate = NSPredicate(format: "name IN %@", nutrientNames)

                let nutrientItems = try context.fetch(nutrientItemsFetch)
                let nutrientItemsDict = Dictionary(uniqueKeysWithValues: nutrientItems.compactMap { ($0.name ?? "", $0.id) })

                // Create FoodItemTemporary entries for unmatched nutrients
                for (name, portionServed) in [("🤖 Kolhydrater", adjustedCarbs),
                                              ("🤖 Fett", adjustedFat),
                                              ("🤖 Protein", adjustedProtein)] {
                    if let nutrientId = nutrientItemsDict[name] {
                        let temporaryItem = FoodItemTemporary(context: context)
                        temporaryItem.entryId = nutrientId
                        temporaryItem.entryPortionServed = Double(portionServed)
                        print("DEBUG: Added \(name) with portion \(portionServed) and ID \(nutrientId)")
                    } else {
                        print("DEBUG: Nutrient \(name) is missing from FoodItems")
                    }
                }
            } else {
                print("DEBUG: All Matvaror matched; no fallback entries added")
            }

            // Save changes to Core Data
            try context.save()
            print("DEBUG: New FoodItemTemporary entries saved successfully")

            // Notify ComposeMealViewController
            NotificationCenter.default.post(name: NSNotification.Name("TemporaryFoodItemsAdded"), object: nil)

            // Show success view and dismiss
            showSuccessView()
            dismiss(animated: true)
        } catch {
            print("DEBUG: Error saving new FoodItemTemporary entries: \(error.localizedDescription)")
        }
    }
    
    private func fuzzySearchForCSV(query: String, in items: [FoodItem]) -> [FoodItem] {
        print("DEBUG: Starting fuzzySearchForCSV with query: \(query)")

        // Log all available FoodItems
        let foodItemNames = items.compactMap { $0.name }
        print("DEBUG: Available FoodItems: \(foodItemNames)")

        // Check for exact case-sensitive match first
        if let exactMatch = items.first(where: { $0.name == query }) {
            print("DEBUG: Exact case-sensitive match found: \(exactMatch.name ?? "Unknown")")
            return [exactMatch]
        }

        // Check for case-insensitive match next
        if let caseInsensitiveMatch = items.first(where: { $0.name?.caseInsensitiveCompare(query) == .orderedSame }) {
            print("DEBUG: Case-insensitive match found: \(caseInsensitiveMatch.name ?? "Unknown")")
            return [caseInsensitiveMatch]
        }

        // Fuzzy matching as fallback
        let threshold = 0.8
        let matchedItems = items.filter { item in
            guard let name = item.name else { return false }

            // Boost matches that start with the same letters
            let startsWithScore = name.lowercased().hasPrefix(query.lowercased()) ? 1.0 : 0.0
            let fuzzyScore = name.fuzzyMatch(query)

            // Log individual scores
            print("DEBUG: Evaluating \(name): startsWithScore = \(startsWithScore), fuzzyScore = \(fuzzyScore)")

            // Calculate a combined score with higher weight for prefix matches
            let combinedScore = (fuzzyScore * 0.9) + (startsWithScore * 0.1)
            print("DEBUG: Combined score for \(name): \(combinedScore)")

            return combinedScore > threshold
        }

        // Log results of fuzzy matching
        let matchedNames = matchedItems.compactMap { $0.name }
        print("DEBUG: Fuzzy matched items: \(matchedNames)")

        return matchedItems
    }

    // Parse CSV function
    private func parseCSV(_ csvString: String) -> [[String]] {
        var ingredients: [[String]] = []

        // Debug: Print the raw CSV string
        print("Raw CSV String:\n\(csvString)")

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
            print("DEBUG: SuccessView displayed")
        } else {
            print("DEBUG: Key window not found for displaying SuccessView")
        }
    }
}