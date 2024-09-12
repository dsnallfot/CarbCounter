import UIKit
import CoreData

struct FoodItemRowData {
    var foodItemID: UUID?
    var portionServed: Double
    var notEaten: Double
    var registeredCarbsSoFar: Double
    var registeredFatSoFar: Double
    var registeredProteinSoFar: Double
    var registeredBolusSoFar: Double
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
    
    let takeoverButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("Ta över registrering", comment: "Ta över registrering"), for: .normal)
        
        let systemFont = UIFont.systemFont(ofSize: 19, weight: .semibold)
        if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            button.titleLabel?.font = UIFont(descriptor: roundedDescriptor, size: 19)
        } else {
            button.titleLabel?.font = systemFont
        }
        
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(takeoverRegistration), for: .touchUpInside)
        button.isEnabled = false // Initially disabled
        button.addTarget(self, action: #selector(buttonStateDidChange), for: .valueChanged)
        return button
    }()
    
    let noDataLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("Ingen måltidregistrering pågår", comment: "Ingen måltidregistrering pågår")
        label.textColor = .gray
        label.textAlignment = .center
        label.font = UIFont.italicSystemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // Create the gradient view
        let colors: [CGColor] = [
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        ]
        let gradientView = GradientView(colors: colors)
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the gradient view to the main view
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)
        
        // Set up constraints for the gradient view
        NSLayoutConstraint.activate([
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
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
        updateButtonState()
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
    
    @objc private func buttonStateDidChange(_ sender: UIButton) {
        sender.backgroundColor = sender.isEnabled ? .systemBlue : .systemGray
    }

    // Call this function to update the button state
    private func updateButtonState() {
        takeoverButton.isEnabled = !foodItemRows.isEmpty
        takeoverButton.backgroundColor = takeoverButton.isEnabled ? .systemBlue : .systemGray
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
        navigationItem.title = NSLocalizedString("Pågående måltid", comment: "Pågående måltid")
        
        setupTakeoverButton()
    }
    
    private func setupTakeoverButton() {
        view.addSubview(takeoverButton)
        
        NSLayoutConstraint.activate([
            takeoverButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            takeoverButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            takeoverButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            takeoverButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        takeoverButton.isEnabled = false // Initially disable the button
    }
    
    @objc private func takeoverRegistration() {
        // Prepare the data to pass
        let foodItemRowData = foodItemRows.map { row in
            FoodItemRowData(
                foodItemID: row.foodItemID,
                portionServed: row.portionServed,
                notEaten: row.notEaten,
                registeredCarbsSoFar: row.registeredCarbsSoFar,
                registeredFatSoFar: row.registeredFatSoFar,
                registeredProteinSoFar: row.registeredProteinSoFar,
                registeredBolusSoFar: row.registeredBolusSoFar
            )
        }
        
        // Post a notification with the food item data
        NotificationCenter.default.post(name: .didTakeoverRegistration, object: nil, userInfo: ["foodItemRows": foodItemRowData])
        
        // Dismiss the view controller
        dismiss(animated: true, completion: nil)
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
            //print("Received imported rows: \(importedRows)") // Log the received data
            foodItemRows = importedRows
            reloadStackView()
            updateUIBasedOnData()
        } else {
            print("Failed to receive imported rows")
        }
    }
    
    private func reloadStackView() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if foodItemRows.isEmpty {
            stackView.addArrangedSubview(noDataLabel)
        } else {
            addCarbsRow()
            addBolusRow()
            addSpacingView()
            addHeaderRow()
            for row in foodItemRows {
                if let foodItem = foodItems[row.foodItemID ?? UUID()] {
                    let netCarbs = calculateNetCarbs(for: foodItem, portionServed: row.portionServed, notEaten: row.notEaten)
                    let rowView = createNonEditableRowView(for: foodItem, portionServed: row.portionServed, notEaten: row.notEaten, netCarbs: netCarbs)
                    stackView.addArrangedSubview(rowView)
                } else {
                    print("Food item not found for ID: \(String(describing: row.foodItemID))")
                }
            }
        }
        updateButtonState()
    }
    
    private func updateUIBasedOnData() {
        let hasData = !foodItemRows.isEmpty
        takeoverButton.isEnabled = hasData
        noDataLabel.isHidden = hasData
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
        nameLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action:#selector(foodItemLabelTapped(_:))))
        nameLabel.tag = foodItem.hashValue // Use the foodItem’s hashValue to identify the label
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
                message += NSLocalizedString("\nKolhydrater: \(carbsPP) g / st ", comment: "\nKolhydrater: \(carbsPP) g / st ")
            }
            if fatPP > 0 {
                message += NSLocalizedString("\nFett: \(fatPP) g / st ", comment: "\nFett: \(fatPP) g / st ")
            }
            if proteinPP > 0 {
                message += NSLocalizedString("\nProtein: \(proteinPP) g / st ", comment: "\nProtein: \(proteinPP) g / st ")
            }
        } else {
            let carbohydrates = selectedFoodItem.carbohydrates
            let fat = selectedFoodItem.fat
            let protein = selectedFoodItem.protein
            if carbohydrates > 0 {
                message += NSLocalizedString("\nKolhydrater: \(carbohydrates) g / 100 g ", comment: "\nKolhydrater: \(carbohydrates) g / 100 g ")
            }
            if fat > 0 {
                message += NSLocalizedString("\nFett: \(fat) g / 100 g ", comment: "\nFett: \(fat) g / 100 g ")
            }
            if protein > 0 {
                message += NSLocalizedString("\nProtein: \(protein) g / 100 g ", comment: "\nProtein: \(protein) g / 100 g ")
            }
        }
        if message.isEmpty {
            message = NSLocalizedString("Ingen näringsinformation tillgänglig.", comment: "Ingen näringsinformation tillgänglig.")
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
        nameLabel.text = NSLocalizedString("LIVSMEDEL", comment: "LIVSMEDEL")
        nameLabel.textColor = .gray
        nameLabel.textAlignment = .left
        nameLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let portionLabel = UILabel()
        portionLabel.text = NSLocalizedString("PORTION", comment: "PORTION")
        portionLabel.textColor = .gray
        portionLabel.textAlignment = .right
        portionLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        portionLabel.widthAnchor.constraint(equalToConstant: 55).isActive = true
        portionLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        let notEatenLabel = UILabel()
        notEatenLabel.text = NSLocalizedString("LÄMNAT", comment: "LÄMNAT")
        notEatenLabel.textColor = .gray
        notEatenLabel.textAlignment = .right
        notEatenLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        notEatenLabel.widthAnchor.constraint(equalToConstant: 55).isActive = true
        notEatenLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        let carbsLabel = UILabel()
        carbsLabel.text = NSLocalizedString("KH", comment: "KH")
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
    
    private func addCarbsRow() {
        guard let latestregisteredCarbsSoFar = foodItemRows.last?.registeredCarbsSoFar else { return }
        let totalCarbs = foodItemRows.reduce(0) { total, row in
            let netCarbs = calculateNetCarbs(for: row.foodItemID, portionServed: row.portionServed, notEaten: row.notEaten)
            return total + netCarbs
        }
        
        let rowView = UIStackView()
        rowView.axis = .horizontal
        rowView.spacing = 8
        rowView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("Reg KH", comment: "Reg KH")
        titleLabel.textColor = .systemOrange
        titleLabel.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .semibold)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let detailLabel = UILabel()
        let localizedCarbsDetailFormat = NSLocalizedString("(av totalt %.0f g i måltiden)", comment: "Detail label text showing the total carbs in the meal")
        detailLabel.text = String(format: localizedCarbsDetailFormat, totalCarbs)
        detailLabel.textColor = .gray
        detailLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        detailLabel.textAlignment = .left
        detailLabel.widthAnchor.constraint(equalToConstant: 185).isActive = true
        
        let regCarbsLabel = UILabel()
        let localizedCarbsText = NSLocalizedString("%.0f g", comment: "Registered carbs label text")
        regCarbsLabel.text = String(format: localizedCarbsText, latestregisteredCarbsSoFar)
        regCarbsLabel.textColor = .systemOrange
        regCarbsLabel.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .semibold)
        regCarbsLabel.textAlignment = .right
        regCarbsLabel.widthAnchor.constraint(equalToConstant: 55).isActive = true
        
        rowView.addArrangedSubview(titleLabel)
        rowView.addArrangedSubview(detailLabel)
        rowView.addArrangedSubview(regCarbsLabel)
        stackView.addArrangedSubview(rowView)
    }
    
    private func roundToNearest(_ value: Double, increment: Double) -> Double {
        return (value / increment).rounded() * increment
    }
    
    private func addBolusRow() {
        guard let latestRegisteredBolusSoFar = foodItemRows.last?.registeredBolusSoFar else { return }
        
        // Calculate total carbs
        let totalCarbs = foodItemRows.reduce(0) { total, row in
            let netCarbs = calculateNetCarbs(for: row.foodItemID, portionServed: row.portionServed, notEaten: row.notEaten)
            return total + netCarbs
        }
        
        // Retrieve scheduled carb ratio from UserDefaults
        let scheduledCarbRatio = UserDefaultsRepository.scheduledCarbRatio
        
        // Calculate total bolus (total carbs / scheduled carb ratio)
        var totalBolus = totalCarbs / scheduledCarbRatio
        
        // Round totalBolus to nearest 0.05 increment
        totalBolus = roundToNearest(totalBolus, increment: 0.05)
        
        let rowView = UIStackView()
        rowView.axis = .horizontal
        rowView.spacing = 8
        rowView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("Reg Bolus", comment: "Reg Bolus")
        titleLabel.textColor = .systemBlue
        titleLabel.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .semibold)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let detailLabel = UILabel()
        let localizedBolusDetailFormat = NSLocalizedString("(av totalt behov %.2f E)", comment: "Detail label text showing the total bolus needed")
        detailLabel.text = String(format: localizedBolusDetailFormat, totalBolus)
        detailLabel.textColor = .gray
        detailLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        detailLabel.textAlignment = .left
        detailLabel.widthAnchor.constraint(equalToConstant: 185).isActive = true
        
        let regBolusLabel = UILabel()
        let localizedBolusText = NSLocalizedString("%.2f E", comment: "Registered bolus label text")
        regBolusLabel.text = String(format: localizedBolusText, latestRegisteredBolusSoFar)
        regBolusLabel.textColor = .systemBlue
        regBolusLabel.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .semibold)
        regBolusLabel.textAlignment = .right
        regBolusLabel.widthAnchor.constraint(equalToConstant: 55).isActive = true
        
        rowView.addArrangedSubview(titleLabel)
        rowView.addArrangedSubview(detailLabel)
        rowView.addArrangedSubview(regBolusLabel)
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

// Add a notification name extension
extension Notification.Name {
    static let didTakeoverRegistration = Notification.Name("didTakeoverRegistration")
}
