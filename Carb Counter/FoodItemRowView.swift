//
//  FoodItemRowView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-19.
//

import UIKit

class FoodItemRowView: UIView, UIPickerViewDataSource, UIPickerViewDelegate {
    
    var onDelete: (() -> Void)?
    
    var foodItems: [FoodItem] = []
    
    let foodItemTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Food Item"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 120).isActive = true
        return textField
    }()
    
    let portionServedTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "  .. g"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        return textField
    }()
    
    let notEatenTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "  .. g"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        return textField
    }()
    
    let netCarbsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 70).isActive = true
        label.textAlignment = .center
        return label
    }()
    
    let deleteButton: UIButton = {
        let button = UIButton(type: .system)
        let trashImage = UIImage(systemName: "trash")
        button.setImage(trashImage, for: .normal)
        button.tintColor = .red
        button.imageView?.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let pickerView = UIPickerView()
    private var selectedFoodItem: FoodItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupPickerView()
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
    
    private func setupPickerView() {
        pickerView.dataSource = self
        pickerView.delegate = self
        
        foodItemTextField.inputView = pickerView
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePicker))
        toolbar.setItems([doneButton], animated: true)
        foodItemTextField.inputAccessoryView = toolbar
    }
    
    @objc private func deleteButtonTapped() {
        onDelete?()
    }
    
    @objc private func calculateNetCarbs() {
        guard let selectedFoodItem = selectedFoodItem else { return }
        let carbsPer100g = selectedFoodItem.carbohydrates
        let portionServed = Double(portionServedTextField.text ?? "") ?? 0
        let notEaten = Double(notEatenTextField.text ?? "") ?? 0
        let netCarbs = (carbsPer100g * portionServed / 100) - (carbsPer100g * notEaten / 100)
        netCarbsLabel.text = String(format: "%.1f g", netCarbs)
    }
    
    @objc private func donePicker() {
        foodItemTextField.resignFirstResponder()
        if let selectedFoodItem = selectedFoodItem {
            foodItemTextField.text = selectedFoodItem.name
            calculateNetCarbs()
        }
    }
    
    // MARK: - UIPickerView DataSource and Delegate
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return foodItems.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return foodItems[row].name
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedFoodItem = foodItems[row]
        foodItemTextField.text = selectedFoodItem?.name
        calculateNetCarbs()
    }
}
