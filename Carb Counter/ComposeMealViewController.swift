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
    var searchableDropdownView: SearchableDropdownView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Compose Meal"
        setupScrollView()
        setupStackView()
        setupSummaryView()
        setupHeadline()
        setupSearchableDropdownView()
        fetchFoodItems()
        addAddButtonRow()
        
        // Add "Clear All" button
        let clearAllButton = UIBarButtonItem(title: "Clear All", style: .plain, target: self, action: #selector(clearAllButtonTapped))
        navigationItem.rightBarButtonItem = clearAllButton
        
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
        updateTotalNetCarbs()
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .systemBackground
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
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
    }
    
    private func setupSummaryView() {
        // Add a spacer view for spacing above the summary view
        let topSpacerView = UIView()
        topSpacerView.translatesAutoresizingMaskIntoConstraints = false
        topSpacerView.heightAnchor.constraint(equalToConstant: 12).isActive = true
        stackView.addArrangedSubview(topSpacerView)
        
        let summaryView = UIView()
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        summaryView.backgroundColor = .systemGray // Set background color to system gray

        let summaryLabel = UILabel()
        summaryLabel.text = "Total Net Carbs:"
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false

        totalNetCarbsLabel = UILabel()
        totalNetCarbsLabel.text = "0.0 g"
        totalNetCarbsLabel.translatesAutoresizingMaskIntoConstraints = false

        summaryView.addSubview(summaryLabel)
        summaryView.addSubview(totalNetCarbsLabel)

        NSLayoutConstraint.activate([
            summaryLabel.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor),
            summaryLabel.centerYAnchor.constraint(equalTo: summaryView.centerYAnchor),

            totalNetCarbsLabel.leadingAnchor.constraint(equalTo: summaryLabel.trailingAnchor, constant: 8),
            totalNetCarbsLabel.centerYAnchor.constraint(equalTo: summaryView.centerYAnchor),
            totalNetCarbsLabel.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor)
        ])

        stackView.addArrangedSubview(summaryView)

        // Add a spacer view for spacing between summary view and headline
        let spacerView = UIView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        spacerView.heightAnchor.constraint(equalToConstant: 12).isActive = true
        stackView.addArrangedSubview(spacerView)

        // Add a divider view
        let dividerView = UIView()
        dividerView.translatesAutoresizingMaskIntoConstraints = false
        dividerView.heightAnchor.constraint(equalToConstant: 1.5).isActive = true
        dividerView.backgroundColor = .lightGray
        stackView.addArrangedSubview(dividerView)
    }
    
    private func setupHeadline() {
        let headlineStackView = UIStackView()
        headlineStackView.axis = .horizontal
        headlineStackView.spacing = 2
        headlineStackView.distribution = .fillProportionally
        headlineStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let font = UIFont.systemFont(ofSize: 12)
        
        let foodItemLabel = UILabel()
        foodItemLabel.text = "FOOD ITEM                "
        foodItemLabel.textAlignment = .left
        foodItemLabel.font = font
        
        let portionServedLabel = UILabel()
        portionServedLabel.text = "SERVED"
        portionServedLabel.textAlignment = .left
        portionServedLabel.font = font
        
        let notEatenLabel = UILabel()
        notEatenLabel.text = "LEFT  "
        notEatenLabel.textAlignment = .left
        notEatenLabel.font = font
        
        let netCarbsLabel = UILabel()
        netCarbsLabel.text = "NET CARBS  "
        netCarbsLabel.textAlignment = .left
        netCarbsLabel.font = font
        
        headlineStackView.addArrangedSubview(foodItemLabel)
        headlineStackView.addArrangedSubview(portionServedLabel)
        headlineStackView.addArrangedSubview(notEatenLabel)
        headlineStackView.addArrangedSubview(netCarbsLabel)
        
        stackView.addArrangedSubview(headlineStackView)
    }
    
    private func setupSearchableDropdownView() {
        searchableDropdownView = SearchableDropdownView()
        searchableDropdownView.translatesAutoresizingMaskIntoConstraints = false
        searchableDropdownView.isHidden = true
        view.addSubview(searchableDropdownView)
        
        NSLayoutConstraint.activate([
            searchableDropdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchableDropdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchableDropdownView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchableDropdownView.heightAnchor.constraint(equalToConstant: 400)
        ])
        
        searchableDropdownView.onSelectItem = { [weak self] foodItem in
            self?.searchableDropdownView.isHidden = true
            self?.addFoodItemRow(with: foodItem)
        }
    }
    
    private func fetchFoodItems() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        do {
            foodItems = try context.fetch(fetchRequest).sorted { ($0.name ?? "") < ($1.name ?? "") }
            searchableDropdownView.updateFoodItems(foodItems) // Update the dropdown view with the new items
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
            self?.updateTotalNetCarbs()
        }
        
        updateTotalNetCarbs()
    }
    
    private func addAddButtonRow() {
        addButtonRowView = AddButtonRowView()
        addButtonRowView.translatesAutoresizingMaskIntoConstraints = false
        addButtonRowView.addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        
        stackView.addArrangedSubview(addButtonRowView)
    }
    
    @objc private func addButtonTapped() {
        searchableDropdownView.isHidden = false
        searchableDropdownView.searchBar.becomeFirstResponder()
    }
    
    private func removeFoodItemRow(_ rowView: FoodItemRowView) {
        stackView.removeArrangedSubview(rowView)
        rowView.removeFromSuperview()
        if let index = foodItemRows.firstIndex(of: rowView) {
            foodItemRows.remove(at: index)
        }
        moveAddButtonRowToEnd()
        updateTotalNetCarbs()
    }
    
    private func moveAddButtonRowToEnd() {
        stackView.removeArrangedSubview(addButtonRowView)
        stackView.addArrangedSubview(addButtonRowView)
    }
    
    private func updateTotalNetCarbs() {
        let totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }
        totalNetCarbsLabel.text = String(format: "%.1f g", totalNetCarbs)
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
        searchableDropdownView.isHidden = false
        searchableDropdownView.searchBar.becomeFirstResponder()
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
