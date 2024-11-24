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
    
    private let weightLabel = UILabel()
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
    
    private var adjustedCarbs: Int = 0
    private var adjustedFat: Int = 0
    private var adjustedProtein: Int = 0
    private var adjustedWeight: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        setupNavigationBar()
        updateBackgroundForCurrentMode()
        setupCloseButton()
        setupUI()
        updateAdjustments() // Initialize adjustments
    }
    
    private func setupNavigationBar() {
        title = "Analyserad måltid"
    }
    
    private func setupUI() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        // Meal section
        let mealContainer = UIView()
        mealContainer.backgroundColor = UIColor.label.withAlphaComponent(0.1)
        mealContainer.layer.cornerRadius = 12
        mealContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let mealTitleLabel = UILabel()
        mealTitleLabel.text = "Analyserad måltid"
        mealTitleLabel.font = .boldSystemFont(ofSize: 18)
        mealTitleLabel.textAlignment = .center
        
        let carbsLabel = UILabel()
        carbsLabel.text = "Kolhydrater: \(gptCarbs) g"
        carbsLabel.tag = 100
        
        let fatLabel = UILabel()
        fatLabel.text = "Fett: \(gptFat) g"
        fatLabel.tag = 101
        
        let proteinLabel = UILabel()
        proteinLabel.text = "Protein: \(gptProtein) g"
        proteinLabel.tag = 102
        
        let originalWeightLabel = UILabel()
        originalWeightLabel.text = "Ursprunglig uppskattad vikt: \(gptTotalWeight) g"
        originalWeightLabel.textColor = .gray
        originalWeightLabel.tag = 103
        
        let mealStack = UIStackView(arrangedSubviews: [carbsLabel, fatLabel, proteinLabel, originalWeightLabel])
        mealStack.axis = .vertical
        mealStack.spacing = 10
        mealStack.translatesAutoresizingMaskIntoConstraints = false
        
        mealContainer.addSubview(mealStack)
        
        NSLayoutConstraint.activate([
            mealStack.leadingAnchor.constraint(equalTo: mealContainer.leadingAnchor, constant: 16),
            mealStack.trailingAnchor.constraint(equalTo: mealContainer.trailingAnchor, constant: -16),
            mealStack.topAnchor.constraint(equalTo: mealContainer.topAnchor, constant: 16),
            mealStack.bottomAnchor.constraint(equalTo: mealContainer.bottomAnchor, constant: -16),
        ])
        
        // Weight slider
        weightLabel.text = "Ursprunglig uppskattad vikt: \(gptTotalWeight) g"
        weightLabel.textAlignment = .center
        
        slider.minimumValue = 0
        slider.maximumValue = 200
        slider.value = 100
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        
        // Add button
        addButton.addTarget(self, action: #selector(addToMeal), for: .touchUpInside)
        
        stackView.addArrangedSubview(mealContainer)
        stackView.addArrangedSubview(weightLabel)
        stackView.addArrangedSubview(slider)
        stackView.addArrangedSubview(addButton)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Add button height constraint
            addButton.heightAnchor.constraint(equalToConstant: 50)
        ])
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
    
    
    private func updateAdjustments() {
        let percentage = Int(slider.value)
        adjustedWeight = gptTotalWeight * percentage / 100
        adjustedCarbs = gptCarbs * percentage / 100
        adjustedFat = gptFat * percentage / 100
        adjustedProtein = gptProtein * percentage / 100
        
        weightLabel.text = "Justerad total vikt: \(adjustedWeight) g"
        
        if let carbsLabel = view.viewWithTag(100) as? UILabel {
            carbsLabel.text = "Kolhydrater: \(adjustedCarbs) g"
        }
        if let fatLabel = view.viewWithTag(101) as? UILabel {
            fatLabel.text = "Fett: \(adjustedFat) g"
        }
        if let proteinLabel = view.viewWithTag(102) as? UILabel {
            proteinLabel.text = "Protein: \(adjustedProtein) g"
        }
        
        // Debug prints
        print("Slider Adjustments Updated:")
        print("Adjusted Weight: \(adjustedWeight) g")
        print("Adjusted Carbs: \(adjustedCarbs) g")
        print("Adjusted Fat: \(adjustedFat) g")
        print("Adjusted Protein: \(adjustedProtein) g")
    }
    
    @objc private func sliderValueChanged(_ sender: UISlider) {
        updateAdjustments()
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
        } catch {
            print("DEBUG: Error fetching FoodItemTemporary entries: \(error.localizedDescription)")
        }
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
