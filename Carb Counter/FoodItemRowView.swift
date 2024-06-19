//
//  FoodItemRowView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-19.
//

import UIKit

protocol FoodItemRowViewDelegate: AnyObject {
    func didTapFoodItemTextField(_ rowView: FoodItemRowView)
}

class FoodItemRowView: UIView {
    
    var onDelete: (() -> Void)?
    var onValueChange: (() -> Void)?
    var netCarbs: Double = 0.0 {
        didSet {
            onValueChange?()
        }
    }
    
    weak var delegate: FoodItemRowViewDelegate?
    var foodItems: [FoodItem] = []
    
    let foodItemTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Food Item"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 120).isActive = true
        textField.backgroundColor = .systemBackground
        textField.textColor = .label
        return textField
    }()
    
    let portionServedTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "  .. g"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        textField.textAlignment = .right
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        textField.backgroundColor = .systemBackground
        textField.textColor = .label
        return textField
    }()
    
    let notEatenTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "  .. g"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        textField.textAlignment = .right
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        textField.backgroundColor = .systemBackground
        textField.textColor = .label
        return textField
    }()
    
    let netCarbsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 70).isActive = true
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
    
    private var selectedFoodItem: FoodItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupTextFieldTargets()
        setupInputAccessoryViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        let stackView = UIStackView(arrangedSubviews: [foodItemTextField, portionServedTextField, notEatenTextField, netCarbsLabel, deleteButton])
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
        
        portionServedTextField.addTarget(self, action: #selector(calculateNetCarbs), for: .editingChanged)
        notEatenTextField.addTarget(self, action: #selector(calculateNetCarbs), for: .editingChanged)
    }

    private func setupTextFieldTargets() {
        foodItemTextField.addTarget(self, action: #selector(foodItemTextFieldTapped), for: .editingDidBegin)
    }
    
    private func setupInputAccessoryViews() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
        toolbar.setItems([doneButton], animated: true)
        
        foodItemTextField.inputAccessoryView = toolbar
        portionServedTextField.inputAccessoryView = toolbar
        notEatenTextField.inputAccessoryView = toolbar
    }
    
    @objc private func doneButtonTapped() {
        endEditing(true)
    }
    
    @objc private func foodItemTextFieldTapped() {
        delegate?.didTapFoodItemTextField(self)
    }
    
    @objc private func deleteButtonTapped() {
        onDelete?()
    }
    
    @objc private func calculateNetCarbs() {
        guard let selectedFoodItem = selectedFoodItem else { return }
        let carbsPer100g = selectedFoodItem.carbohydrates
        let portionServed = Double(portionServedTextField.text ?? "") ?? 0
        let notEaten = Double(notEatenTextField.text ?? "") ?? 0
        netCarbs = (carbsPer100g * portionServed / 100) - (carbsPer100g * notEaten / 100)
        netCarbsLabel.text = String(format: "%.1f g", netCarbs)
    }
    
    func setSelectedFoodItem(_ item: FoodItem) {
        self.selectedFoodItem = item
        foodItemTextField.text = item.name
        calculateNetCarbs()
    }
}
