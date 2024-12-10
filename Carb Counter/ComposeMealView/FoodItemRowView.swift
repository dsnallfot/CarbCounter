//
//  FoodItemRowView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-19.
//
import UIKit
import CoreData

protocol FoodItemRowViewDelegate: AnyObject {
    func didTapNextButton(_ rowView: FoodItemRowView, currentTextField: UITextField)
    func saveToCoreData()
    func deleteFoodItemRow(_ rowView: FoodItemRowView)
    func startEditing()
    func stopEditing()
}

class FoodItemRowView: UIView, UITextFieldDelegate, AddFoodItemDelegate {
    var onDelete: (() -> Void)?
    var onValueChange: (() -> Void)?
    private var exportTimer: Timer?
    
    weak var delegate: FoodItemRowViewDelegate? // Ensure this is declared at the top level
    
    func didAddFoodItem(_ foodItem: FoodItem) {
            // Handle the updated food item (e.g., refresh UI or update data)
            setSelectedFoodItem(foodItem)
            print("Food item updated: \(foodItem.name ?? "")")
        }
    
    func didSaveAndClose(foodItem: FoodItem) {
        // Update the selectedFoodItem with the edited foodItem
        selectedFoodItem = foodItem

        // Recalculate nutrients
        print("Modal saved and closed. Recalculating nutrients.")
        calculateNutrients()
    }
    
    var foodItems: [FoodItem] = []
    
    
    var netCarbs: Double = 0.0 {
        didSet {
            onValueChange?()
            delegate?.saveToCoreData()
            delegate?.startEditing()
        }
    }
    var netFat: Double = 0.0 {
        didSet {
            onValueChange?()
            delegate?.saveToCoreData()
            delegate?.startEditing()
        }
    }
    var netProtein: Double = 0.0 {
        didSet {
            onValueChange?()
            delegate?.saveToCoreData()
            delegate?.startEditing()
        }
    }
        
        var selectedFoodItem: FoodItem?
        var foodItemRow: FoodItemRow?
        
        let infoLabel: UILabel = {
            let label = UILabel()
            label.text = "ⓘ "
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 13).isActive = true
            label.textColor = .label
            label.adjustsFontSizeToFitWidth = true
            label.isHidden = true
            label.font = UIFont.boldSystemFont(ofSize: label.font.pointSize)
            return label
        }()
        
        let foodItemLabel: UILabel = {
            let label = UILabel()
            label.text = "Food Item"
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textColor = .label
            label.isUserInteractionEnabled = true
            return label
        }()
        
        var foodItemLabelWidthConstraintWithInfo: NSLayoutConstraint!
        var foodItemLabelWidthConstraintWithoutInfo: NSLayoutConstraint!
        
        let portionServedTextField: UITextField = {
            let textField = UITextField()
            textField.placeholder = "..."
            textField.borderStyle = .roundedRect
            textField.keyboardType = .decimalPad
            textField.textAlignment = .right
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.widthAnchor.constraint(equalToConstant: 48).isActive = true
            textField.backgroundColor = .systemGray2.withAlphaComponent(0.2)
            textField.textColor = .label
            textField.adjustsFontSizeToFitWidth = true
            return textField
        }()
        
        let ppOr100g: UILabel = {
            let label = UILabel()
            label.textColor = .gray
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 17).isActive = true
            label.textAlignment = .left
            label.textColor = .label
            label.adjustsFontSizeToFitWidth = true
            return label
        }()
        
        let notEatenTextField: UITextField = {
            let textField = UITextField()
            textField.placeholder = "..."
            textField.borderStyle = .roundedRect
            textField.keyboardType = .decimalPad
            textField.textAlignment = .right
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.widthAnchor.constraint(equalToConstant: 48).isActive = true
            textField.backgroundColor = .systemGray2.withAlphaComponent(0.2)
            textField.textColor = .label
            textField.adjustsFontSizeToFitWidth = true
            return textField
        }()
        
        let netCarbsLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 50).isActive = true
            label.textAlignment = .right
            label.textColor = .label
            label.adjustsFontSizeToFitWidth = true
            return label
        }()
        
        let deleteButton: UIButton = {
            let button = UIButton(type: .system)
            let trashImage = UIImage(systemName: "trash")
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular, scale: .medium)
            let resizedImage = trashImage?.applyingSymbolConfiguration(config)
            button.setImage(resizedImage, for: .normal)
            button.widthAnchor.constraint(equalToConstant: 25).isActive = true
            button.tintColor = .red
            button.translatesAutoresizingMaskIntoConstraints = false
            return button
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupView()
            addInputAccessoryView()
            setupLabelTapGesture()
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupView() {
            let stackView = UIStackView(arrangedSubviews: [infoLabel, foodItemLabel, portionServedTextField, ppOr100g, notEatenTextField, netCarbsLabel, deleteButton])
            stackView.axis = .horizontal
            stackView.spacing = 2
            stackView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stackView)
            
            foodItemLabelWidthConstraintWithInfo = foodItemLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 125)
            foodItemLabelWidthConstraintWithoutInfo = foodItemLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
            foodItemLabelWidthConstraintWithoutInfo.isActive = true
            
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
                stackView.topAnchor.constraint(equalTo: topAnchor),
                stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            
            setupSwipeGesture()
            deleteButton.isHidden = true
            deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
            
            portionServedTextField.addTarget(self, action: #selector(calculateNutrients), for: .editingChanged)
            portionServedTextField.delegate = self // Set delegate
            
            notEatenTextField.addTarget(self, action: #selector(calculateNutrients), for: .editingChanged)
            notEatenTextField.delegate = self // Set delegate
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            delegate?.saveToCoreData()
            delegate?.stopEditing()
        }
    
    private func setupSwipeGesture() {
        let swipeLeftGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeLeftGesture.direction = .left
        addGestureRecognizer(swipeLeftGesture)
        
        let swipeRightGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeRightGesture.direction = .right
        addGestureRecognizer(swipeRightGesture)
    }
    
    @objc private func handleSwipeGesture(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left {
            UIView.animate(withDuration: 0.3) {
                self.deleteButton.isHidden = false
            }
        } else if gesture.direction == .right {
            UIView.animate(withDuration: 0.3) {
                self.deleteButton.isHidden = true
            }
        }
    }
    
    func hideDeleteButton() {
        UIView.animate(withDuration: 0.3) {
            self.deleteButton.isHidden = true
        }
    }
    
    @objc private func deleteButtonTapped() {
        onDelete?()
        delegate?.deleteFoodItemRow(self)
        hideDeleteButton() // Hide the delete button after deletion
        delegate?.stopEditing()
    }
        
        private func setupLabelTapGesture() {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(foodItemLabelTapped))
            foodItemLabel.addGestureRecognizer(tapGesture)
        }
        
        private func addInputAccessoryView() {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            
            let doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Klar"), style: .plain, target: self, action: #selector(doneButtonTapped))
            let nextButton = UIBarButtonItem(title: NSLocalizedString("Nästa", comment: "Nästa"), style: .plain, target: self, action: #selector(nextButtonTapped))
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            
            toolbar.setItems([nextButton, flexSpace, doneButton], animated: false)
            
            portionServedTextField.inputAccessoryView = toolbar
            notEatenTextField.inputAccessoryView = toolbar
        }
        
    @objc private func foodItemLabelTapped() {
        guard let selectedFoodItem = selectedFoodItem else { return }

        var emoji = selectedFoodItem.emoji ?? ""
        emoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        emoji = emoji.precomposedStringWithCanonicalMapping  // Normalize emoji

        let title = "\(emoji) \(selectedFoodItem.name ?? "")"
        var message = ""

        if let notes = selectedFoodItem.notes, !notes.isEmpty {
            message += String(format: NSLocalizedString("\nⓘ %@\n", comment: "\nNot: %@\n"), notes)
        }

        if selectedFoodItem.perPiece {
            let carbsPP = selectedFoodItem.carbsPP
            let fatPP = selectedFoodItem.fatPP
            let proteinPP = selectedFoodItem.proteinPP

            if carbsPP > 0 {
                message += String(format: NSLocalizedString("\nKolhydrater: %.1f g / st", comment: "\nKolhydrater: %.1f g / st"), carbsPP)
            }
            if fatPP > 0 {
                message += String(format: NSLocalizedString("\nFett: %.1f g / st", comment: "\nFett: %.1f g / st"), fatPP)
            }
            if proteinPP > 0 {
                message += String(format: NSLocalizedString("\nProtein: %.1f g / st", comment: "\nProtein: %.1f g / st"), proteinPP)
            }
        } else {
            let carbohydrates = selectedFoodItem.carbohydrates
            let fat = selectedFoodItem.fat
            let protein = selectedFoodItem.protein

            if carbohydrates > 0 {
                message += String(format: NSLocalizedString("\nKolhydrater: %.1f g / 100 g", comment: "\nKolhydrater: %.1f g / 100 g"), carbohydrates)
            }
            if fat > 0 {
                message += String(format: NSLocalizedString("\nFett: %.1f g / 100 g", comment: "\nFett: %.1f g / 100 g"), fat)
            }
            if protein > 0 {
                message += String(format: NSLocalizedString("\nProtein: %.1f g / 100 g", comment: "\nProtein: %.1f g / 100 g"), protein)
            }
        }

        if message.isEmpty {
            message = NSLocalizedString("Ingen näringsinformation tillgänglig.", comment: "Ingen näringsinformation tillgänglig.")
        } else {
            message = String(message.dropLast())
            
            let regex = try! NSRegularExpression(pattern: "\\.0", options: [])
            message = regex.stringByReplacingMatches(in: message, options: [], range: NSRange(location: 0, length: message.utf16.count), withTemplate: "")
        }

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel"), style: .cancel, handler: nil)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Redigera näringsvärden", comment: "Edit food item"), style: .default, handler: { _ in
            self.editSelectedFoodItem(selectedFoodItem)
        }))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Visa portionsförslag", comment: "Serving size button"), style: .default, handler: { _ in
            self.presentMealInsightsViewController(with: selectedFoodItem)
        }))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Hitta liknande måltider", comment: "Show similar meals"), style: .default, handler: { _ in
            self.presentMealHistoryViewControllerAndRunBestMatches()
        }))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Visa historik", comment: "Show history"), style: .default, handler: { _ in
            self.presentMealHistoryViewController(with: selectedFoodItem) // Add funcs to open MealHistoryViewController and populate the searchtext with selectedFoodItem
        }))
        alertController.addAction(cancelAction)

        if let viewController = self.getViewController() {
            viewController.present(alertController, animated: true, completion: nil)
        }
    }

    
    private func presentMealInsightsViewController(with selectedFoodItem: FoodItem) {
        // Create an instance of MealInsightsViewController
        let mealInsightsVC = MealInsightsViewController()

        // Prepopulate the search text field with the foodItem name
        mealInsightsVC.prepopulatedSearchText = selectedFoodItem.name ?? ""
        mealInsightsVC.prepopulatedSearchTextId = selectedFoodItem.id ?? nil
        
        mealInsightsVC.isComingFromFoodItemRow = true

        // Set the completion handler to update the portionServedTextField
        mealInsightsVC.onAveragePortionSelected = { [weak self] averagePortion in
            guard let self = self else { return }
            self.portionServedTextField.text = String(format: "%.0f", averagePortion)
            self.calculateNutrients()  // Optionally recalculate nutrients after setting the portion
        }

        // Embed the MealInsightsViewController in a UINavigationController
        let navController = UINavigationController(rootViewController: mealInsightsVC)

        // Set the modal presentation style
        navController.modalPresentationStyle = .pageSheet

        // Customize the sheet behavior
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.preferredCornerRadius = 24
        }

        // Get the top view controller and present the modal
        if let topVC = getTopViewController() {
            topVC.present(navController, animated: true, completion: nil)
        }
    }
    
    private func presentMealHistoryViewController(with selectedFoodItem: FoodItem) {
        guard let viewController = self.getViewController() else { return }
        
        // Create an instance of MealHistoryViewController
        let mealHistoryVC = MealHistoryViewController()
        
        // Set the selectedFoodItem's name and ID for the initial search
        mealHistoryVC.initialSearchText = selectedFoodItem.name
        mealHistoryVC.initialSearchTextId = selectedFoodItem.id
        
        // Present the MealHistoryViewController
        viewController.navigationController?.pushViewController(mealHistoryVC, animated: true)
    }
    
    private func presentMealHistoryViewControllerAndRunBestMatches() {
        guard let viewController = self.getViewController() else { return }
        
        // Create an instance of MealHistoryViewController
        let mealHistoryVC = MealHistoryViewController()
        
        // Set the flag to indicate that we are coming from the best matches view
        mealHistoryVC.isComingFromBestMatches = true
        
        // Push the MealHistoryViewController to the navigation stack
        viewController.navigationController?.pushViewController(mealHistoryVC, animated: true)
    }
    
    private func editSelectedFoodItem(_ foodItem: FoodItem) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self // Set the delegate
            addFoodItemVC.foodItem = foodItem
            let navController = UINavigationController(rootViewController: addFoodItemVC)
            navController.modalPresentationStyle = .pageSheet
            
            if let viewController = self.getViewController() {
                viewController.present(navController, animated: true, completion: nil)
            }
        }
    }
    
    func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene })
            .first,
            let rootVC = windowScene.windows.filter({ $0.isKeyWindow }).first?.rootViewController else {
                return nil
        }
        
        var topController: UIViewController = rootVC
        while let newTopController = topController.presentedViewController {
            topController = newTopController
        }
        return topController
    }
        
        private func getViewController() -> UIViewController? {
            var nextResponder: UIResponder? = self
            while nextResponder != nil {
                nextResponder = nextResponder?.next
                if let viewController = nextResponder as? UIViewController {
                    return viewController
                }
            }
            return nil
        }

        @objc func calculateNutrients() {
            guard let selectedFoodItem = selectedFoodItem else { return }
            let portionServed = Double(portionServedTextField.text?.replacingOccurrences(of: ",", with: ".") ?? "") ?? 0
            let notEaten = Double(notEatenTextField.text?.replacingOccurrences(of: ",", with: ".") ?? "") ?? 0
            
            if selectedFoodItem.perPiece {
                let carbsPerPiece = selectedFoodItem.carbsPP
                let fatPerPiece = selectedFoodItem.fatPP
                let proteinPerPiece = selectedFoodItem.proteinPP
                netCarbs = (carbsPerPiece * portionServed) - (carbsPerPiece * notEaten)
                netFat = (fatPerPiece * portionServed) - (fatPerPiece * notEaten)
                netProtein = (proteinPerPiece * portionServed) - (proteinPerPiece * notEaten)
            } else {
                let carbsPer100g = selectedFoodItem.carbohydrates
                let fatPer100g = selectedFoodItem.fat
                let proteinPer100g = selectedFoodItem.protein
                netCarbs = (carbsPer100g * portionServed / 100) - (carbsPer100g * notEaten / 100)
                netFat = (fatPer100g * portionServed / 100) - (fatPer100g * notEaten / 100)
                netProtein = (proteinPer100g * portionServed / 100) - (proteinPer100g * notEaten / 100)
            }
            netCarbsLabel.text = String(format: "%.0f g", netCarbs)
            delegate?.saveToCoreData() // Call the delegate method
            delegate?.startEditing()
        }
        
        @objc private func doneButtonTapped() {
            portionServedTextField.resignFirstResponder()
            notEatenTextField.resignFirstResponder()
            delegate?.stopEditing()
        }
        
        @objc private func nextButtonTapped() {
            if portionServedTextField.isFirstResponder {
                delegate?.didTapNextButton(self, currentTextField: portionServedTextField)
            } else if notEatenTextField.isFirstResponder {
                delegate?.didTapNextButton(self, currentTextField: notEatenTextField)
            }
        }
        
    func setSelectedFoodItem(_ item: FoodItem) {
        print("setSelectedFoodItem called with food item: \(item.name ?? "")")
        self.selectedFoodItem = item
        foodItemLabel.text = item.name
        print("Food item name set to: \(item.name ?? "")")
            delegate?.saveToCoreData() // Call the delegate method
            
            if let notes = item.notes, !notes.isEmpty {
                infoLabel.isHidden = false
                foodItemLabelWidthConstraintWithoutInfo.isActive = false
                foodItemLabelWidthConstraintWithInfo.isActive = true
            } else {
                infoLabel.isHidden = true
                foodItemLabelWidthConstraintWithInfo.isActive = false
                foodItemLabelWidthConstraintWithoutInfo.isActive = true
            }
            
            ppOr100g.text = item.perPiece ? NSLocalizedString("st", comment: "st") : NSLocalizedString("g", comment: "g")
            calculateNutrients()
            delegate?.startEditing()
        }
        
        func deleteFromCoreData() {
            let context = CoreDataStack.shared.context
            guard let foodItemRow = foodItemRow else { return }
            
            context.delete(foodItemRow)
            
            do {
                try context.save()
            } catch {
                print("Failed to delete FoodItemRow: \(error)")
            }
            delegate?.stopEditing()
        }
    }


