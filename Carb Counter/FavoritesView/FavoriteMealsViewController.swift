import UIKit
import CoreData

class FavoriteMealsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, FavoriteMealDetailViewControllerDelegate {
    
    var tableView: UITableView!
    var searchBar: UISearchBar!
    var clearButton: UIBarButtonItem!
    var favoriteMeals: [FavoriteMeals] = []
    var filteredFavoriteMeals: [FavoriteMeals] = []
    
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
        
        setupSearchBar()
        setupTableView()
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
        view.addSubview(searchBar)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90),
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
        CoreDataStack.shared.context.delete(favoriteMeal)
        CoreDataStack.shared.saveContext()
        
        favoriteMeals.removeAll { $0 == favoriteMeal }
        filteredFavoriteMeals.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        
        guard let dataSharingVC = dataSharingVC else { return }
        print(NSLocalizedString("Favorite meals export triggered", comment: "Message when favorite meals export is triggered"))
        await dataSharingVC.exportFavoriteMealsToCSV()
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
