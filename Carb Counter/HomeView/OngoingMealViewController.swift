import UIKit
import CoreData

class OngoingMealViewController: UIViewController {
    
    var foodItemRows: [FoodItemRow] = []
    var foodItems: [UUID: FoodItem] = [:] // Dictionary to store FoodItems by their ID
    private var importTimer: Timer?
    
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12 // Adjusted spacing for better layout
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupView()
        loadFoodItems()
        loadFoodItemRows()
        
        // Observe for imported ongoing meal data
        NotificationCenter.default.addObserver(self, selector: #selector(didImportOngoingMeal(_:)), name: .didImportOngoingMeal, object: nil)
        }
    
    override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            startImportTimer()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            stopImportTimer()
        }
        
        private func startImportTimer() {
            stopImportTimer() // Stop any existing timer
            importTimer = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(importOngoingMealCSV), userInfo: nil, repeats: true)
        }
        
        private func stopImportTimer() {
            importTimer?.invalidate()
            importTimer = nil
        }

        @objc private func importOngoingMealCSV() {
            // Call the import method from DataSharingViewController
            let dataSharingVC = DataSharingViewController()
            dataSharingVC.importOngoingMealCSV()
        }
    
    private func setupView() {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -16)
        ])
        
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeView))
        navigationItem.leftBarButtonItem = closeButton
        navigationItem.title = "Pågående måltid"
    }
    
    @objc private func closeView() {
        dismiss(animated: true, completion: nil)
    }
    
    private func loadFoodItems() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        do {
            let items = try context.fetch(fetchRequest)
            for item in items {
                if let id = item.id {
                    foodItems[id] = item
                }
            }
        } catch {
            print("Failed to fetch food items: \(error)")
        }
    }
    
    private func loadFoodItemRows() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItemRow> = FoodItemRow.fetchRequest()
        do {
            foodItemRows = try context.fetch(fetchRequest)
            addTotalRegisteredCarbsRow() // Add this line to add the registered carbs row at the top
            addTotalCarbsRow()
            addSpacingView()
            addHeaderRow()
            for row in foodItemRows {
                if let foodItem = foodItems[row.foodItemID ?? UUID()] {
                    let netCarbs = calculateNetCarbs(for: foodItem, portionServed: row.portionServed, notEaten: row.notEaten)
                    let rowView = createNonEditableRowView(for: foodItem, portionServed: row.portionServed, notEaten: row.notEaten, netCarbs: netCarbs)
                    stackView.addArrangedSubview(rowView)
                }
            }
        } catch {
            print("Failed to fetch food item rows: \(error)")
        }
    }
    @objc private func didImportOngoingMeal(_ notification: Notification) {
        if let importedRows = notification.userInfo?["foodItemRows"] as? [FoodItemRow] {
            foodItemRows = importedRows
            reloadStackView()
        }
    }
    
    private func reloadStackView() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        addTotalRegisteredCarbsRow()
        addTotalCarbsRow()
        addSpacingView()
        addHeaderRow()
        for row in foodItemRows {
            if let foodItem = foodItems[row.foodItemID ?? UUID()] {
                let netCarbs = calculateNetCarbs(for: foodItem, portionServed: row.portionServed, notEaten: row.notEaten)
                let rowView = createNonEditableRowView(for: foodItem, portionServed: row.portionServed, notEaten: row.notEaten, netCarbs: netCarbs)
                stackView.addArrangedSubview(rowView)
            }
        }
    }
    
    private func calculateNetCarbs(for foodItem: FoodItem, portionServed: Double, notEaten: Double) -> Double {
        let carbohydrates = foodItem.carbohydrates
        let carbsPP = foodItem.carbsPP
        let netCarbs = ((carbohydrates / 100) + carbsPP) * (portionServed - notEaten)
        return netCarbs
    }
    
    private func createNonEditableRowView(for foodItem: FoodItem, portionServed: Double, notEaten: Double, netCarbs: Double) -> UIView {
        let rowView = UIStackView()
        rowView.axis = .horizontal
        rowView.spacing = 8
        rowView.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = foodItem.name
        nameLabel.textColor = .label
        nameLabel.textAlignment = .left
        nameLabel.widthAnchor.constraint(equalToConstant: 150).isActive = true
        
        let portionLabel = UILabel()
        portionLabel.text = String(format: "%.0f", portionServed)
        portionLabel.textColor = .label
        portionLabel.textAlignment = .right
        portionLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        let notEatenLabel = UILabel()
        notEatenLabel.text = String(format: "%.0f", notEaten)
        notEatenLabel.textColor = .label
        notEatenLabel.textAlignment = .right
        notEatenLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        let carbsLabel = UILabel()
        carbsLabel.text = String(format: "%.0f", netCarbs)
        carbsLabel.textColor = .label
        carbsLabel.textAlignment = .right
        carbsLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        rowView.addArrangedSubview(nameLabel)
        rowView.addArrangedSubview(portionLabel)
        rowView.addArrangedSubview(notEatenLabel)
        rowView.addArrangedSubview(carbsLabel)
        
        return rowView
    }
    
    private func addHeaderRow() {
        let rowView = UIStackView()
        rowView.axis = .horizontal
        rowView.spacing = 8
        rowView.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = "Livsmedel"
        nameLabel.textColor = .gray
        nameLabel.textAlignment = .left
        nameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        nameLabel.widthAnchor.constraint(equalToConstant: 150).isActive = true
        
        let portionLabel = UILabel()
        portionLabel.text = "Serv."
        portionLabel.textColor = .gray
        portionLabel.textAlignment = .right
        portionLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        portionLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        let notEatenLabel = UILabel()
        notEatenLabel.text = "Ej ätit"
        notEatenLabel.textColor = .gray
        notEatenLabel.textAlignment = .right
        notEatenLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        notEatenLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        let carbsLabel = UILabel()
        carbsLabel.text = "Kh"
        carbsLabel.textColor = .gray
        carbsLabel.textAlignment = .right
        carbsLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        carbsLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        rowView.addArrangedSubview(nameLabel)
        rowView.addArrangedSubview(portionLabel)
        rowView.addArrangedSubview(notEatenLabel)
        rowView.addArrangedSubview(carbsLabel)
        
        stackView.addArrangedSubview(rowView)
    }
    
    private func addTotalRegisteredCarbsRow() {
        guard let latestTotalRegisteredValue = foodItemRows.last?.totalRegisteredValue else { return }
        
        let rowView = UIStackView()
        rowView.axis = .horizontal
        rowView.spacing = 8
        rowView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Registrerade kolhydrater:"
        titleLabel.textColor = .label
        titleLabel.widthAnchor.constraint(equalToConstant: 250).isActive = true
        
        let totalCarbsLabel = UILabel()
        totalCarbsLabel.text = String(format: "%.0f", latestTotalRegisteredValue)
        totalCarbsLabel.textColor = .label
        totalCarbsLabel.textAlignment = .right
        totalCarbsLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        rowView.addArrangedSubview(titleLabel)
        rowView.addArrangedSubview(totalCarbsLabel)
        stackView.addArrangedSubview(rowView)
    }
    
    
    private func addTotalCarbsRow() {
        let totalCarbs = foodItemRows.reduce(0) { total, row in
            if let foodItem = foodItems[row.foodItemID ?? UUID()] {
                let netCarbs = calculateNetCarbs(for: foodItem, portionServed: row.portionServed, notEaten: row.notEaten)
                return total + netCarbs
            }
            return total
        }
        
        let rowView = UIStackView()
        rowView.axis = .horizontal
        rowView.spacing = 8
        rowView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Kolhydrater totalt:"
        titleLabel.textColor = .label
        titleLabel.widthAnchor.constraint(equalToConstant: 250).isActive = true
        
        let totalCarbsLabel = UILabel()
        totalCarbsLabel.text = String(format: "%.0f", totalCarbs)
        totalCarbsLabel.textColor = .label
        totalCarbsLabel.textAlignment = .right
        totalCarbsLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        rowView.addArrangedSubview(titleLabel)
        rowView.addArrangedSubview(totalCarbsLabel)
        
        stackView.addArrangedSubview(rowView)
    }
    
    private func addSpacingView() {
        let spacingView = UIView()
        spacingView.translatesAutoresizingMaskIntoConstraints = false
        spacingView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacingView)
    }
}
