import UIKit
import CoreData

class FavoriteMealsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, FavoriteMealDetailViewControllerDelegate {
    
    var tableView: UITableView!
    var searchBar: UISearchBar!
    var clearButton: UIBarButtonItem!
    var favoriteMeals: [FavoriteMeals] = []
    var filteredFavoriteMeals: [FavoriteMeals] = []
    private var tableBottomConstraint: NSLayoutConstraint?
    
    var dataSharingVC: DataSharingViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Välj en favoritmåltid", comment: "Select a favorite meal")
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
        
        // Set the back button title for the next view controller
        let backButton = UIBarButtonItem()
        backButton.title = NSLocalizedString("Tillbaka", comment: "Back")
        navigationItem.backBarButtonItem = backButton
        
        // Setup Clear button
        clearButton = UIBarButtonItem(title: NSLocalizedString("Rensa", comment: "Rensa"), style: .plain, target: self, action: #selector(clearButtonTapped))
        clearButton.tintColor = .red
        
        // Listen for changes to allowDataClearing setting
        NotificationCenter.default.addObserver(self, selector: #selector(updateButtonVisibility), name: Notification.Name("AllowDataClearingChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        setupSearchBar()
        setupTableView()
        addRefreshControl()
        setupNavigationBar()
        fetchFavoriteMeals()
        
        dataSharingVC = DataSharingViewController()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func updateButtonVisibility() {
        if UserDefaultsRepository.allowDataClearing {
            navigationItem.rightBarButtonItems = [clearButton]
        } else {
            navigationItem.rightBarButtonItems = nil // Remove the clear button if not allowed
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchFavoriteMeals()
        updateButtonVisibility()
    }
    
    @objc private func keyboardWillShow(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        
        let keyboardHeight = keyboardFrame.height
        tableBottomConstraint?.constant = -keyboardHeight // Move the table up by the keyboard height
        
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded() // Animate the layout change
        }
    }

    @objc private func keyboardWillHide(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        
        tableBottomConstraint?.constant = -90 // Reset the bottom constraint
        
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded() // Animate the layout change
        }
    }
    
    func favoriteMealDetailViewControllerDidSave(_ controller: FavoriteMealDetailViewController) {
        fetchFavoriteMeals()
    }
    
    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = NSLocalizedString("Sök favoritmåltid", comment: "Search favorite meal")
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.barTintColor = .clear
        searchBar.backgroundColor = .clear
        searchBar.backgroundImage = UIImage()
        
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .sentences
            textField.spellCheckingType = .no
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
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    @objc private func cancelButtonTapped() {
        // Dismiss the keyboard
        searchBar.resignFirstResponder()
    }

    @objc private func doneButtonTapped() {
        // Dismiss the keyboard
        searchBar.resignFirstResponder()
    }
    
    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        
        tableBottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            //tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90),
            tableBottomConstraint!,
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .clear
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        } else {
            navigationController?.navigationBar.barTintColor = .clear
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.label]
        }
        
        updateButtonVisibility()
    }
    
    private func fetchFavoriteMeals() {
        let fetchRequest: NSFetchRequest<FavoriteMeals> = FavoriteMeals.fetchRequest()
        
        // Add a predicate to filter out items where the delete flag is true
        fetchRequest.predicate = NSPredicate(format: "delete == NO OR delete == nil")
        
        do {
            let favoriteMeals = try CoreDataStack.shared.context.fetch(fetchRequest)
            
            // Sort favorite meals alphabetically by name
            let sortedFavoriteMeals = favoriteMeals.sorted { ($0.name ?? "") < ($1.name ?? "") }
            
            DispatchQueue.main.async {
                self.favoriteMeals = sortedFavoriteMeals
                self.filteredFavoriteMeals = sortedFavoriteMeals
                self.tableView.reloadData()
            }
        } catch {
            DispatchQueue.main.async {
                print(NSLocalizedString("Failed to fetch favorite meals: %@", comment: "Error message for fetching favorite meals"))
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredFavoriteMeals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        cell.backgroundColor = .clear
        cell.textLabel?.numberOfLines = 2
        cell.textLabel?.lineBreakMode = .byWordWrapping
        cell.detailTextLabel?.numberOfLines = 2
        cell.detailTextLabel?.lineBreakMode = .byWordWrapping
        
        let favoriteMeal = filteredFavoriteMeals[indexPath.row]
        cell.textLabel?.text = favoriteMeal.name
        
        let items = getItems(from: favoriteMeal)
        let itemNames = items.compactMap { $0["name"] as? String }
        cell.detailTextLabel?.text = itemNames.joined(separator: " • ")
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        cell.detailTextLabel?.textColor = .gray
        
        return cell
    }
    
    private func getItems(from favoriteMeal: FavoriteMeals) -> [[String: Any]] {
        if let jsonString = favoriteMeal.items as? String,
           let jsonData = jsonString.data(using: .utf8),
           let items = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] {
            return items
        }
        return []
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let favoriteMeal = filteredFavoriteMeals[indexPath.row]
        print("Selected favorite meal: \(favoriteMeal.name ?? NSLocalizedString("Unknown", comment: "Unknown"))")
        
        if let composeMealVC = navigationController?.viewControllers.first(where: { $0 is ComposeMealViewController }) as? ComposeMealViewController {
            composeMealVC.checkAndHandleExistingMeal(replacementAction: {
                composeMealVC.addFavoriteMeal(favoriteMeal)
            }, additionAction: {
                composeMealVC.addFavoriteMeal(favoriteMeal)
            }, completion: {
                self.navigationController?.popViewController(animated: true)
            })
        } else {
            print(NSLocalizedString("ComposeMealViewController not found in navigation stack.", comment: "Error message when ComposeMealViewController is not found"))
        }
    }
    
    private func addRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: NSLocalizedString("Uppdaterar favoritlistan...", comment: "Message shown while updating favorites"))
        refreshControl.addTarget(self, action: #selector(refreshFavorites), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    @objc private func refreshFavorites() {
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else {
            tableView.refreshControl?.endRefreshing()
            return
        }
        
        // Call the desired function
        print("Data import triggered")
        Task {
            await dataSharingVC.importCSVFiles(specificFileName: "FavoriteMeals.csv")
            
            // End refreshing after completion
            await MainActor.run {
                tableView.refreshControl?.endRefreshing()
                fetchFavoriteMeals()
            }
        }
    }
    
    // Implement swipe actions
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: nil) { [weak self] (action, view, completionHandler) in
            self?.editFavoriteMeal(at: indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemBlue
        editAction.image = UIImage(systemName: "square.and.pencil")
        
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] (action, view, completionHandler) in
            self?.confirmDeleteFavoriteMeal(at: indexPath)
            completionHandler(true)
        }
        deleteAction.image = UIImage(systemName: "trash.fill")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        return configuration
    }

    private func editFavoriteMeal(at indexPath: IndexPath) {
        let favoriteMeal = filteredFavoriteMeals[indexPath.row]
        let detailVC = FavoriteMealDetailViewController()
        detailVC.favoriteMeal = favoriteMeal
        detailVC.delegate = self
        let navController = UINavigationController(rootViewController: detailVC)
        navController.modalPresentationStyle = .pageSheet
        
        present(navController, animated: true, completion: nil)
    }

    private func confirmDeleteFavoriteMeal(at indexPath: IndexPath) {
        let favoriteMeal = filteredFavoriteMeals[indexPath.row]
        
        let deleteAlert = UIAlertController(
            title: NSLocalizedString("Radera favoritmåltid", comment: "Delete favorite meal"),
            message: String(format: NSLocalizedString("Bekräfta att du vill radera: '%@'?", comment: "Confirm that you want to delete"), favoriteMeal.name ?? ""),
            preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: NSLocalizedString("Radera", comment: "Delete"), style: .destructive) { [weak self] _ in
            Task {
                await self?.deleteFavoriteMeal(at: indexPath)
            }
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel"), style: .cancel, handler: nil)
        
        deleteAlert.addAction(deleteAction)
        deleteAlert.addAction(cancelAction)
        
        present(deleteAlert, animated: true, completion: nil)
    }

    private func deleteFavoriteMeal(at indexPath: IndexPath) async {
        let favoriteMeal = filteredFavoriteMeals[indexPath.row]
        
        // Step 1: Set the delete flag to true and update lastEdited
        favoriteMeal.delete = true
        favoriteMeal.lastEdited = Date() // Update lastEdited date to current date

        // Step 2: Export the updated list of favorite meals
        guard let dataSharingVC = dataSharingVC else { return }
        print(NSLocalizedString("Favorite meals export triggered", comment: "Message when favorite meals export is triggered"))
        await dataSharingVC.exportFavoriteMealsToCSV()

        // Step 3: Save the updated context with the delete flag set to true
        CoreDataStack.shared.saveContext()

        // Step 4: Update the UI by removing the item from the visible list
        filteredFavoriteMeals.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredFavoriteMeals = favoriteMeals
        } else {
            filteredFavoriteMeals = favoriteMeals.filter { $0.name?.lowercased().contains(searchText.lowercased()) ?? false }
        }
        tableView.reloadData()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        filteredFavoriteMeals = favoriteMeals
        tableView.reloadData()
        searchBar.resignFirstResponder()
    }
    
    @objc private func clearButtonTapped() {
        let alertController = UIAlertController(
            title: NSLocalizedString("Rensa", comment: "Rensa"),
            message: NSLocalizedString("Är du säker på att du vill radera alla favoriter?", comment: "Är du säker på att du vill radera alla favoriter?"),
            preferredStyle: .actionSheet
        )

        let yesAction = UIAlertAction(title: NSLocalizedString("Ja", comment: "Ja"), style: .destructive) { [weak self] _ in
            // Clear all favorites
            CoreDataHelper.shared.clearAllFavorites()
            
            // Refresh the table view
            self?.fetchFavoriteMeals()

            // Export favorite meals to CSV
            guard let dataSharingVC = self?.dataSharingVC else { return }
            print(NSLocalizedString("Favorite meals export triggered", comment: "Favorite meals export triggered"))
            
            Task {
                await dataSharingVC.exportFavoriteMealsToCSV()
            }
        }

        let noAction = UIAlertAction(title: NSLocalizedString("Nej", comment: "Nej"), style: .cancel, handler: nil)

        alertController.addAction(yesAction)
        alertController.addAction(noAction)

        present(alertController, animated: true, completion: nil)
    }
}
