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
    var totalNetCarbsLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Compose Meal"
        setupScrollView()
        setupStackView()
        setupSummaryView()
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
        let summaryView = UIView()
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        
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
        spacerView.heightAnchor.constraint(equalToConstant: 16).isActive = true
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

        let font = UIFont.systemFont(ofSize: 14)

        let foodItemLabel = UILabel()
        foodItemLabel.text = "FOOD ITEM        "
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
        netCarbsLabel.text = "NET CARBS "
        netCarbsLabel.textAlignment = .left
        netCarbsLabel.font = font

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
