import UIKit
import CoreData

class OngoingMealViewController: UIViewController {
    
    var foodItemRows: [FoodItemRow] = []
    var foodItems: [UUID: FoodItem] = [:] // Dictionary to store FoodItems by their ID
    
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
        //startAutoSaveToCSV()
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
    
    private func startAutoSaveToCSV() {
        Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(saveToCSV), userInfo: nil, repeats: true)
    }
    
    @objc private func saveToCSV() {
        var csvText = "Name,Portion Served,Not Eaten,Net Carbs\n"
        for row in foodItemRows {
            if let foodItem = foodItems[row.foodItemID ?? UUID()] {
                let netCarbs = calculateNetCarbs(for: foodItem, portionServed: row.portionServed, notEaten: row.notEaten)
                let newRow = "\(foodItem.name ?? ""),\(row.portionServed),\(row.notEaten),\(netCarbs)\n"
                csvText.append(newRow)
            }
        }
        csvText.append("Registrerade kolhydrater,\(foodItemRows.reduce(0) { $0 + $1.totalRegisteredValue })\n")
        
        let fileName = "OngoingMeal.csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            print("CSV file saved at \(path)")
            uploadFileToICloud(fileURL: path)
        } catch {
            print("Failed to save CSV: \(error)")
        }
    }
    
    private func uploadFileToICloud(fileURL: URL) {
        let iCloudDirectory = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
        let destinationURL = iCloudDirectory?.appendingPathComponent(fileURL.lastPathComponent)
        
        do {
            try FileManager.default.setUbiquitous(true, itemAt: fileURL, destinationURL: destinationURL!)
            print("File uploaded to iCloud: \(destinationURL!)")
        } catch {
            print("Failed to upload file to iCloud: \(error)")
        }
    }
}
