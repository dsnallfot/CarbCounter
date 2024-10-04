// Daniel: 1100+ lines - To be cleaned
import UIKit
import CoreData
import UniformTypeIdentifiers

class FoodItemsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UISearchBarDelegate, AddFoodItemDelegate {
    private var lastSearchTime: Date?
    private var isUsingDabas: Bool = true
    
    private let searchTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = NSLocalizedString("Sök efter livsmedel online", comment: "Sök efter livsmedel online")
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .systemGray6
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        let placeholderText = NSLocalizedString("Sök efter livsmedel online", comment: "Sök efter livsmedel online")
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemGray
        ]
        textField.attributedPlaceholder = NSAttributedString(string: placeholderText, attributes: attributes)
        
        return textField
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
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FoodItemTableViewCell.self, forCellReuseIdentifier: "FoodItemCell")
        tableView.register(ArticleTableViewCell.self, forCellReuseIdentifier: "ArticleCell")
        tableView.backgroundColor = .clear
        self.fetchFoodItems()
        setupNavigationBarButtons()
        setupNavigationBarTitle()
        setupSegmentedControl()
        setupSearchBar()
        
        clearButton = UIBarButtonItem(title: NSLocalizedString("Rensa", comment: "Rensa"), style: .plain, target: self, action: #selector(clearButtonTapped))
        clearButton.tintColor = .red
        navigationItem.leftBarButtonItem = clearButton
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateClearButtonVisibility), name: Notification.Name("AllowDataClearingChanged"), object: nil)
        
        updateClearButtonVisibility()
        
        let backButton = UIBarButtonItem()
        backButton.title = NSLocalizedString("Tillbaka", comment: "Tillbaka")
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
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor), //constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])
        
        tableViewBottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90)
        tableViewBottomConstraint.isActive = true
        
        // Instantiate DataSharingViewController programmatically
        dataSharingVC = DataSharingViewController()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.fetchFoodItems()
        updateClearButtonVisibility()
        
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else { return }
        
        // Call the desired function

        Task {
            print("Data import triggered")
            await dataSharingVC.importAllCSVFiles()
        }
        
        // Load saved search text
        if let savedSearchText = UserDefaultsRepository.savedSearchText, !savedSearchText.isEmpty {
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
        let firstAlertController = UIAlertController(title: NSLocalizedString("Rensa allt", comment: "Rensa allt"), message: NSLocalizedString("Vill du radera alla livsmedel från databasen?", comment: "Vill du radera alla livsmedel från databasen?"), preferredStyle: .actionSheet)
        let continueAction = UIAlertAction(title: NSLocalizedString("Fortsätt", comment: "Fortsätt"), style: .destructive) { _ in
            self.showSecondClearAlert()
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel, handler: nil)
        
        firstAlertController.addAction(continueAction)
        firstAlertController.addAction(cancelAction)
        
        present(firstAlertController, animated: true, completion: nil)
    }
    
    private func showSecondClearAlert() {
        let secondAlertController = UIAlertController(title: NSLocalizedString("Rensa allt", comment: "Rensa allt"), message: NSLocalizedString("Är du helt säker? Åtgärden går inte att ångra.", comment: "Är du helt säker? Åtgärden går inte att ångra."), preferredStyle: .actionSheet)
        let clearAction = UIAlertAction(title: NSLocalizedString("Rensa", comment: "Rensa"), style: .destructive) { _ in
            self.clearAllFoodItems()
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel, handler: nil)
        
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
        clearButton = UIBarButtonItem(title: NSLocalizedString("Rensa", comment: "Rensa"), style: .plain, target: self, action: #selector(clearButtonTapped))
        clearButton.tintColor = .red
        
        navigationItem.rightBarButtonItems = [barcodeButton, addButton]
        navigationItem.leftBarButtonItems = [clearButton]
        updateClearButtonVisibility()
    }
    
    private func setupNavigationBarTitle() {
        title = NSLocalizedString("Livsmedel", comment: "Livsmedel")
    }
    
    private func setupSegmentedControl() {
        let items = [NSLocalizedString("Sök sparade", comment: "Sök sparade"), NSLocalizedString("Sök online", comment: "Sök online")]
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
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.backgroundImage = UIImage() // Make background clear
        
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .sentences
            textField.spellCheckingType = .yes //Other keyboards are set without spell checking, but this one has it since online search will be triggered by this search text
            textField.inputAssistantItem.leadingBarButtonGroups = []
            textField.inputAssistantItem.trailingBarButtonGroups = []
            
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
        
        view.addSubview(searchBar)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        // Set up the table view constraints
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableViewBottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90)
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

        // Perform the search with the current search text
        if let searchText = searchBar.text, !searchText.isEmpty {
            searchBarSearchButtonClicked(searchBar)
        } else {
            if searchMode == .local {
                filteredFoodItems = foodItems
                sortFoodItems()
                tableView.reloadData()
            } else {
                articles = []
                tableView.reloadData()
            }
        }
    }
    
    private func updateSearchBarPlaceholder() {
        let foodItemCount = Double(foodItems.count)
        searchBar.placeholder = searchMode == .local
            ? String(format: NSLocalizedString("Sök bland %.0f sparade livsmedel", comment: "Sök bland %.0f sparade livsmedel"), foodItemCount)
            : NSLocalizedString("Sök efter nya livsmedel online", comment: "Sök efter nya livsmedel online")
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        guard let searchText = searchBar.text, !searchText.isEmpty else {
            articles = []
            tableView.reloadData()
            return
        }
        UserDefaultsRepository.savedSearchText = searchText // Save search text
        if searchMode == .local {
            filteredFoodItems = foodItems.filter { $0.name?.lowercased().contains(searchText.lowercased()) ?? false }
            sortFoodItems()
        } else {
            fetchOnlineArticles(for: searchText)
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        UserDefaultsRepository.savedSearchText = searchText // Save search text
        if searchMode == .local {
            if searchText.isEmpty {
                filteredFoodItems = foodItems
                sortFoodItems()
                tableView.reloadData()
            } else {
                filteredFoodItems = foodItems.filter { foodItem in
                    let nameMatches = foodItem.name?.lowercased().contains(searchText.lowercased()) ?? false
                    let emojiMatches = foodItem.emoji?.lowercased().contains(searchText.lowercased()) ?? false
                    return nameMatches || emojiMatches
                }
                sortFoodItems()
            }
        } else {
            if searchText.isEmpty {
                articles = []
                tableView.reloadData()
            }
        }
    }
    private func fetchOnlineArticles(for searchText: String) {
        // Replace all spaces with + signs and make the search text HTTP friendly
        let formattedSearchText = searchText.replacingOccurrences(of: " ", with: "+").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchText

        let dabasAPISecret = UserDefaultsRepository.dabasAPISecret
        
        // Check if the Dabas API secret is empty
        if dabasAPISecret.isEmpty {
            self.searchOpenfoodfacts(for: searchText)
            return
        }

        let dabasURLString = "https://api.dabas.com/DABASService/V2/articles/searchparameter/\(formattedSearchText)/JSON?apikey=\(dabasAPISecret)"
        
        guard let dabasURL = URL(string: dabasURLString) else {
            self.searchOpenfoodfacts(for: searchText)
            showErrorAlert(message: NSLocalizedString("Felaktig Dabas URL", comment: "Felaktig Dabas URL"))
            return
        }
        
        let dabasTask = URLSession.shared.dataTask(with: dabasURL) { data, response, error in
            if let error = error {
                self.searchOpenfoodfacts(for: searchText)
                DispatchQueue.main.async {
                    self.showErrorAlert(message: String(format: NSLocalizedString("Dabas API fel: %@", comment: "Dabas API fel: %@"), error.localizedDescription))
                }
                return
            }
            
            guard let data = data else {
                self.searchOpenfoodfacts(for: searchText)
                DispatchQueue.main.async {
                    self.showErrorAlert(message: NSLocalizedString("Dabas API fel: Ingen data togs emot", comment: "Dabas API fel: Ingen data togs emot"))
                }
                return
            }
            
            do {
                // Decode the JSON response
                let articles = try JSONDecoder().decode([DabasArticle].self, from: data)
                DispatchQueue.main.async {
                    if articles.isEmpty {
                        // If no articles found in Dabas, fallback to OpenFoodFacts
                        self.searchOpenfoodfacts(for: searchText)
                    } else {
                        self.isUsingDabas = true
                        self.articles = articles.map { Article(from: $0) }.filter { $0.artikelbenamning != nil && !$0.artikelbenamning!.isEmpty }
                        self.tableView.reloadData()
                    }
                }
            } catch {
                self.searchOpenfoodfacts(for: searchText)
                DispatchQueue.main.async {
                    print("Dabas API fel: \(error.localizedDescription)")
                }
            }
        }
        
        dabasTask.resume()
    }
    
    private func searchOpenfoodfacts(for searchText: String) {
        // Check if the search is within the allowed rate limit
        if let lastSearchTime = lastSearchTime, Date().timeIntervalSince(lastSearchTime) < 8 {
            DispatchQueue.main.async {
                self.showAlert(title: NSLocalizedString("API Begränsning", comment: "API Begränsning"), message: NSLocalizedString("Vänta några sekunder innan nästa sökning", comment: "Vänta några sekunder innan nästa sökning"))
            }
            return
        }
        
        lastSearchTime = Date() // Update the time of the last search
        
        let openfoodURLString = "https://en.openfoodfacts.org/cgi/search.pl?&search_terms=\(searchText)&action=process&json=1&fields=product_name,brands,ingredients_text,carbohydrates_100g,fat_100g,proteins_100g&search_simple=1"
        print(openfoodURLString)
        
        guard let openfoodURL = URL(string: openfoodURLString) else {
            showErrorAlert(message: NSLocalizedString("Felaktig OpenFoodFacts URL", comment: "Felaktig OpenFoodFacts URL"))
            return
        }
        
        var request = URLRequest(url: openfoodURL)
        request.addValue("CarbsCounterApp_iOS_Version_0.1", forHTTPHeaderField: "User-Agent")
        
        let openfoodTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: String(format: NSLocalizedString("OpenFoodFacts API fel: %@", comment: "OpenFoodFacts API fel: %@"), error.localizedDescription))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: NSLocalizedString("OpenFoodFacts API fel: Ingen data togs emot", comment: "OpenFoodFacts API fel: Ingen data togs emot"))
                }
                return
            }
            
            do {
                // Decode the JSON response
                let jsonResponse = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
                DispatchQueue.main.async {
                    if jsonResponse.count == 0 {
                        self.showAlert(title: NSLocalizedString("Inga sökträffar", comment: "Inga sökträffar"), message: NSLocalizedString("OK", comment: "OK"))
                    } else {
                        self.isUsingDabas = false
                        self.articles = jsonResponse.products.map { Article(from: $0) }
                        self.tableView.reloadData()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: String(format: NSLocalizedString("OpenFoodFacts API fel: %@", comment: "OpenFoodFacts API fel: %@"), error.localizedDescription))
                }
            }
        }
        
        openfoodTask.resume()
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
    
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    @objc private func doneButtonTapped() {
        searchBar.resignFirstResponder()
    }
    
    @objc private func cancelButtonTapped() {
        searchBar.resignFirstResponder()
    }
    
    func fetchFoodItems() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        
        // Apply predicate to filter out items where delete is true
        fetchRequest.predicate = NSPredicate(format: "delete == NO OR delete == nil")
        
        do {
            // Fetch filtered items
            foodItems = try context.fetch(fetchRequest)
            
            // Ensure that filteredFoodItems is updated to reflect changes
            filteredFoodItems = foodItems
            
            DispatchQueue.main.async {
                self.sortFoodItems()
                self.tableView.reloadData()
                self.updateSearchBarPlaceholder() // Update the search bar placeholder after fetching items
            }
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
        // "Mer" action
        let moreAction = UIContextualAction(style: .normal, title: nil) { (_, _, completionHandler) in
            let foodItem = self.filteredFoodItems[indexPath.row]
            self.showLocalFoodItemDetails(foodItem)
            completionHandler(true)
        }
        moreAction.backgroundColor = .systemGray
        moreAction.image = UIImage(systemName: "ellipsis.circle.fill")

        // "Ändra" action
        let editAction = UIContextualAction(style: .normal, title: nil) { (_, _, completionHandler) in
            self.editFoodItem(at: indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemBlue
        editAction.image = UIImage(systemName: "square.and.pencil")

        // "Radera" action
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { (_, _, completionHandler) in
            if self.searchMode == .local {
                let foodItem = self.filteredFoodItems[indexPath.row]
                self.showDeleteConfirmationAlert(at: indexPath, foodItemName: foodItem.name ?? NSLocalizedString("detta livsmedel", comment: "detta livsmedel"))
            }
            completionHandler(true)
        }
        deleteAction.backgroundColor = .red
        deleteAction.image = UIImage(systemName: "trash.fill")

        // Add both actions to the configuration
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction, moreAction])
        configuration.performsFirstActionWithFullSwipe = false // Disable full swipe to avoid accidental deletions
        return configuration
    }

    
    private func showDeleteConfirmationAlert(at indexPath: IndexPath, foodItemName: String) {
        let alert = UIAlertController(title: NSLocalizedString("Radera Livsmedel", comment: "Radera Livsmedel"), message: String(format: NSLocalizedString("Bekräfta att du vill radera: '%@'?", comment: "Bekräfta att du vill radera: '%@'?"), foodItemName), preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: NSLocalizedString("Radera", comment: "Radera"), style: .destructive) { _ in
            self.deleteFoodItem(at: indexPath)
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel, handler: nil)
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
            let foodItem = filteredFoodItems[safe: indexPath.row] // Safely access the index
            if let foodItem = foodItem {
                cell.configure(with: foodItem)
            }
            cell.backgroundColor = .clear // Set cell background to clear
            return cell
        case .online:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ArticleCell", for: indexPath) as! ArticleTableViewCell
            if let article = articles[safe: indexPath.row] {
                cell.configure(with: article)
            }
            cell.backgroundColor = .clear // Set cell background to clear
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
            if isUsingDabas {
                if let gtin = article.gtin {
                    fetchNutritionalInfo(for: gtin)
                }
            } else {
                let message = String(format: NSLocalizedString("""
                Kolhydrater: %@ g / 100 g
                Fett: %@ g / 100 g
                Protein: %@ g / 100 g
                
                [Källa: OpenFoodFacts]
                """, comment: "Nutritional information displayed for a food product"),
                formattedValue(article.carbohydrates_100g ?? 0),
                formattedValue(article.fat_100g ?? 0),
                formattedValue(article.proteins_100g ?? 0))

                let title = article.artikelbenamning ?? NSLocalizedString("Produkt", comment: "Default title for a product")
                self.showProductAlert(
                    title: title,
                    message: message,
                    productName: title,
                    carbohydrates: article.carbohydrates_100g ?? 0,
                    fat: article.fat_100g ?? 0,
                    proteins: article.proteins_100g ?? 0
                )
            }
        }
    }
    
    private func showLocalFoodItemDetails(_ foodItem: FoodItem) {
        // Clean up the emoji string by trimming unnecessary whitespace or newlines
        var emoji = foodItem.emoji ?? ""
        emoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        emoji = emoji.precomposedStringWithCanonicalMapping  // Normalize emoji
        
        // Format the title string with the cleaned emoji
        let title = "\(emoji) \(foodItem.name ?? NSLocalizedString("Produkt", comment: "Default product name if none is provided"))"
        
        var message = ""

        if let notes = foodItem.notes, !notes.isEmpty {
            message += "\n\(NSLocalizedString("Not:", comment: "Label for notes")) \(notes)\n"
        }

        if foodItem.perPiece {
            if foodItem.carbsPP > 0 {
                message += "\n\(NSLocalizedString("Kolhydrater:", comment: "Carbohydrates label")) \(String(format: "%.0f", foodItem.carbsPP)) \(NSLocalizedString("g / st", comment: "Per piece unit for carbohydrates"))"
            }
            if foodItem.fatPP > 0 {
                message += "\n\(NSLocalizedString("Fett:", comment: "Fat label")) \(String(format: "%.0f", foodItem.fatPP)) \(NSLocalizedString("g / st", comment: "Per piece unit for fat"))"
            }
            if foodItem.proteinPP > 0 {
                message += "\n\(NSLocalizedString("Protein:", comment: "Protein label")) \(String(format: "%.0f", foodItem.proteinPP)) \(NSLocalizedString("g / st", comment: "Per piece unit for protein"))"
            }
        } else {
            if foodItem.carbohydrates > 0 {
                message += "\n\(NSLocalizedString("Kolhydrater:", comment: "Carbohydrates label")) \(String(format: "%.0f", foodItem.carbohydrates)) \(NSLocalizedString("g / 100 g", comment: "Per 100 grams unit for carbohydrates"))"
            }
            if foodItem.fat > 0 {
                message += "\n\(NSLocalizedString("Fett:", comment: "Fat label")) \(String(format: "%.0f", foodItem.fat)) \(NSLocalizedString("g / 100 g", comment: "Per 100 grams unit for fat"))"
            }
            if foodItem.protein > 0 {
                message += "\n\(NSLocalizedString("Protein:", comment: "Protein label")) \(String(format: "%.0f", foodItem.protein)) \(NSLocalizedString("g / 100 g", comment: "Per 100 grams unit for protein"))"
            }
        }

        message += "\n\n\(NSLocalizedString("Serverats:", comment: "Label for number of times the food item has been served")) \(foodItem.count) \(NSLocalizedString("ggr", comment: "Abbreviation for times served"))"

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: NSLocalizedString("+ Lägg till i måltid", comment: "Add to meal button"), style: .default, handler: { _ in
            self.addToComposeMealViewController(foodItem: foodItem)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Mer insikter", comment: "Insights button"), style: .default, handler: { _ in
            self.presentMealInsightsViewController(with: foodItem)
        }))
        
        if UserDefaultsRepository.allowDataClearing {
            alert.addAction(UIAlertAction(title: NSLocalizedString("Nollställ räknare", comment: "Reset counter button"), style: .destructive, handler: { _ in
                foodItem.count = 0
                self.saveFoodItemChanges(for: foodItem)
            }))
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel button"), style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
        tableView.deselectRow(at: IndexPath(row: self.filteredFoodItems.firstIndex(of: foodItem) ?? 0, section: 0), animated: true)
    }

    private func saveFoodItemChanges(for foodItem: FoodItem) {
        let context = CoreDataStack.shared.context
        
        do {
            try context.save()
            print("Food item count reset and saved successfully.")
            
            // Notify that food items have changed
            NotificationCenter.default.post(name: .foodItemsDidChange, object: nil, userInfo: ["foodItems": fetchAllFoodItems()])
            
            // Ensure dataSharingVC is instantiated
            guard let dataSharingVC = dataSharingVC else {
                print("dataSharingVC not available, unable to export food items.")
                return
            }

            // Call the export function
            Task {
                print("Food items export triggered")
                await dataSharingVC.exportFoodItemsToCSV()
            }
        } catch {
            print("Failed to save food item: \(error)")
        }
    }

    
    private func fetchAllFoodItems() -> [FoodItem] {
        let context = CoreDataStack.shared.context
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch food items: \(error)")
            return []
        }
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
    
    private func presentMealInsightsViewController(with foodItem: FoodItem) {
        // Create an instance of MealInsightsViewController
        let mealInsightsVC = MealInsightsViewController()

        // Prepopulate the search text field with the foodItem name
        mealInsightsVC.prepopulatedSearchText = foodItem.name ?? ""

        // Embed the MealInsightsViewController in a UINavigationController
        let navController = UINavigationController(rootViewController: mealInsightsVC)

        // Set the modal presentation style
        navController.modalPresentationStyle = .pageSheet

        // Present the view controller modally
        present(navController, animated: true, completion: nil)
    }
    
    private func deleteFoodItem(at indexPath: IndexPath) {
        let foodItem = filteredFoodItems[indexPath.row]
        let context = CoreDataStack.shared.context
        
        // Step 1: Set the delete flag to true
        foodItem.delete = true
        
        do {
            // Step 2: Save the context with the updated delete flag
            try context.save()
            
            // Step 3: Export the updated list to CSV before marking the item as deleted
            guard let dataSharingVC = dataSharingVC else { return }
            Task {
                print("Food items export triggered")
                await dataSharingVC.exportFoodItemsToCSV()
                
                // Step 4: Update the table view without deleting the Core Data entry
                filteredFoodItems.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                updateSearchBarPlaceholder() // Update the search bar placeholder after deleting an item
            }
        } catch {
            print("Failed to update delete flag: \(error)")
        }
    }
    
    private func editFoodItem(at indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self // Set the delegate
            addFoodItemVC.foodItem = filteredFoodItems[indexPath.row]
            let navController = UINavigationController(rootViewController: addFoodItemVC)
            navController.modalPresentationStyle = .pageSheet
            
            present(navController, animated: true, completion: nil)
        }
    }
    
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        UserDefaultsRepository.savedSearchText = nil // Clear saved search text
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
    
    @objc private func navigateToScanner() {
        let scannerVC = ScannerViewController()
        let navController = UINavigationController(rootViewController: scannerVC)
        navController.modalPresentationStyle = .pageSheet
        
        present(navController, animated: true, completion: nil)
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
                    
                    [Källa: Dabas]
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
        
        var isPerPiece: Bool = false // New flag
        
        do {
            let existingItems = try context.fetch(fetchRequest)
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            alert.addTextField { textField in
                textField.placeholder = NSLocalizedString("Ange vikt per styck i gram (valfritt)", comment: "Placeholder for inputting weight per piece in grams (optional)")
                textField.keyboardType = .decimalPad
            }
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel button"), style: .cancel, handler: nil))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Lägg till", comment: "Add button"), style: .default, handler: { _ in
                let adjustedProductName = productName
                if let textField = alert.textFields?.first, let text = textField.text, let weight = Double(text), weight > 0 {
                    let adjustedCarbs = (carbohydrates * weight / 100).roundToDecimal(1)
                    let adjustedFat = (fat * weight / 100).roundToDecimal(1)
                    let adjustedProteins = (proteins * weight / 100).roundToDecimal(1)
                    isPerPiece = true // Update the flag
                    self.navigateToAddFoodItem(productName: adjustedProductName, carbohydrates: adjustedCarbs, fat: adjustedFat, proteins: adjustedProteins, isPerPiece: isPerPiece)
                } else {
                    self.navigateToAddFoodItem(productName: adjustedProductName, carbohydrates: carbohydrates, fat: fat, proteins: proteins, isPerPiece: isPerPiece)
                }
            }))
            
            if let existingItem = existingItems.first {
                let comparisonMessage = """
                \(NSLocalizedString("Befintlig data", comment: "Existing data"))    ->    \(NSLocalizedString("Ny data", comment: "New data"))
                \(NSLocalizedString("Kh:", comment: "Carbohydrates abbreviation"))       \(formattedValue(existingItem.carbohydrates))  ->  \(formattedValue(carbohydrates)) \(NSLocalizedString("g/100g", comment: "grams per 100 grams"))
                \(NSLocalizedString("Fett:", comment: "Fat label"))    \(formattedValue(existingItem.fat))  ->  \(formattedValue(fat)) \(NSLocalizedString("g/100g", comment: "grams per 100 grams"))
                \(NSLocalizedString("Protein:", comment: "Protein label"))  \(formattedValue(existingItem.protein))  ->  \(formattedValue(proteins)) \(NSLocalizedString("g/100g", comment: "grams per 100 grams"))
                """
                
                let duplicateAlert = UIAlertController(
                    title: productName,
                    message: "\(NSLocalizedString("Finns redan inlagt i livsmedelslistan.", comment: "Product already exists message")) \n\n\(NSLocalizedString("Vill du behålla de befintliga näringsvärdena eller uppdatera dem?", comment: "Message asking if user wants to keep existing nutritional values or update them"))\n\n\(comparisonMessage)",
                    preferredStyle: .alert
                )
                duplicateAlert.addAction(UIAlertAction(title: NSLocalizedString("Behåll befintliga", comment: "Keep existing data"), style: .default, handler: { _ in
                    self.navigateToAddFoodItem(foodItem: existingItem)
                }))
                duplicateAlert.addAction(UIAlertAction(title: NSLocalizedString("Uppdatera", comment: "Update existing data"), style: .default, handler: { _ in
                    self.navigateToAddFoodItemWithUpdate(existingItem: existingItem, productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                }))
                duplicateAlert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel button"), style: .cancel, handler: nil))
                present(duplicateAlert, animated: true, completion: nil)
            } else {
                present(alert, animated: true, completion: nil)
            }
        } catch {
            showErrorAlert(message: NSLocalizedString("Ett fel uppstod vid hämtning av livsmedelsdata.", comment: "Error message for fetching food item data"))
        }
    }
    
    private func formattedValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Fel"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func navigateToAddFoodItemPlain() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            let navController = UINavigationController(rootViewController: addFoodItemVC)
            navController.modalPresentationStyle = .pageSheet
            
            present(navController, animated: true, completion: nil)
        }
    }

    private func navigateToAddFoodItem(foodItem: FoodItem) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            addFoodItemVC.foodItem = foodItem
            let navController = UINavigationController(rootViewController: addFoodItemVC)
            navController.modalPresentationStyle = .pageSheet
            
            present(navController, animated: true, completion: nil)
        }
    }

    private func navigateToAddFoodItem(productName: String, carbohydrates: Double, fat: Double, proteins: Double, isPerPiece: Bool) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            addFoodItemVC.prePopulatedData = (productName, carbohydrates, fat, proteins)
            addFoodItemVC.isPerPiece = isPerPiece
            let navController = UINavigationController(rootViewController: addFoodItemVC)
            navController.modalPresentationStyle = .pageSheet
            
            present(navController, animated: true, completion: nil)
        }
    }

    private func navigateToAddFoodItemWithUpdate(existingItem: FoodItem, productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            addFoodItemVC.foodItem = existingItem
            addFoodItemVC.prePopulatedData = (productName, carbohydrates, fat, proteins)
            addFoodItemVC.isUpdateMode = true
            let navController = UINavigationController(rootViewController: addFoodItemVC)
            navController.modalPresentationStyle = .pageSheet
            
            present(navController, animated: true, completion: nil)
        }
    }
    
    // AddFoodItemDelegate conformance
    func didAddFoodItem() {
        // Fetch updated list of food items
        fetchFoodItems()
        
        // Update the filtered list and reload the table view
        filteredFoodItems = foodItems // Ensure filtered list is updated
        sortFoodItems()
        tableView.reloadData()
    }
}

struct OpenFoodFactsResponse: Codable {
    let count: Int
    let products: [OpenFoodFactsProduct]
}

struct OpenFoodFactsProduct: Codable {
    let product_name: String?
    let brands: String?
    let ingredients_text: String?
    let code: String?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    let proteins_100g: Double?
}
struct DabasArticle: Codable {
    let artikelbenamning: String?
    let varumarke: String?
    let forpackningsstorlek: String?
    let gtin: String?
    
    enum CodingKeys: String, CodingKey {
        case artikelbenamning = "Artikelbenamning"
        case varumarke = "Varumarke"
        case forpackningsstorlek = "Forpackningsstorlek"
        case gtin = "GTIN"
    }
}

struct OpenFoodFactsArticle: Codable {
    let artikelbenamning: String?
    let varumarke: String?
    let forpackningsstorlek: String?
    let gtin: String?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    let proteins_100g: Double?
    
    enum CodingKeys: String, CodingKey {
        case artikelbenamning = "product_name"
        case varumarke = "brands"
        case forpackningsstorlek = "ingredients_text"
        case gtin = "code"
        case carbohydrates_100g = "nutriments.carbohydrates_100g"
        case fat_100g = "nutriments.fat_100g"
        case proteins_100g = "nutriments.proteins_100g"
    }
}

struct Article: Codable {
    let artikelbenamning: String?
    let varumarke: String?
    let forpackningsstorlek: String?
    let gtin: String?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    let proteins_100g: Double?
    
    init(
        artikelbenamning: String?,
        varumarke: String?,
        forpackningsstorlek: String?,
        gtin: String?,
        carbohydrates_100g: Double?,
        fat_100g: Double?,
        proteins_100g: Double?
    ) {
        self.artikelbenamning = artikelbenamning
        self.varumarke = varumarke
        self.forpackningsstorlek = forpackningsstorlek
        self.gtin = gtin
        self.carbohydrates_100g = carbohydrates_100g
        self.fat_100g = fat_100g
        self.proteins_100g = proteins_100g
    }
    
    init(from product: OpenFoodFactsProduct) {
        self.init(
            artikelbenamning: product.product_name,
            varumarke: product.brands,
            forpackningsstorlek: nil,
            gtin: product.code,
            carbohydrates_100g: product.carbohydrates_100g,
            fat_100g: product.fat_100g,
            proteins_100g: product.proteins_100g
        )
    }
    
    init(from article: DabasArticle) {
        self.init(
            artikelbenamning: article.artikelbenamning,
            varumarke: article.varumarke,
            forpackningsstorlek: nil,
            gtin: article.gtin,
            carbohydrates_100g: nil,
            fat_100g: nil,
            proteins_100g: nil
        )
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
        detailsLabel.text = "\(article.varumarke ?? "")"
        gtin = article.gtin // Store GTIN
    }
}

// Extension to round Double to specified decimal places
extension Double {
    public func roundToDecimal(_ fractionDigits: Int) -> Double {
        let multiplier = pow(10.0, Double(fractionDigits))
        return (self * multiplier).rounded() / multiplier
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return index >= 0 && index < count ? self[index] : nil
    }
}

