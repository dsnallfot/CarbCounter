import UIKit

class SearchableDropdownView: UIView, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    var onSelectItems: (([FoodItem]) -> Void)?
    var onDoneButtonTapped: (([FoodItem]) -> Void)?
    var foodItems: [FoodItem] = []
    var filteredFoodItems: [FoodItem] = []
    var selectedFoodItems: [FoodItem] = []

    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search and Select Food Items"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.barTintColor = .systemGray
        searchBar.backgroundImage = UIImage() // Removes the default background image

        // Customize the text field inside the search bar
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.backgroundColor = .systemGray4
            textField.tintColor = .label // Set the cursor color
            textField.autocorrectionType = .no // Disable autocorrection
            textField.spellCheckingType = .no // Disable spell checking

            // Remove predictive text
            if #available(iOS 11.0, *) {
                textField.inputAssistantItem.leadingBarButtonGroups = []
                textField.inputAssistantItem.trailingBarButtonGroups = []
            }

            // Create toolbar with done button
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            toolbar.setItems([flexSpace, doneButton], animated: false)
            
            textField.inputAccessoryView = toolbar
        }
        
        return searchBar
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    let segmentedControl: UISegmentedControl = {
        let items = ["Name A-Z", "Most Popular"]
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.backgroundColor = .systemBackground // Set background color
        segmentedControl.tintColor = .systemBlue // Set tint color
        return segmentedControl
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        // Add observer for notifications
        NotificationCenter.default.addObserver(self, selector: #selector(foodItemsDidChange(_:)), name: .foodItemsDidChange, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        addSubview(segmentedControl)
        addSubview(searchBar)
        addSubview(tableView)

        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
        searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: trailingAnchor),

            segmentedControl.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor),

            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        searchBar.becomeFirstResponder()
    }

    @objc private func doneButtonTapped() {
        // Increment count for each selected item and save context
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        
        for item in selectedFoodItems {
            item.count += 1
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to update food item count: \(error)")
        }
        
        onDoneButtonTapped?(selectedFoodItems)
        clearSelection()
        clearSearch()
    }

    @objc private func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        sortFoodItems()
        tableView.reloadData()
    }

    private func sortFoodItems() {
        if segmentedControl.selectedSegmentIndex == 0 {
            filteredFoodItems.sort { ($0.name ?? "") < ($1.name ?? "") }
        } else {
            filteredFoodItems.sort { $0.count > $1.count }
        }
    }

    private func clearSelection() {
        selectedFoodItems.removeAll()
    }

    private func clearSearch() {
        searchBar.text = ""
        filteredFoodItems = foodItems
        sortFoodItems()
        tableView.reloadData()
    }

    @objc private func foodItemsDidChange(_ notification: Notification) {
        if let updatedItems = notification.userInfo?["foodItems"] as? [FoodItem] {
            updateFoodItems(updatedItems)
        }
    }

    func updateFoodItems(_ items: [FoodItem]) {
        self.foodItems = items
        self.filteredFoodItems = self.foodItems
        sortFoodItems()
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredFoodItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        let foodItem = filteredFoodItems[indexPath.row]
        cell.textLabel?.text = foodItem.name
        cell.accessoryType = selectedFoodItems.contains(foodItem) ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let foodItem = filteredFoodItems[indexPath.row]
        if let index = selectedFoodItems.firstIndex(of: foodItem) {
            selectedFoodItems.remove(at: index)
        } else {
            selectedFoodItems.append(foodItem)
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredFoodItems = foodItems
        } else {
            filteredFoodItems = foodItems.filter { $0.name?.lowercased().contains(searchText.lowercased()) ?? false }
        }
        sortFoodItems()
        tableView.reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension Notification.Name {
    static let foodItemsDidChange = Notification.Name("foodItemsDidChange")
}
