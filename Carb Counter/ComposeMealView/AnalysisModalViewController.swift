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
        
        if replacing {
            // Remove existing entries
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
        
        // Fetch FoodItems to create new FoodItemTemporary entries
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name IN %@", ["🤖 Fett", "🤖 Kolhydrater", "🤖 Protein"])
        
        do {
            let selectedFoodItems = try context.fetch(fetchRequest)
            print("DEBUG: Fetched \(selectedFoodItems.count) FoodItems for new entries")
            
            for item in selectedFoodItems {
                guard let foodItemId = item.id else {
                    print("DEBUG: Skipping FoodItem with missing ID")
                    continue
                }
                
                let portionServed: Double
                switch item.name {
                case "🤖 Kolhydrater":
                    portionServed = Double(adjustedCarbs)
                    print("DEBUG: Setting portion for Kolhydrater: \(portionServed)")
                case "🤖 Fett":
                    portionServed = Double(adjustedFat)
                    print("DEBUG: Setting portion for Fett: \(portionServed)")
                case "🤖 Protein":
                    portionServed = Double(adjustedProtein)
                    print("DEBUG: Setting portion for Protein: \(portionServed)")
                default:
                    print("DEBUG: Unhandled FoodItem name: \(item.name ?? "Unknown")")
                    continue
                }
                
                let temporaryItem = FoodItemTemporary(context: context)
                temporaryItem.entryId = foodItemId
                temporaryItem.entryPortionServed = portionServed
                
                print("DEBUG: Created FoodItemTemporary with ID: \(foodItemId) and portion served: \(portionServed)")
            }
            
            try context.save()
            print("DEBUG: New FoodItemTemporary entries saved successfully")
            
            // Notify ComposeMealViewController
            NotificationCenter.default.post(name: NSNotification.Name("TemporaryFoodItemsAdded"), object: nil)
            
            // Show the success view after adding the food item
            showSuccessView()
            
            dismiss(animated: true)
            print("DEBUG: Dismissed AnalysisModalViewController")
        } catch {
            print("DEBUG: Error saving new FoodItemTemporary entries: \(error.localizedDescription)")
        }
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
