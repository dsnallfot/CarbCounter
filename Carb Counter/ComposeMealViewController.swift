//
//  ComposeMealViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-17.
//

import UIKit
import CoreData

class ComposeMealViewController: UIViewController {
    
    var foodItemRows: [FoodItemRowView] = []
    var stackView: UIStackView!
    var scrollView: UIScrollView!
    var contentView: UIView!
    var foodItems: [FoodItem] = []
    var addButtonRowView: AddButtonRowView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Compose Meal"
        setupScrollView()
        setupStackView()
        setupHeadline()
        fetchFoodItems()
        addAddButtonRow()
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
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
    
    private func setupHeadline() {
        let headlineStackView = UIStackView()
        headlineStackView.axis = .horizontal
        headlineStackView.spacing = 2
        headlineStackView.distribution = .fillProportionally
        headlineStackView.translatesAutoresizingMaskIntoConstraints = false

        let foodItemLabel = UILabel()
        foodItemLabel.text = "Food Item    "
        foodItemLabel.textAlignment = .left
        
        let portionServedLabel = UILabel()
        portionServedLabel.text = "Served"
        portionServedLabel.textAlignment = .left
        
        let notEatenLabel = UILabel()
        notEatenLabel.text = "Left  "
        notEatenLabel.textAlignment = .left
        
        let netCarbsLabel = UILabel()
        netCarbsLabel.text = "Net carbs   "
        netCarbsLabel.textAlignment = .left

        headlineStackView.addArrangedSubview(foodItemLabel)
        headlineStackView.addArrangedSubview(portionServedLabel)
        headlineStackView.addArrangedSubview(notEatenLabel)
        headlineStackView.addArrangedSubview(netCarbsLabel)

        stackView.addArrangedSubview(headlineStackView)
    }
    
    private func fetchFoodItems() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        do {
            foodItems = try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch food items: \(error)")
        }
    }
    
    private func addFoodItemRow() {
        let rowView = FoodItemRowView()
        rowView.foodItems = foodItems
        rowView.translatesAutoresizingMaskIntoConstraints = false
        stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count - 1)
        foodItemRows.append(rowView)
        
        rowView.onDelete = { [weak self] in
            self?.removeFoodItemRow(rowView)
        }
    }
    
    private func addAddButtonRow() {
        addButtonRowView = AddButtonRowView()
        addButtonRowView.translatesAutoresizingMaskIntoConstraints = false
        addButtonRowView.addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        
        stackView.addArrangedSubview(addButtonRowView)
    }
    
    @objc private func addButtonTapped() {
        addFoodItemRow()
        moveAddButtonRowToEnd()
    }
    
    private func removeFoodItemRow(_ rowView: FoodItemRowView) {
        stackView.removeArrangedSubview(rowView)
        rowView.removeFromSuperview()
        if let index = foodItemRows.firstIndex(of: rowView) {
            foodItemRows.remove(at: index)
        }
        moveAddButtonRowToEnd()
    }
    
    private func moveAddButtonRowToEnd() {
        stackView.removeArrangedSubview(addButtonRowView)
        stackView.addArrangedSubview(addButtonRowView)
    }
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
