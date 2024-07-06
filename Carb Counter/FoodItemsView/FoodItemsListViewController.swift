import UIKit
import CoreData
import UniformTypeIdentifiers

class FoodItemsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UISearchBarDelegate, AddFoodItemDelegate {
    private let searchTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Sök efter livsmedel online"
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .systemGray6
        textField.translatesAutoresizingMaskIntoConstraints = false

        let placeholderText = "Sök efter livsmedel online"
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemGray
        ]
        textField.attributedPlaceholder = NSAttributedString(string: placeholderText, attributes: attributes)

        return textField
    }()

    private let searchButtonOnline: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Sök", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    @IBOutlet weak var tableView: UITableView!
    var foodItems: [FoodItem] = []
    var filteredFoodItems: [FoodItem] = []
    var articles: [Article] = []
    var searchMode: SearchMode = .local
    var sortOption: SortOption = .name
    var segmentedControl: UISegmentedControl!
    var searchBar: UISearchBar!
    var clearButton: UIBarButtonItem!
    //var searchButton: UIBarButtonItem!
    var tableViewBottomConstraint: NSLayoutConstraint!
    
    var dataSharingVC: DataSharingViewController?
    
    enum SearchMode {
        case local, online
    }
    
    enum SortOption {
        case name, perPiece, count
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FoodItemTableViewCell.self, forCellReuseIdentifier: "FoodItemCell")
        tableView.register(ArticleTableViewCell.self, forCellReuseIdentifier: "ArticleCell")
        fetchFoodItems()
        setupNavigationBarButtons()
        setupNavigationBarTitle()
        setupSegmentedControl()
        setupSearchBar()
        
        clearButton = UIBarButtonItem(title: "Rensa", style: .plain, target: self, action: #selector(clearButtonTapped))
        clearButton.tintColor = .red
        navigationItem.leftBarButtonItem = clearButton
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateClearButtonVisibility), name: Notification.Name("AllowDataClearingChanged"), object: nil)
        
        updateClearButtonVisibility()
        
        let backButton = UIBarButtonItem()
        backButton.title = "Tillbaka"
        navigationItem.backBarButtonItem = backButton
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // Add the tableView as a subview and set up constraints
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            searchBar.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        tableViewBottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        tableViewBottomConstraint.isActive = true
        
        // Instantiate DataSharingViewController programmatically
        dataSharingVC = DataSharingViewController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            fetchFoodItems()
            updateClearButtonVisibility()
            
            // Ensure dataSharingVC is instantiated
            guard let dataSharingVC = dataSharingVC else { return }

            // Call the desired function
            print("Data import triggered")
            dataSharingVC.importAllCSVFiles()
            
            // Load saved search text
            if let savedSearchText = UserDefaults.standard.string(forKey: "savedSearchText"), !savedSearchText.isEmpty {
                searchBar.text = savedSearchText
                if searchMode == .local {
                    filteredFoodItems = foodItems.filter { $0.name?.lowercased().contains(savedSearchText.lowercased()) ?? false }
                } else {
                    fetchOnlineArticles(for: savedSearchText)
                }
            } else {
                // If no search text is saved, show the full list
                filteredFoodItems = foodItems
            }
            sortFoodItems()
            tableView.reloadData()
        }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func updateClearButtonVisibility() {
        let allowDataClearing = UserDefaultsRepository.allowDataClearing
        clearButton.isHidden = !allowDataClearing
    }
    
    @objc private func clearButtonTapped() {
        let firstAlertController = UIAlertController(title: "Rensa allt", message: "Vill du radera alla livsmedel från databasen?", preferredStyle: .actionSheet)
        let continueAction = UIAlertAction(title: "Fortsätt", style: .destructive) { _ in
            self.showSecondClearAlert()
        }
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        
        firstAlertController.addAction(continueAction)
        firstAlertController.addAction(cancelAction)
        
        present(firstAlertController, animated: true, completion: nil)
    }
    
    private func showSecondClearAlert() {
        let secondAlertController = UIAlertController(title: "Rensa allt", message: "Är du helt säker? Åtgärden går inte att ångra.", preferredStyle: .actionSheet)
        let clearAction = UIAlertAction(title: "Rensa", style: .destructive) { _ in
            self.clearAllFoodItems()
        }
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        
        secondAlertController.addAction(clearAction)
        secondAlertController.addAction(cancelAction)
        
        present(secondAlertController, animated: true, completion: nil)
    }
    
    private func clearAllFoodItems() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = FoodItem.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            fetchFoodItems()
        } catch {
            print("Failed to clear food items: \(error)")
        }
    }
    
    private func setupNavigationBarButtons() {
        let addButton = UIBarButtonItem(image: UIImage(systemName: "plus.circle"), style: .plain, target: self, action: #selector(navigateToAddFoodItemPlain))
        let barcodeButton = UIBarButtonItem(image: UIImage(systemName: "barcode.viewfinder"), style: .plain, target: self, action: #selector(navigateToScanner))
        clearButton = UIBarButtonItem(title: "Rensa", style: .plain, target: self, action: #selector(clearButtonTapped))
        clearButton.tintColor = .red
        
        navigationItem.rightBarButtonItems = [barcodeButton]
        navigationItem.leftBarButtonItems = [clearButton, addButton]
        updateClearButtonVisibility()
    }
    
    private func setupNavigationBarTitle() {
        title = "Livsmedel"
    }
    
    private func setupSegmentedControl() {
        let items = ["Sök bland sparade", "Sök efter nya online"]
        segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(searchModeChanged(_:)), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(segmentedControl)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupSearchBar() {
        // Initialize and add the searchBar
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "Sök bland sparade livsmedel"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
            textField.spellCheckingType = .no
            textField.inputAssistantItem.leadingBarButtonGroups = []
            textField.inputAssistantItem.trailingBarButtonGroups = []
            
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            
            let symbolImage = UIImage(systemName: "keyboard.chevron.compact.down")
            let cancelButton = UIButton(type: .system)
            cancelButton.setImage(symbolImage, for: .normal)
            cancelButton.tintColor = .systemBlue
            cancelButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
            cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
            let cancelBarButtonItem = UIBarButtonItem(customView: cancelButton)
            
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
            
            toolbar.setItems([cancelBarButtonItem, flexSpace, doneButton], animated: false)
            
            textField.inputAccessoryView = toolbar
        }
        
        view.addSubview(searchBar)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        // Set up the table view constraints
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableViewBottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableViewBottomConstraint
        ])
        
        // Update placeholder based on initial search mode
        updateSearchBarPlaceholder()
    }

    @objc private func searchModeChanged(_ sender: UISegmentedControl) {
        searchMode = sender.selectedSegmentIndex == 0 ? .local : .online
        updateSearchBarPlaceholder()
        tableView.reloadData()
    }

    private func updateSearchBarPlaceholder() {
        searchBar.placeholder = searchMode == .local ? "Sök bland sparade livsmedel" : "Sök efter nya livsmedel online"
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        guard let searchText = searchBar.text, !searchText.isEmpty else {
            articles = []
            tableView.reloadData()
            return
        }
        UserDefaults.standard.set(searchText, forKey: "savedSearchText") // Save search text
        if searchMode == .local {
            filteredFoodItems = foodItems.filter { $0.name?.lowercased().contains(searchText.lowercased()) ?? false }
            sortFoodItems()
        } else {
            fetchOnlineArticles(for: searchText)
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        UserDefaults.standard.set(searchText, forKey: "savedSearchText") // Save search text
        if searchMode == .local {
            if searchText.isEmpty {
                filteredFoodItems = foodItems
            } else {
                filteredFoodItems = foodItems.filter { $0.name?.lowercased().contains(searchText.lowercased()) ?? false }
            }
            sortFoodItems()
        } else {
            if searchText.isEmpty {
                articles = []
                tableView.reloadData()
            }
        }
    }

    private func fetchOnlineArticles(for searchText: String) {
        let dabasAPISecret = UserDefaultsRepository.dabasAPISecret
        let dabasURLString = "https://api.dabas.com/DABASService/V2/articles/searchparameter/\(searchText)/JSON?apikey=\(dabasAPISecret)"
        
        guard let dabasURL = URL(string: dabasURLString) else {
            showErrorAlert(message: "Felaktig Dabas URL")
            return
        }
        
        let dabasTask = URLSession.shared.dataTask(with: dabasURL) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Dabas API fel: \(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Dabas API fel: Ingen data togs emot")
                }
                return
            }
            
            do {
                let articles = try JSONDecoder().decode([Article].self, from: data)
                let filteredArticles = articles.filter { $0.artikelbenamning != nil }
                DispatchQueue.main.async {
                    self.articles = filteredArticles
                    self.tableView.reloadData()
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Dabas API fel: \(error.localizedDescription)")
                }
            }
        }
        
        dabasTask.resume()
    }
    
    @objc private func searchButtonOnlineTapped() {
        guard let searchText = searchTextField.text, !searchText.isEmpty else {
            // Handle empty search text
            return
        }
        
        if searchMode == .local {
            filteredFoodItems = foodItems.filter { $0.name?.lowercased().contains(searchText.lowercased()) ?? false }
            sortFoodItems()
        } else {
            fetchOnlineArticles(for: searchText)
        }
    }
    
    @objc private func doneButtonTapped() {
        searchBar.resignFirstResponder()
    }
    
    @objc private func cancelButtonTapped() {
        searchBar.resignFirstResponder()
    }
    
    func fetchFoodItems() {
        let context = CoreDataStack.shared.context
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        do {
            foodItems = try context.fetch(fetchRequest)
            filteredFoodItems = foodItems
            sortFoodItems()
        } catch {
            print("Failed to fetch food items: \(error)")
        }
    }
    
    func sortFoodItems() { // Not used currently
        switch sortOption {
        case .name:
            filteredFoodItems.sort { $0.name ?? "" < $1.name ?? "" }
        case .perPiece:
            filteredFoodItems.sort { $0.perPiece && !$1.perPiece }
        case .count:
            filteredFoodItems.sort { $0.count > $1.count }
        }
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Radera") { (_, _, completionHandler) in
            if self.searchMode == .local {
                let foodItem = self.filteredFoodItems[indexPath.row]
                self.showDeleteConfirmationAlert(at: indexPath, foodItemName: foodItem.name ?? "detta livsmedel")
            }
            completionHandler(true)
        }
        deleteAction.backgroundColor = .red // Optionally set the background color

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = false // Disable full swipe to avoid accidental deletions
        return configuration
    }

    private func showDeleteConfirmationAlert(at indexPath: IndexPath, foodItemName: String) {
        let alert = UIAlertController(title: "Radera Livsmedel", message: "Bekräfta att du vill radera: '\(foodItemName)'?", preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: "Radera", style: .destructive) { _ in
            self.deleteFoodItem(at: indexPath)
        }
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch searchMode {
        case .local:
            return filteredFoodItems.count
        case .online:
            return articles.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch searchMode {
        case .local:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FoodItemCell", for: indexPath) as! FoodItemTableViewCell
            let foodItem = filteredFoodItems[indexPath.row]
            cell.configure(with: foodItem)
            return cell
        case .online:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ArticleCell", for: indexPath) as! ArticleTableViewCell
            let article = articles[indexPath.row]
            cell.configure(with: article)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch searchMode {
        case .local:
            let foodItem = filteredFoodItems[indexPath.row]
            showLocalFoodItemDetails(foodItem)
        case .online:
            let article = articles[indexPath.row]
            if let gtin = article.gtin {
                fetchNutritionalInfo(for: gtin)
            }
        }
    }
    
    private func showLocalFoodItemDetails(_ foodItem: FoodItem) {
        let title = "\(foodItem.emoji ?? "") \(foodItem.name ?? "")"
        var message = ""
        
        if let notes = foodItem.notes, !notes.isEmpty {
            message += "\nNot: \(notes)\n"
        }
        
        if foodItem.perPiece {
            if foodItem.carbsPP > 0 {
                message += "\nKolhydrater: \(String(format: "%.0f", foodItem.carbsPP)) g / st"
            }
            if foodItem.fatPP > 0 {
                message += "\nFett: \(String(format: "%.0f", foodItem.fatPP)) g / st"
            }
            if foodItem.proteinPP > 0 {
                message += "\nProtein: \(String(format: "%.0f", foodItem.proteinPP)) g / st"
            }
        } else {
            if foodItem.carbohydrates > 0 {
                message += "\nKolhydrater: \(String(format: "%.0f", foodItem.carbohydrates)) g / 100 g"
            }
            if foodItem.fat > 0 {
                message += "\nFett: \(String(format: "%.0f", foodItem.fat)) g / 100 g"
            }
            if foodItem.protein > 0 {
                message += "\nProtein: \(String(format: "%.0f", foodItem.protein)) g / 100 g"
            }
        }
        
        message += "\n\n(Serverats: \(foodItem.count) ggr)"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Ändra", style: .destructive, handler: { _ in
            self.editFoodItem(at: IndexPath(row: self.filteredFoodItems.firstIndex(of: foodItem) ?? 0, section: 0))
        }))
        
        alert.addAction(UIAlertAction(title: "+ Lägg till i måltid", style: .default, handler: { _ in
            self.addToComposeMealViewController(foodItem: foodItem)
        }))
        
        alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: nil))
        
        present(alert, animated: true, completion: nil)
        tableView.deselectRow(at: IndexPath(row: self.filteredFoodItems.firstIndex(of: foodItem) ?? 0, section: 0), animated: true)
    }
    
    private func addToComposeMealViewController(foodItem: FoodItem) {
        guard let tabBarController = tabBarController else {
            print("Tab bar controller not found")
            return
        }
        
        for viewController in tabBarController.viewControllers ?? [] {
            if let navController = viewController as? UINavigationController {
                for vc in navController.viewControllers {
                    if let composeMealVC = vc as? ComposeMealViewController {
                        print("Adding food item to ComposeMealViewController: \(foodItem.name ?? "")")
                        composeMealVC.addFoodItemRow(with: foodItem)
                        return
                    }
                }
            }
        }
        print("ComposeMealViewController not found in tab bar controller")
    }
    
    private func deleteFoodItem(at indexPath: IndexPath) {
        let foodItem = filteredFoodItems[indexPath.row]
        let context = CoreDataStack.shared.context
        context.delete(foodItem)
        do {
            try context.save()
            foodItems.remove(at: indexPath.row)
            filteredFoodItems.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        } catch {
            print("Failed to delete food item: \(error)")
        }
        
        // Ensure dataSharingVC is instantiated
                guard let dataSharingVC = dataSharingVC else { return }

                // Call the desired function
                dataSharingVC.exportFoodItemsToCSV()
        print("Food items export triggered")
    }
    
    private func editFoodItem(at indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            addFoodItemVC.foodItem = filteredFoodItems[indexPath.row]
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        UserDefaults.standard.removeObject(forKey: "savedSearchText") // Clear saved search text
        if searchMode == .local {
            filteredFoodItems = foodItems
            sortFoodItems()
        }
        searchBar.resignFirstResponder()
    }
    @objc func keyboardWillShow(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            if let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                tableViewBottomConstraint.constant = -keyboardFrame.height + 2
                view.layoutIfNeeded()
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        tableViewBottomConstraint.constant = 0
        view.layoutIfNeeded()
    }
    
    @objc private func navigateToAddFoodItemPlain() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }
    
    @objc private func navigateToScanner() {
        let scannerVC = ScannerViewController()
        navigationController?.pushViewController(scannerVC, animated: true)
    }
    
    private func fetchNutritionalInfo(for gtin: String) {
        let dabasAPISecret = UserDefaultsRepository.dabasAPISecret
        let dabasURLString = "https://api.dabas.com/DABASService/V2/article/gtin/\(gtin)/JSON?apikey=\(dabasAPISecret)"
        guard let dabasURL = URL(string: dabasURLString) else {
            showErrorAlert(message: "Felaktig Dabas URL")
            return
        }
        
        let dabasTask = URLSession.shared.dataTask(with: dabasURL) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Dabas API fel: \(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Dabas API fel: Ingen data togs emot")
                }
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    guard let artikelbenamning = jsonResponse["Artikelbenamning"] as? String,
                          let naringsinfoArray = jsonResponse["Naringsinfo"] as? [[String: Any]],
                          let naringsinfo = naringsinfoArray.first,
                          let naringsvarden = naringsinfo["Naringsvarden"] as? [[String: Any]] else {
                        DispatchQueue.main.async {
                            self.showErrorAlert(message: "Kunde inte hitta information om livsmedlet")
                        }
                        return
                    }
                    var carbohydrates = 0.0
                    var fat = 0.0
                    var proteins = 0.0
                    
                    for nutrient in naringsvarden {
                        if let code = nutrient["Kod"] as? String, let amount = nutrient["Mangd"] as? Double {
                            switch code {
                            case "CHOAVL":
                                carbohydrates = amount
                            case "FAT":
                                fat = amount
                            case "PRO-":
                                proteins = amount
                            default:
                                break
                            }
                        }
                    }
                    
                    let message = """
                    Kolhydrater: \(carbohydrates) g / 100 g
                    Fett: \(fat) g / 100 g
                    Protein: \(proteins) g / 100 g
                    
                    (Källa: Dabas)
                    """
                    
                    DispatchQueue.main.async {
                        self.showProductAlert(title: artikelbenamning, message: message, productName: artikelbenamning, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showErrorAlert(message: "Dabas API fel: Kunde inte tolka svar från servern")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Dabas API error: \(error.localizedDescription)")
                }
            }
        }
        
        dabasTask.resume()
    }
    
    private func showProductAlert(title: String, message: String, productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", productName)
        
        do {
            let existingItems = try context.fetch(fetchRequest)
            
            if let existingItem = existingItems.first {
                let comparisonMessage = """
                Befintlig data    ->    Ny data
                Kh:       \(formattedValue(existingItem.carbohydrates))  ->  \(formattedValue(carbohydrates)) g/100g
                Fett:    \(formattedValue(existingItem.fat))  ->  \(formattedValue(fat)) g/100g
                Protein:  \(formattedValue(existingItem.protein))  ->  \(formattedValue(proteins)) g/100g
                """
                
                let duplicateAlert = UIAlertController(title: productName, message: "Finns redan inlagt i livsmedelslistan. \n\nVill du behålla de befintliga näringsvärdena eller uppdatera dem?\n\n\(comparisonMessage)", preferredStyle: .alert)
                duplicateAlert.addAction(UIAlertAction(title: "Behåll befintliga", style: .default, handler: { _ in
                    self.navigateToAddFoodItem(foodItem: existingItem)
                }))
                duplicateAlert.addAction(UIAlertAction(title: "Uppdatera", style: .default, handler: { _ in
                    self.navigateToAddFoodItemWithUpdate(existingItem: existingItem, productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                }))
                duplicateAlert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: nil))
                present(duplicateAlert, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: "Lägg till", style: .default, handler: { _ in
                    self.navigateToAddFoodItem(productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                }))
                present(alert, animated: true, completion: nil)
            }
        } catch {
            showErrorAlert(message: "Ett fel uppstod vid hämtning av livsmedelsdata.")
        }
    }
    
    private func formattedValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Fel", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func navigateToAddFoodItem(foodItem: FoodItem) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            addFoodItemVC.foodItem = foodItem
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }
    
    private func navigateToAddFoodItem(productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            addFoodItemVC.prePopulatedData = (productName, carbohydrates, fat, proteins)
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }
    
    private func navigateToAddFoodItemWithUpdate(existingItem: FoodItem, productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            addFoodItemVC.foodItem = existingItem
            addFoodItemVC.prePopulatedData = (productName, carbohydrates, fat, proteins)
            addFoodItemVC.isUpdateMode = true
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }
    
    // AddFoodItemDelegate conformance
    func didAddFoodItem() {
        fetchFoodItems()
    }
}

struct Article: Codable {
let artikelbenamning: String?
let varumarke: String?
let forpackningsstorlek: String?
let gtin: String?  // Add this line

enum CodingKeys: String, CodingKey {
case artikelbenamning = "Artikelbenamning"
case varumarke = "Varumarke"
case forpackningsstorlek = "Forpackningsstorlek"
case gtin = "GTIN"  // Add this line
}
}
class ArticleTableViewCell: UITableViewCell {
let nameLabel: UILabel = {
let label = UILabel()
label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
label.translatesAutoresizingMaskIntoConstraints = false
return label
}()
let detailsLabel: UILabel = {
let label = UILabel()
label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
label.textColor = .gray
label.translatesAutoresizingMaskIntoConstraints = false
return label
}()

var gtin: String? // Add this property to store GTIN

override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
super.init(style: style, reuseIdentifier: reuseIdentifier)
contentView.addSubview(nameLabel)
contentView.addSubview(detailsLabel)

NSLayoutConstraint.activate([
nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 16),

detailsLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
detailsLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
detailsLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
detailsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
])
}

required init?(coder: NSCoder) {
fatalError("init(coder:) has not been implemented")
}

func configure(with article: Article) {
nameLabel.text = article.artikelbenamning
detailsLabel.text = "\(article.varumarke ?? "") • \(article.forpackningsstorlek ?? "")"
gtin = article.gtin // Store GTIN
}
}
