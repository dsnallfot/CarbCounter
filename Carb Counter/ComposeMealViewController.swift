//
//  ComposeMealViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-17.
//

import UIKit
import CoreData

class ComposeMealViewController: UIViewController, FoodItemRowViewDelegate, AddFoodItemDelegate {
    
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
    
    // Add an outlet for the "Clear All" button
    var clearAllButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Meal"
        
        // Setup the fixed header containing summary and headline
        let fixedHeaderContainer = UIView()
        fixedHeaderContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fixedHeaderContainer)
        
        NSLayoutConstraint.activate([
            fixedHeaderContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            fixedHeaderContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fixedHeaderContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fixedHeaderContainer.heightAnchor.constraint(equalToConstant: 107) // Adjust height as needed
        ])
        
        // Setup summary view
        setupSummaryView(in: fixedHeaderContainer)
        
        // Setup headline
        setupHeadline(in: fixedHeaderContainer)
        
        // Setup scroll view
        setupScrollView(below: fixedHeaderContainer)
        
        // Initialize "Clear All" button
        clearAllButton = UIBarButtonItem(title: "Clear all", style: .plain, target: self, action: #selector(clearAllButtonTapped))
        clearAllButton.tintColor = .red // Set the button color to red
        navigationItem.rightBarButtonItem = clearAllButton
        
        // Ensure searchableDropdownView is properly initialized
        setupSearchableDropdownView()
        
        searchableDropdownView.onDoneButtonTapped = { [weak self] in
            self?.searchableDropdownView.isHidden = true
            self?.clearAllButton?.isEnabled = true // Show the "Clear All" button
        }
        
        // Fetch food items and add the add button row
        fetchFoodItems()
        updateClearAllButtonState() // Add this line
        
        // Add observers for keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    deinit {
        // Remove observers for keyboard notifications
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func clearAllButtonTapped() {
        view.endEditing(true) // This will hide the keyboard
        let alertController = UIAlertController(title: "Clear All", message: "Do you want to clear all entries?", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let yesAction = UIAlertAction(title: "Yes", style: .destructive) { _ in
            self.clearAllFoodItems()
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
        view.endEditing(true) // Hide the keyboard
        updateClearAllButtonState() // Add this line
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
        
        // Fetch food items and add the add button row
        fetchFoodItems()
        updateClearAllButtonState() // Add this line
        addAddButtonRow()
    }
    
    private func setupSummaryView(in container: UIView) {
        let summaryView = UIView()
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        summaryView.backgroundColor = .secondarySystemBackground // Set background color to secondary system background
        container.addSubview(summaryView)

        // Create the CARBS container
        let carbsContainer = createContainerView(backgroundColor: .systemOrange)
        summaryView.addSubview(carbsContainer)
        
        let summaryLabel = createLabel(text: "CARBS", fontSize: 10, weight: .bold, color: .white)
        totalNetCarbsLabel = createLabel(text: "0 g", fontSize: 18, weight: .bold, color: .white)
        let carbsStack = UIStackView(arrangedSubviews: [summaryLabel, totalNetCarbsLabel])
        setupStackView(carbsStack, in: carbsContainer)

        // Create the FAT container
        let fatContainer = createContainerView(backgroundColor: .systemBrown)
        summaryView.addSubview(fatContainer)

        let netFatLabel = createLabel(text: "FAT", fontSize: 10, weight: .bold, color: .white)
        totalNetFatLabel = createLabel(text: "0 g", fontSize: 18, weight: .bold, color: .white)
        let fatStack = UIStackView(arrangedSubviews: [netFatLabel, totalNetFatLabel])
        setupStackView(fatStack, in: fatContainer)

        // Create the PROTEIN container
        let proteinContainer = createContainerView(backgroundColor: .systemBrown)
        summaryView.addSubview(proteinContainer)

        let netProteinLabel = createLabel(text: "PROTEIN", fontSize: 10, weight: .bold, color: .white)
        totalNetProteinLabel = createLabel(text: "0 g", fontSize: 18, weight: .bold, color: .white)
        let proteinStack = UIStackView(arrangedSubviews: [netProteinLabel, totalNetProteinLabel])
        setupStackView(proteinStack, in: proteinContainer)

        // Arrange the containers in a horizontal stack view
        let hStack = UIStackView(arrangedSubviews: [fatContainer, proteinContainer, carbsContainer])
        hStack.axis = .horizontal
        hStack.spacing = 8
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.distribution = .fillEqually
        summaryView.addSubview(hStack)

        NSLayoutConstraint.activate([
            summaryView.heightAnchor.constraint(equalToConstant: 65),
            summaryView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            summaryView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            summaryView.topAnchor.constraint(equalTo: container.topAnchor),

            hStack.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor, constant: -16),
            hStack.topAnchor.constraint(equalTo: summaryView.topAnchor, constant: 12),
            hStack.bottomAnchor.constraint(equalTo: summaryView.bottomAnchor, constant: -12)
        ])
    }

    private func createContainerView(backgroundColor: UIColor) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = backgroundColor
        containerView.layer.cornerRadius = 8
        containerView.clipsToBounds = true
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

    private func setupStackView(_ stackView: UIStackView, in containerView: UIView) {
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4)
        ])
    }

    private func updateTotalNutrients() {
        let totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }
        totalNetCarbsLabel?.text = String(format: "%.1f g", totalNetCarbs)

        let totalNetFat = foodItemRows.reduce(0.0) { $0 + $1.netFat }
        totalNetFatLabel?.text = String(format: "%.1f g", totalNetFat)

        let totalNetProtein = foodItemRows.reduce(0.0) { $0 + $1.netProtein }
        totalNetProteinLabel?.text = String(format: "%.1f g", totalNetProtein)
    }
    private func setupHeadline(in container: UIView) {
        let headlineContainer = UIView()
        headlineContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headlineContainer)
        
        NSLayoutConstraint.activate([
            headlineContainer.topAnchor.constraint(equalTo: container.bottomAnchor, constant: -37),
            headlineContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headlineContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headlineContainer.heightAnchor.constraint(equalToConstant: 42) // Adjust height as needed
        ])
        
        let headlineStackView = UIStackView()
        headlineStackView.axis = .horizontal
        headlineStackView.spacing = 2
        headlineStackView.distribution = .fillProportionally
        headlineStackView.translatesAutoresizingMaskIntoConstraints = false
        headlineContainer.addSubview(headlineStackView)
        
        let font = UIFont.systemFont(ofSize: 11)
        
        let foodItemLabel = UILabel()
        foodItemLabel.text = "FOOD ITEM                 "
        foodItemLabel.textAlignment = .left
        foodItemLabel.font = font
        foodItemLabel.textColor = .gray
        
        let portionServedLabel = UILabel()
        portionServedLabel.text = "SERVED   "
        portionServedLabel.textAlignment = .left
        portionServedLabel.font = font
        portionServedLabel.textColor = .gray
        
        let notEatenLabel = UILabel()
        notEatenLabel.text = "   LEFT  "
        notEatenLabel.textAlignment = .left
        notEatenLabel.font = font
        notEatenLabel.textColor = .gray
        
        let netCarbsLabel = UILabel()
        netCarbsLabel.text = "NET CARBS"
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
    
    private func setupSearchableDropdownView() {
        searchableDropdownView = SearchableDropdownView()
        searchableDropdownView.translatesAutoresizingMaskIntoConstraints = false
        searchableDropdownView.isHidden = true
        view.addSubview(searchableDropdownView)
        
        NSLayoutConstraint.activate([
            searchableDropdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchableDropdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchableDropdownView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 62), //Justerar var sökfältet renderas
            searchableDropdownView.heightAnchor.constraint(equalToConstant: 400)
        ])
        
        searchableDropdownView.onSelectItem = { [weak self] foodItem in
            self?.searchableDropdownView.isHidden = true
            self?.addFoodItemRow(with: foodItem)
            self?.clearAllButton.isEnabled = true // Show the "Clear All" button
        }
        
        searchableDropdownView.onDoneButtonTapped = { [weak self] in
            self?.searchableDropdownView.isHidden = true
            self?.clearAllButton.isEnabled = true // Show the "Clear All" button
        }
    }
    
    private func fetchFoodItems() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        do {
            foodItems = try context.fetch(fetchRequest).sorted { ($0.name ?? "") < ($1.name ?? "") }
            
            // Ensure searchableDropdownView is not nil before calling updateFoodItems
            if let searchableDropdownView = searchableDropdownView {
                searchableDropdownView.updateFoodItems(foodItems) // Update the dropdown view with the new items
            }
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
        updateClearAllButtonState() // Add this line
    }
    
    private func addAddButtonRow() {
        addButtonRowView = AddButtonRowView()
        addButtonRowView.translatesAutoresizingMaskIntoConstraints = false
        addButtonRowView.addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        
        stackView.addArrangedSubview(addButtonRowView)
    }
    
    @objc private func addButtonTapped() {
        // Ensure that the searchableDropdownView is added to the view hierarchy if not already added
        if searchableDropdownView.superview == nil {
            view.addSubview(searchableDropdownView)
            NSLayoutConstraint.activate([
                searchableDropdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                searchableDropdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                searchableDropdownView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                searchableDropdownView.heightAnchor.constraint(equalToConstant: 400)
            ])
        }
        
        // Show the searchableDropdownView and make the searchBar the first responder
        searchableDropdownView.isHidden = false
        DispatchQueue.main.async {
            self.searchableDropdownView.searchBar.becomeFirstResponder()
        }
        clearAllButton.isEnabled = false // Hide the "Clear All" button
    }
    
    private func removeFoodItemRow(_ rowView: FoodItemRowView) {
        stackView.removeArrangedSubview(rowView)
        rowView.removeFromSuperview()
        if let index = foodItemRows.firstIndex(of: rowView) {
            foodItemRows.remove(at: index)
        }
        moveAddButtonRowToEnd()
        updateTotalNutrients()
        updateClearAllButtonState() // Add this line
    }
    
    private func moveAddButtonRowToEnd() {
        stackView.removeArrangedSubview(addButtonRowView)
        stackView.addArrangedSubview(addButtonRowView)
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
        if let clearAllButton = clearAllButton {
            clearAllButton.isEnabled = !foodItemRows.isEmpty
        }
    }
    
    // MARK: - FoodItemRowViewDelegate
    
    func didTapFoodItemTextField(_ rowView: FoodItemRowView) {
        // Ensure that the searchableDropdownView is added to the view hierarchy if not already added
        if searchableDropdownView.superview == nil {
            view.addSubview(searchableDropdownView)
            NSLayoutConstraint.activate([
                searchableDropdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                searchableDropdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                searchableDropdownView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                searchableDropdownView.heightAnchor.constraint(equalToConstant: 400)
            ])
        }
        
        // Show the searchableDropdownView and make the searchBar the first responder
        searchableDropdownView.isHidden = false
        DispatchQueue.main.async {
            self.searchableDropdownView.searchBar.becomeFirstResponder()
        }
        clearAllButton.isEnabled = false // Hide the "Clear All" button
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
        fetchFoodItems() // Update the food items after adding a new one
    }
    
    // Separate class for Add Button Row
    class AddButtonRowView: UIView {
        let addButton: UIButton = {
            let button = UIButton(type: .contactAdd)
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
                addButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                addButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                addButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
            ])
        }
    }
}
