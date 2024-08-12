import UIKit
import CoreData

class SearchableDropdownViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, AddFoodItemDelegate {
    
    var onSelectItems: (([FoodItem]) -> Void)?
    var onDoneButtonTapped: (([FoodItem]) -> Void)?
    var foodItems: [FoodItem] = []
    var filteredFoodItems: [FoodItem] = []
    var selectedFoodItems: [FoodItem] = []
    private var tableViewBottomConstraint: NSLayoutConstraint!
    
    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Sök & välj ett eller flera livsmedel"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.backgroundImage = UIImage() // Removes the default background image
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.tintColor = .label
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            if #available(iOS 11.0, *) {
                textField.inputAssistantItem.leadingBarButtonGroups = []
                textField.inputAssistantItem.trailingBarButtonGroups = []
            }
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            let symbolImage = UIImage(systemName: "keyboard.chevron.compact.down")
            let cancelButton = UIButton(type: .system)
            cancelButton.setImage(symbolImage, for: .normal)
            cancelButton.tintColor = .label
            cancelButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
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
        tableView.backgroundColor = .clear
        return tableView
    }()
    
    let segmentedControl: UISegmentedControl = {
        let items = ["Namn A-Ö", "Skolmat", "Styck", "Populära"]
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.tintColor = .label
        return segmentedControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupNavigationBar()
        fetchFoodItems()
        
        // Add observer for notifications
        NotificationCenter.default.addObserver(self, selector: #selector(foodItemsDidChange(_:)), name: .foodItemsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        // Load saved search text
                if let savedSearchText = UserDefaultsRepository.dropdownSearchText {
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
    
    private func setupNavigationBar() {
        title = "Välj livsmedel"
        
        // Create the close button
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
        
        // Create the info.circle button (existing addFoodItemButton)
        let addFoodItemButton = UIBarButtonItem(image: UIImage(systemName: "plus.circle"), style: .plain, target: self, action: #selector(addNewButtonTapped))
        
        // Create the show meal button for the right side of the navigation bar
        let showMealButton = UIBarButtonItem(title: "Klar", style: .plain, target: self, action: #selector(doneButtonTapped))
        
        // Set both buttons on the left side of the navigation bar
        navigationItem.rightBarButtonItems = [showMealButton, addFoodItemButton]
        

    }
    
    private func setupView() {
        view.backgroundColor = .systemBackground
        let colors: [CGColor] = [
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        ]
        let gradientView = GradientView(colors: colors)
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)
        NSLayoutConstraint.activate([
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        view.addSubview(searchBar)
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
        searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            searchBar.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        tableViewBottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        tableViewBottomConstraint.isActive = true
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let keyboardHeight = keyboardFrame.height
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        
        UIView.animate(withDuration: duration) {
            self.tableViewBottomConstraint.constant = -keyboardHeight
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        
        UIView.animate(withDuration: duration) {
            self.tableViewBottomConstraint.constant = 0
            self.view.layoutIfNeeded()
        }
    }
    
    private func fetchFoodItems() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        
        do {
            foodItems = try context.fetch(fetchRequest)
            filteredFoodItems = foodItems
            sortFoodItems()
            tableView.reloadData()
        } catch {
            print("Failed to fetch food items: \(error)")
        }
    }
    
    @objc private func doneButtonTapped() {
        searchBar.text = ""
        UserDefaultsRepository.dropdownSearchText = nil
        filteredFoodItems = foodItems
        sortFoodItems()
        tableView.reloadData()
        completeSelection()
    }
    
    @objc private func cancelButtonTapped() {
        UserDefaultsRepository.dropdownSearchText = nil
        searchBar.resignFirstResponder()
    }
    
    @objc private func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        sortFoodItems()
        tableView.reloadData()
    }
    
    private func sortFoodItems() {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            filteredFoodItems.sort { $0.name ?? "" < $1.name ?? "" }
        case 1:
            filteredFoodItems.sort { ($0.name?.hasPrefix("Ⓢ") ?? false) && !($1.name?.hasPrefix("Ⓢ") ?? false) }
        case 2:
            filteredFoodItems.sort { ($0.name?.hasSuffix("①") ?? false) && !($1.name?.hasSuffix("①") ?? false) }
        case 3:
            filteredFoodItems.sort { $0.count > $1.count }
        default:
            break
        }
    }
    
    @objc private func foodItemsDidChange(_ notification: Notification) {
        if let updatedItems = notification.userInfo?["foodItems"] as? [FoodItem] {
            updateFoodItems(updatedItems)
        }
    }
    
    func updateFoodItems(_ items: [FoodItem]) {
        foodItems = items
        filteredFoodItems = foodItems
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
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
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
        UserDefaultsRepository.dropdownSearchText = searchText
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
    
    func completeSelection() {
        let context = CoreDataStack.shared.context
        for item in selectedFoodItems {
            item.count += 1
        }
        do {
            try context.save()
        } catch {
            print("Failed to update food item count: \(error)")
        }
        searchBar.resignFirstResponder()
        onDoneButtonTapped?(selectedFoodItems)
        clearSelection()
        tableView.reloadData()
        dismiss(animated: true, completion: nil)
    }

    private func clearSelection() {
        selectedFoodItems.removeAll()
    }
    
    @objc private func addNewButtonTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            let navigationController = UINavigationController(rootViewController: addFoodItemVC)
            present(navigationController, animated: true, completion: nil)
        }
    }
    func didAddFoodItem() {
            fetchFoodItems()
        }
}

extension Notification.Name {
static let foodItemsDidChange = Notification.Name("foodItemsDidChange")
}


