import UIKit
import CoreData

class SearchableDropdownViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, AddFoodItemDelegate {
    
    var onSelectItems: (([FoodItem]) -> Void)?
    var onDoneButtonTapped: (([FoodItem]) -> Void)?
    var foodItems: [FoodItem] = []
    var filteredFoodItems: [FoodItem] = []
    var selectedFoodItems: [FoodItem] = []
    private var tableViewBottomConstraint: NSLayoutConstraint!
    
    var dataSharingVC: DataSharingViewController?
    
    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = NSLocalizedString("Sök & välj ett eller flera livsmedel", comment: "Sök & välj ett eller flera livsmedel")
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
            let doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Klar"), style: .done, target: self, action: #selector(doneButtonTapped))
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
        let items = [NSLocalizedString("Namn A-Ö", comment: "Namn A-Ö"), NSLocalizedString("Skolmat", comment: "Skolmat"), NSLocalizedString("Styck", comment: "Styck")]
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
                filterFoodItems(with: savedSearchText)
            } else {
                filterFoodItems(with: "")
            }
        // Instantiate DataSharingViewController programmatically
        dataSharingVC = DataSharingViewController()
        
        addRefreshControl()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Restore the saved search text
            if let savedSearchText = UserDefaultsRepository.dropdownSearchText {
                searchBar.text = savedSearchText
                filterFoodItems(with: savedSearchText)
            } else {
                filterFoodItems(with: "")
            }
        
        sortFoodItems()
        tableView.reloadData()
    }
    
    private func setupNavigationBar() {
        title = NSLocalizedString("Välj livsmedel", comment: "Välj livsmedel")
        
        // Create the close button
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
        
        // Create the info.circle button (existing addFoodItemButton)
        let addFoodItemButton = UIBarButtonItem(image: UIImage(systemName: "plus.circle"), style: .plain, target: self, action: #selector(addNewButtonTapped))
        
        // Create the show meal button for the right side of the navigation bar
        let showMealButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Klar"), style: .plain, target: self, action: #selector(doneButtonTapped))
        
        // Set both buttons on the left side of the navigation bar
        navigationItem.rightBarButtonItems = [showMealButton, addFoodItemButton]
        

    }
    
    private func setupView() {
        view.backgroundColor = .systemBackground
        // Check if the app is in dark mode
        if traitCollection.userInterfaceStyle == .dark {
            // Create the gradient view for dark mode
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
        } else {
            // In light mode, set a solid white background
            view.backgroundColor = .systemGray6
        }
        
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
    
    private func addRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: NSLocalizedString("Uppdaterar livsmedelslistan...", comment: "Message shown while updating food items"))
        refreshControl.addTarget(self, action: #selector(refreshFoodItems), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    @objc private func refreshFoodItems() {
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else {
            tableView.refreshControl?.endRefreshing()
            return
        }
        
        // Call the desired function
        print("Data import triggered")
        Task {
            await dataSharingVC.importCSVFiles(specificFileName: "FoodItems.csv")
            
            // End refreshing after completion
            await MainActor.run {
                tableView.refreshControl?.endRefreshing()
                fetchFoodItems()
            }
        }
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
        
        // Add a predicate to filter out items where the delete flag is true
        fetchRequest.predicate = NSPredicate(format: "delete == NO OR delete == nil")
        
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
        // Clear the search and reset UserDefaults
        searchBar.text = ""
        UserDefaultsRepository.dropdownSearchText = nil
        
        // Reset the filtered items to show all food items
        filteredFoodItems = foodItems
        sortFoodItems()
        tableView.reloadData()

        // Save context and resign the search bar
        let context = CoreDataStack.shared.context
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
        
        searchBar.resignFirstResponder()
        onDoneButtonTapped?(selectedFoodItems)
        clearSelection()
        dismiss(animated: true, completion: nil)
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
        //case 3:
            //filteredFoodItems.sort { $0.count > $1.count }
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        
        let foodItem = filteredFoodItems[indexPath.row]
        
        // Configure the cell with the food item's name and details
        cell.textLabel?.text = foodItem.name
        cell.detailTextLabel?.text = generateDetailsText(for: foodItem)
        
        // Apply custom formatting
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        cell.detailTextLabel?.textColor = .gray
        
        cell.accessoryType = selectedFoodItems.contains(foodItem) ? .checkmark : .none
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        
        // Custom selection color
        let customSelectionColor = UIView()
        customSelectionColor.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        cell.selectedBackgroundView = customSelectionColor
        
        return cell
    }

    private func generateDetailsText(for foodItem: FoodItem) -> String {
        var details = [String]()
        
        // Start the first detail with "ⓘ" if the food item has notes
        var firstDetail: String? = nil
        if let notes = foodItem.notes, !notes.isEmpty {
            firstDetail = "ⓘ"
        }
        
        if foodItem.perPiece {
            if foodItem.carbsPP > 0 {
                let carbsDetail = String(format: NSLocalizedString("Kh %.0fg/st", comment: "Carbohydrates per piece"), foodItem.carbsPP)
                details.append(firstDetail != nil ? "\(firstDetail!) \(carbsDetail)" : carbsDetail)
                firstDetail = nil
            }
            if foodItem.fatPP > 0 {
                let fatDetail = String(format: NSLocalizedString("Fett %.0fg/st", comment: "Fat per piece"), foodItem.fatPP)
                details.append(firstDetail != nil ? "\(firstDetail!) \(fatDetail)" : fatDetail)
                firstDetail = nil
            }
            if foodItem.proteinPP > 0 {
                let proteinDetail = String(format: NSLocalizedString("Protein %.0fg/st", comment: "Protein per piece"), foodItem.proteinPP)
                details.append(firstDetail != nil ? "\(firstDetail!) \(proteinDetail)" : proteinDetail)
                firstDetail = nil
            }
        } else {
            if foodItem.carbohydrates > 0 {
                let carbsDetail = String(format: NSLocalizedString("Kh %.0fg/100g", comment: "Carbohydrates per 100 grams"), foodItem.carbohydrates)
                details.append(firstDetail != nil ? "\(firstDetail!) \(carbsDetail)" : carbsDetail)
                firstDetail = nil
            }
            if foodItem.fat > 0 {
                let fatDetail = String(format: NSLocalizedString("Fett %.0fg/100g", comment: "Fat per 100 grams"), foodItem.fat)
                details.append(firstDetail != nil ? "\(firstDetail!) \(fatDetail)" : fatDetail)
                firstDetail = nil
            }
            if foodItem.protein > 0 {
                let proteinDetail = String(format: NSLocalizedString("Protein %.0fg/100g", comment: "Protein per 100 grams"), foodItem.protein)
                details.append(firstDetail != nil ? "\(firstDetail!) \(proteinDetail)" : proteinDetail)
                firstDetail = nil
            }
        }
        
        return details.joined(separator: " | ")
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
    
    private func filterFoodItems(with searchText: String) {
        if searchText.isEmpty {
            // If search text is empty, show all items
            filteredFoodItems = foodItems
        } else {
            // Split the search text by "." and trim whitespace
            let searchTerms = searchText.lowercased()
                .split(separator: ".")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty } // Ensure no empty terms
            
            // Filter the food items based on the search terms
            filteredFoodItems = foodItems.filter { foodItem in
                // Combine the name and emoji into one string
                let combinedText = "\(foodItem.name ?? "") \(foodItem.emoji ?? "")".lowercased()
                
                // Check if **any** search term is contained **somewhere** in the combinedText
                return searchTerms.contains(where: { term in
                    combinedText.contains(term)
                })
            }
        }
        
        // Sort and reload the table
        sortFoodItems()
        tableView.reloadData()
    }
}

extension Notification.Name {
static let foodItemsDidChange = Notification.Name("foodItemsDidChange")
}

extension SearchableDropdownViewController: UISearchBarDelegate {
    
    // Called when the "Search" button on the keyboard is tapped
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Simply dismiss the keyboard
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Save the current search text in UserDefaults
        UserDefaultsRepository.dropdownSearchText = searchText
        filterFoodItems(with: searchText)
    }
}


