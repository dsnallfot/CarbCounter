import UIKit
import CoreData

struct FoodItemRowData {
    var foodItemID: UUID?
    var portionServed: Double
    var notEaten: Double
    var totalRegisteredValue: Double
}

class OngoingMealViewController: UIViewController {
    
    var foodItemRows: [FoodItemRowData] = []
    var foodItems: [UUID: FoodItem] = [:] // Dictionary to store FoodItems by their ID
    private var importTimer: Timer?
    private var originalAllowSharingOngoingMeals: Bool?
    
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
        loadFoodItems() // Load food items once for mapping purposes
        
        // Observe for imported ongoing meal data
        NotificationCenter.default.addObserver(self, selector: #selector(didImportOngoingMeal(_:)), name: .didImportOngoingMeal, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Save the original state and set it to false
        originalAllowSharingOngoingMeals = UserDefaultsRepository.allowSharingOngoingMeals
        if UserDefaultsRepository.allowSharingOngoingMeals {
            UserDefaultsRepository.allowSharingOngoingMeals = false
        }
        startImportTimer()
        importOngoingMealCSV()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore the original state
        if let originalState = originalAllowSharingOngoingMeals {
            UserDefaultsRepository.allowSharingOngoingMeals = originalState
        }
        stopImportTimer()
    }
    
    private func startImportTimer() {
        stopImportTimer() // Stop any existing timer
        importTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(importOngoingMealCSV), userInfo: nil, repeats: true)
    }
    
    private func stopImportTimer() {
        importTimer?.invalidate()
        importTimer = nil
    }
    
    @objc private func importOngoingMealCSV() {
        // Automatically import ongoing meal CSV
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
    
    @objc private func didImportOngoingMeal(_ notification: Notification) {
        if let importedRows = notification.userInfo?["foodItemRows"] as? [FoodItemRowData] {
            // Clear existing rows and add imported rows
            foodItemRows = importedRows
            reloadStackView()
        }
    }
    
    private func reloadStackView() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        addTotalCarbsRow()
        addTotalRegisteredCarbsRow()
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
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.isUserInteractionEnabled = true
        nameLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(foodItemLabelTapped(_:))))
        nameLabel.tag = foodItem.hashValue // Use the foodItem's hashValue to identify the label
        
        let portionLabel = UILabel()
        portionLabel.text = String(format: "%.0f", portionServed)
        portionLabel.textColor = .label
        portionLabel.textAlignment = .right
        portionLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        portionLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        let notEatenLabel = UILabel()
        notEatenLabel.text = String(format: "%.0f", notEaten)
        notEatenLabel.textColor = .label
        notEatenLabel.textAlignment = .right
        notEatenLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        notEatenLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        let carbsLabel = UILabel()
        carbsLabel.text = String(format: "%.0f", netCarbs) + " g"
        carbsLabel.textColor = .label
        carbsLabel.textAlignment = .right
        carbsLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        carbsLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        rowView.addArrangedSubview(nameLabel)
        rowView.addArrangedSubview(portionLabel)
        rowView.addArrangedSubview(notEatenLabel)
        rowView.addArrangedSubview(carbsLabel)
        
        return rowView
    }
    
    @objc private func foodItemLabelTapped(_ sender: UITapGestureRecognizer) {
        guard let label = sender.view as? UILabel,
              let selectedFoodItem = foodItems.values.first(where: { $0.hashValue == label.tag }) else { return }
        
        let title = "\(selectedFoodItem.emoji ?? "") \(selectedFoodItem.name ?? "")"
        var message = ""
        
        if let notes = selectedFoodItem.notes, !notes.isEmpty {
            message += "\nNot: \(notes)\n"
        }
        
        if selectedFoodItem.perPiece {
            let carbsPP = selectedFoodItem.carbsPP
            let fatPP = selectedFoodItem.fatPP
            let proteinPP = selectedFoodItem.proteinPP
            
            if carbsPP > 0 {
                message += "\nKolhydrater: \(carbsPP) g / st "
            }
            if fatPP > 0 {
                message += "\nFett: \(fatPP) g / st "
            }
            if proteinPP > 0 {
                message += "\nProtein: \(proteinPP) g / st "
            }
        }
        else {
            let carbohydrates = selectedFoodItem.carbohydrates
            let fat = selectedFoodItem.fat
            let protein = selectedFoodItem.protein
            if carbohydrates > 0 {
                message += "\nKolhydrater: \(carbohydrates) g / 100 g "
            }
            if fat > 0 {
                message += "\nFett: \(fat) g / 100 g "
            }
            if protein > 0 {
                message += "\nProtein: (protein) g / 100 g "
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
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func addHeaderRow() {
        let rowView = UIStackView()
        rowView.axis = .horizontal
        rowView.spacing = 8
        rowView.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = "LIVSMEDEL"
        nameLabel.textColor = .gray
        nameLabel.textAlignment = .left
        nameLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let portionLabel = UILabel()
        portionLabel.text = "PORTION"
        portionLabel.textColor = .gray
        portionLabel.textAlignment = .right
        portionLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        portionLabel.widthAnchor.constraint(equalToConstant: 55).isActive = true
        portionLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        let notEatenLabel = UILabel()
        notEatenLabel.text = "LÄMNAT"
        notEatenLabel.textColor = .gray
        notEatenLabel.textAlignment = .right
        notEatenLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        notEatenLabel.widthAnchor.constraint(equalToConstant: 55).isActive = true
        notEatenLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        let carbsLabel = UILabel()
        carbsLabel.text = "KH"
        carbsLabel.textColor = .gray
        carbsLabel.textAlignment = .right
        carbsLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        carbsLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true
        carbsLabel.setContentHuggingPriority(.required, for: .horizontal)
        
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
        titleLabel.text = "REGISTRERADE KOLHYDRATER:"
        titleLabel.textColor = .label
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let totalCarbsLabel = UILabel()
        totalCarbsLabel.text = String(format: "%.0f", latestTotalRegisteredValue) + " g"
        totalCarbsLabel.textColor = .label
        totalCarbsLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        totalCarbsLabel.textAlignment = .right
        totalCarbsLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        rowView.addArrangedSubview(titleLabel)
        rowView.addArrangedSubview(totalCarbsLabel)
        stackView.addArrangedSubview(rowView)
    }
    
    private func addTotalCarbsRow() {
        let totalCarbs = foodItemRows.reduce(0) { total, row in
            let netCarbs = calculateNetCarbs(for: row.foodItemID, portionServed: row.portionServed, notEaten: row.notEaten)
            return total + netCarbs
        }
        
        let rowView = UIStackView()
        rowView.axis = .horizontal
        rowView.spacing = 8
        rowView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "TOT KOLHYDRATER I MÅLTIDEN:"
        titleLabel.textColor = .systemOrange
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let totalCarbsLabel = UILabel()
        totalCarbsLabel.text = String(format: "%.0f", totalCarbs) + " g"
        totalCarbsLabel.textColor = .systemOrange
        totalCarbsLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        totalCarbsLabel.textAlignment = .right
        totalCarbsLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        rowView.addArrangedSubview(titleLabel)
        rowView.addArrangedSubview(totalCarbsLabel)
        stackView.addArrangedSubview(rowView)
    }
    
    private func calculateNetCarbs(for foodItemID: UUID?, portionServed: Double, notEaten: Double) -> Double {
        guard let foodItemID = foodItemID, let foodItem = foodItems[foodItemID] else {
            return 0.0
        }
        let carbohydrates = foodItem.carbohydrates
        let carbsPP = foodItem.carbsPP
        let netCarbs = ((carbohydrates / 100) + carbsPP) * (portionServed - notEaten)
        return netCarbs
    }
    
    private func addSpacingView() {
        let spacingView = UIView()
        spacingView.translatesAutoresizingMaskIntoConstraints = false
        spacingView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacingView)
    }
}

extension OngoingMealViewController {
    func loadFoodItemRowsFromCSV() -> [FoodItemRow] {
        // Implement the method to load food item rows from the CSV
        // For example:
        var foodItemRows = [FoodItemRow]()
        
        // Load the CSV data (this is an example, adapt it to your actual loading logic)
        // let rows = ... (Load the CSV rows as strings)
        // foodItemRows = parseOngoingMealCSV(rows)
        
        return foodItemRows
    }
}
