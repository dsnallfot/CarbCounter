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
        clearAllButton = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearAllButtonTapped))
        clearAllButton.tintColor = .red // Set the button color to red
        navigationItem.rightBarButtonItem = clearAllButton
        
        // Ensure searchableDropdownView is properly initialized
        setupSearchableDropdownView()
        
        searchableDropdownView.onDoneButtonTapped = { [weak self] in
            self?.searchableDropdownView.isHidden = true
            self?.clearAllButton.isEnabled = true // Show the "Clear All" button
        }
        
        // Fetch food items and add the add button row
        fetchFoodItems()
        //addAddButtonRow()
        
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
        navigationItem.rightBarButtonItem?.isEnabled = true // Enable the "Clear All" button
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
        addAddButtonRow()
    }
    
    private func setupSummaryView(in container: UIView) {
        let summaryView = UIView()
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        summaryView.backgroundColor = .secondarySystemBackground // Set background color to secondary system background
        container.addSubview(summaryView)
        
        let summaryLabel = UILabel()
        summaryLabel.text = "CARBS"
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular) // Set font size and weight
        summaryLabel.textColor = .systemYellow // Set text color
        summaryLabel.textAlignment = .center

        totalNetCarbsLabel = UILabel()
        totalNetCarbsLabel.text = "0 g"
        totalNetCarbsLabel.translatesAutoresizingMaskIntoConstraints = false
        totalNetCarbsLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold) // Set font size and weight
        totalNetCarbsLabel.textColor = .systemYellow // Set text color
        totalNetCarbsLabel.textAlignment = .center
        
        let netFatLabel = UILabel()
        netFatLabel.text = "FAT"
        netFatLabel.translatesAutoresizingMaskIntoConstraints = false
        netFatLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular) // Set font size and weight
        netFatLabel.textColor = .systemBrown // Set text color
        netFatLabel.textAlignment = .center

        totalNetFatLabel = UILabel()
        totalNetFatLabel.text = "0 g"
        totalNetFatLabel.translatesAutoresizingMaskIntoConstraints = false
        totalNetFatLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold) // Set font size and weight
        totalNetFatLabel.textColor = .systemBrown // Set text color
        totalNetFatLabel.textAlignment = .center

        let netProteinLabel = UILabel()
        netProteinLabel.text = "PROTEIN"
        netProteinLabel.translatesAutoresizingMaskIntoConstraints = false
        netProteinLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular) // Set font size and weight
        netProteinLabel.textColor = .systemBrown // Set text color
        netProteinLabel.textAlignment = .center

        totalNetProteinLabel = UILabel()
        totalNetProteinLabel.text = "0 g"
        totalNetProteinLabel.translatesAutoresizingMaskIntoConstraints = false
        totalNetProteinLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold) // Set font size and weight
        totalNetProteinLabel.textColor = .systemBrown // Set text color
        totalNetProteinLabel.textAlignment = .center

        let fatStack = UIStackView(arrangedSubviews: [netFatLabel, totalNetFatLabel])
        fatStack.axis = .vertical
        fatStack.alignment = .center

        let proteinStack = UIStackView(arrangedSubviews: [netProteinLabel, totalNetProteinLabel])
        proteinStack.axis = .vertical
        proteinStack.alignment = .center
        
        let carbsStack = UIStackView(arrangedSubviews: [summaryLabel, totalNetCarbsLabel])
        carbsStack.axis = .vertical
        carbsStack.alignment = .center

        let hStack = UIStackView(arrangedSubviews: [proteinStack, UIView(), fatStack, UIView(), carbsStack])
        hStack.axis = .horizontal
        hStack.spacing = 4
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.distribution = .equalSpacing
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
    }
    
    private func moveAddButtonRowToEnd() {
        stackView.removeArrangedSubview(addButtonRowView)
        stackView.addArrangedSubview(addButtonRowView)
    }
    
    private func updateTotalNutrients() {
        let totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }
        totalNetCarbsLabel.text = String(format: "%.1f g", totalNetCarbs)
        
        let totalNetFat = foodItemRows.reduce(0.0) { $0 + $1.netFat }
        totalNetFatLabel.text = String(format: "%.1f g", totalNetFat)
        
        let totalNetProtein = foodItemRows.reduce(0.0) { $0 + $1.netProtein }
        totalNetProteinLabel.text = String(format: "%.1f g", totalNetProtein)
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
