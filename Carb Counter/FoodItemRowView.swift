//
//  FoodItemRowView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-19.
//

import UIKit

protocol FoodItemRowViewDelegate: AnyObject {
    func didTapFoodItemTextField(_ rowView: FoodItemRowView)
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
    
    let foodItemTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Food Item"
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 135).isActive = true
        textField.textColor = .label
        return textField
    }()
    
    let portionServedTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "..."
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        textField.textAlignment = .right
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 45).isActive = true
        textField.backgroundColor = .secondarySystemBackground
        textField.textColor = .label
        return textField
    }()
    
    let ppOr100g: UILabel = {
        let label = UILabel()
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 10).isActive = true
        label.textAlignment = .left
        label.textColor = .label
        return label
    }()
    
    let notEatenTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "..."
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        textField.textAlignment = .right
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 45).isActive = true
        textField.backgroundColor = .secondarySystemBackground
        textField.textColor = .label
        return textField
    }()
    
    let netCarbsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 55).isActive = true
        label.textAlignment = .right
        label.textColor = .label
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
        setupTextFieldTargets()
        addInputAccessoryView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder😊 has not been implemented")
    }
    
    private func setupView() {
        let stackView = UIStackView(arrangedSubviews: [foodItemTextField, portionServedTextField, ppOr100g, notEatenTextField, netCarbsLabel, deleteButton])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
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

    private func setupTextFieldTargets() {
        foodItemTextField.addTarget(self, action: #selector(foodItemTextFieldTapped), for: .editingDidBegin)
    }
    
    private func addInputAccessoryView() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
        let nextButton = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(nextButtonTapped))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.setItems([nextButton, flexSpace, doneButton], animated: false)
        
        portionServedTextField.inputAccessoryView = toolbar
        notEatenTextField.inputAccessoryView = toolbar
    }
    
    @objc private func foodItemTextFieldTapped() {
        delegate?.didTapFoodItemTextField(self)
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
        foodItemTextField.text = item.name
        ppOr100g.text = item.perPiece ? "p" : "g"
        calculateNutrients()
    }
}
