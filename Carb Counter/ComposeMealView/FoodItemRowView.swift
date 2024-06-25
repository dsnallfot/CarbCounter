//
//  FoodItemRowView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-19.
//
import UIKit

protocol FoodItemRowViewDelegate: AnyObject {
    func didTapNextButton(_ rowView: FoodItemRowView, currentTextField: UITextField)
}

class FoodItemRowView: UIView {
    
    var onDelete: (() -> Void)?
    var onValueChange: (() -> Void)?
    
    var netCarbs: Double = 0.0 {
        didSet {
            onValueChange?()
        }
    }
    var netFat: Double = 0.0 {
        didSet {
            onValueChange?()
        }
    }
    var netProtein: Double = 0.0 {
        didSet {
            onValueChange?()
        }
    }
    
    weak var delegate: FoodItemRowViewDelegate?
    var foodItems: [FoodItem] = []
    
    let infoLabel: UILabel = {
        let label = UILabel()
        label.text = "ⓘ "
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 13).isActive = true
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.isHidden = true
        label.font = UIFont.boldSystemFont(ofSize: label.font.pointSize) // Set the font to bold
        return label
    }()
    
    let foodItemLabel: UILabel = {
        let label = UILabel()
        label.text = "Food Item"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .label
        label.isUserInteractionEnabled = true // Make the label interactable
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
        textField.backgroundColor = .secondarySystemBackground
        textField.textColor = .label
        textField.adjustsFontSizeToFitWidth = true
        return textField
    }()
    
    let ppOr100g: UILabel = {
        let label = UILabel()
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 14).isActive = true
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
        textField.backgroundColor = .secondarySystemBackground
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
        button.tintColor = .red
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    var selectedFoodItem: FoodItem?
    
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
        
        foodItemLabelWidthConstraintWithInfo = foodItemLabel.widthAnchor.constraint(equalToConstant: 125)
        foodItemLabelWidthConstraintWithoutInfo = foodItemLabel.widthAnchor.constraint(equalToConstant: 140)
        foodItemLabelWidthConstraintWithoutInfo.isActive = true
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        
        portionServedTextField.addTarget(self, action: #selector(calculateNutrients), for: .editingChanged)
        notEatenTextField.addTarget(self, action: #selector(calculateNutrients), for: .editingChanged)
    }
    
    private func setupLabelTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(foodItemLabelTapped))
        foodItemLabel.addGestureRecognizer(tapGesture)
    }
    
    private func addInputAccessoryView() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Klar", style: .plain, target: self, action: #selector(doneButtonTapped))
        let nextButton = UIBarButtonItem(title: "Nästa", style: .plain, target: self, action: #selector(nextButtonTapped))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.setItems([nextButton, flexSpace, doneButton], animated: false)
        
        portionServedTextField.inputAccessoryView = toolbar
        notEatenTextField.inputAccessoryView = toolbar
    }
    
    @objc private func foodItemLabelTapped() {
        guard let selectedFoodItem = selectedFoodItem else { return }
        
        let name = selectedFoodItem.name ?? "Unknown"
        var message = ""
        
        if let notes = selectedFoodItem.notes, !notes.isEmpty {
            message += "Not: \(notes)\n\n"
        }
        
        if selectedFoodItem.perPiece {
            let carbsPP = selectedFoodItem.carbsPP
            let fatPP = selectedFoodItem.fatPP
            let proteinPP = selectedFoodItem.proteinPP
            
            if carbsPP > 0 {
                message += "Kolhydrater: \(carbsPP) g/st\n"
            }
            if fatPP > 0 {
                message += "Fett: \(fatPP) g/st\n"
            }
            if proteinPP > 0 {
                message += "Protein: \(proteinPP) g/st\n"
            }
        } else {
            let carbohydrates = selectedFoodItem.carbohydrates
            let fat = selectedFoodItem.fat
            let protein = selectedFoodItem.protein
            
            if carbohydrates > 0 {
                message += "Kolhydrater: \(carbohydrates)/100 g\n"
            }
            if fat > 0 {
                message += "Fett: \(fat)/100 g\n"
            }
            if protein > 0 {
                message += "Protein: \(protein)/100 g\n"
            }
        }
        
        if message.isEmpty {
            message = "Ingen näringsinformation tillgänglig."
        } else {
            // Remove the last newline character
            message = String(message.dropLast())
            
            // Regex replacement for ".0"
            let regex = try! NSRegularExpression(pattern: "\\.0", options: [])
            message = regex.stringByReplacingMatches(in: message, options: [], range: NSRange(location: 0, length: message.utf16.count), withTemplate: "")
        }
        
        let alertController = UIAlertController(title: name, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        if let viewController = self.getViewController() {
            viewController.present(alertController, animated: true, completion: nil)
        }
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
    @objc private func deleteButtonTapped() {
        onDelete?()
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
    }
    
    @objc private func doneButtonTapped() {
        portionServedTextField.resignFirstResponder()
        notEatenTextField.resignFirstResponder()
    }
    
    @objc private func nextButtonTapped() {
        if portionServedTextField.isFirstResponder {
            delegate?.didTapNextButton(self, currentTextField: portionServedTextField)
        } else if notEatenTextField.isFirstResponder {
            delegate?.didTapNextButton(self, currentTextField: notEatenTextField)
        }
    }
    
    func setSelectedFoodItem(_ item: FoodItem) {
        self.selectedFoodItem = item
        foodItemLabel.text = item.name
        
        if let notes = item.notes, !notes.isEmpty {
            infoLabel.isHidden = false
            foodItemLabelWidthConstraintWithoutInfo.isActive = false
            foodItemLabelWidthConstraintWithInfo.isActive = true
        } else {
            infoLabel.isHidden = true
            foodItemLabelWidthConstraintWithInfo.isActive = false
            foodItemLabelWidthConstraintWithoutInfo.isActive = true
        }
        
        ppOr100g.text = item.perPiece ? "st" : "g"
        calculateNutrients()
    }
}
   
