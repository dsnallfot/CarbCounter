import UIKit

class SearchableDropdownView: UIView, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    var onSelectItems: (([FoodItem]) -> Void)?
    var onDoneButtonTapped: (([FoodItem]) -> Void)?
    var foodItems: [FoodItem] = []
    var filteredFoodItems: [FoodItem] = []
    var selectedFoodItems: [FoodItem] = [] {
            didSet {
                updateCombinedEmojis()
            }
        }
    var combinedEmojis: String = "🍽️"

    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Sök & välj ett eller flera livsmedel"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.barTintColor = .systemGray6//.systemGray
        searchBar.backgroundImage = UIImage() // Removes the default background image

        // Customize the text field inside the search bar
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.backgroundColor = .systemGray6
            textField.tintColor = .label // Set the cursor color
            textField.autocorrectionType = .no // Disable autocorrection
            textField.spellCheckingType = .no // Disable spell checking

            // Remove predictive text
            if #available(iOS 11.0, *) {
                textField.inputAssistantItem.leadingBarButtonGroups = []
                textField.inputAssistantItem.trailingBarButtonGroups = []
            }

            // Create toolbar with done and cancel buttons
            let toolbar = UIToolbar()
                toolbar.sizeToFit()
                
                // Create a UIButton with an SF symbol
                let symbolImage = UIImage(systemName: "keyboard.chevron.compact.down")
                let cancelButton = UIButton(type: .system)
                cancelButton.setImage(symbolImage, for: .normal)
                cancelButton.tintColor = .systemBlue // Change color if needed
                cancelButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24) // Adjust size if needed
                cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
                let cancelBarButtonItem = UIBarButtonItem(customView: cancelButton)
                
                let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                let doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
                
                toolbar.setItems([cancelBarButtonItem, flexSpace, doneButton], animated: false)
                
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
        let items = ["Namn A-Ö", "Skolmat", "Styck", "Populära"]
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
        
        // Load saved search text
        if let savedSearchText = UserDefaults.standard.string(forKey: "dropdownSearchText") {
            searchBar.text = savedSearchText
            filteredFoodItems = foodItems.filter { $0.name?.lowercased().contains(savedSearchText.lowercased()) ?? false }
            sortFoodItems()
            tableView.reloadData()
        } else {
            filteredFoodItems = foodItems
            sortFoodItems()
            tableView.reloadData()
        }
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

    @objc private func doneButtonTapped() {
        completeSelection()
    }

    @objc private func cancelButtonTapped() {
        // Clear saved search text
        UserDefaults.standard.removeObject(forKey: "dropdownSearchText")
        // Dismiss the keyboard
        searchBar.resignFirstResponder()
    }

    @objc private func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        sortFoodItems()
        tableView.reloadData()
    }

    private func sortFoodItems() {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            // Case 0: Sort by name (A-Z) with items without "Ⓢ" prefix first
            filteredFoodItems.sort { (item1, item2) in
                let name1 = item1.name ?? ""
                let name2 = item2.name ?? ""

                let hasPrefix1 = name1.hasPrefix("Ⓢ")
                let hasPrefix2 = name2.hasPrefix("Ⓢ")

                if hasPrefix1 != hasPrefix2 {
                    return !hasPrefix1 && hasPrefix2
                }
                return name1 < name2
            }
        case 1:
            // Case 1: Sort items with "Ⓢ" prefix on top, then by name
            filteredFoodItems.sort { (item1, item2) in
                let name1 = item1.name ?? ""
                let name2 = item2.name ?? ""

                let hasPrefix1 = name1.hasPrefix("Ⓢ")
                let hasPrefix2 = name2.hasPrefix("Ⓢ")

                if hasPrefix1 != hasPrefix2 {
                    return hasPrefix1 && !hasPrefix2
                }
                return name1 < name2
            }
        case 2:
            // Case 2: Sort by suffix "①" on top, then by name
            filteredFoodItems.sort { (item1, item2) in
                let name1 = item1.name ?? ""
                let name2 = item2.name ?? ""

                let hasSuffix1 = name1.hasSuffix("①")
                let hasSuffix2 = name2.hasSuffix("①")

                if hasSuffix1 != hasSuffix2 {
                    return hasSuffix1 && !hasSuffix2
                }
                return name1 < name2
            }
        case 3:
            // Case 3: Sort by count descending
            filteredFoodItems.sort { $0.count > $1.count }
        default:
            break
        }
    }
    private func clearSelection() {
        selectedFoodItems.removeAll()
    }

    /*private func clearSearch() {
        searchBar.text = ""
        filteredFoodItems = foodItems
        sortFoodItems()
        tableView.reloadData()
    }*/

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
        UserDefaults.standard.set(searchText, forKey: "dropdownSearchText") // Save search text
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

extension SearchableDropdownView {
    func completeSelection() {
        // Increment count for each selected item and save context
        let context = CoreDataStack.shared.context
        
        for item in selectedFoodItems {
            item.count += 1
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to update food item count: \(error)")
        }
        
        // Save combined emojis before clearing selection
        let emojis = removeDuplicateEmojis(from: combinedEmojis)
        print("saved emojis: \(emojis)")
        
        // Resign the searchBar as first responder
        searchBar.resignFirstResponder()
        
        onDoneButtonTapped?(selectedFoodItems)
        clearSelection()
        tableView.reloadData()
        
        // Hide the dropdown view
        self.isHidden = true
        
        // Notify delegate to update navigation bar
        (self.superview?.next as? ComposeMealViewController)?.hideSearchableDropdown()
        
        // Set combined emojis back to the previously saved value
        combinedEmojis = emojis
    }
    
    func updateCombinedEmojis() {
        // Extract emojis from selected food items
        let emojis = selectedFoodItems.compactMap { $0.emoji }
        
        if emojis.isEmpty {
            combinedEmojis = "🍽️" // Default emoji if no emojis are available
        } else {
            combinedEmojis = emojis.joined()
        }
        
        // Notify if needed
        onSelectItems?(selectedFoodItems)
        print("combinedEmojis cleared and reset: \(combinedEmojis)")
    }

    func getCombinedEmojis() -> String {
        return combinedEmojis
    }

    // Helper function to remove duplicate emojis
    private func removeDuplicateEmojis(from string: String) -> String {
        var uniqueEmojis = Set<Character>()
        let filteredEmojis = string.filter { uniqueEmojis.insert($0).inserted }
        return String(filteredEmojis)
    }
}
