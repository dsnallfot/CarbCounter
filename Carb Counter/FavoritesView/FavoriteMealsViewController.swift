import UIKit
import CoreData

class FavoriteMealsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, FavoriteMealDetailViewControllerDelegate {
    
    var tableView: UITableView!
    var searchBar: UISearchBar!
    var favoriteMeals: [FavoriteMeals] = []
    var filteredFavoriteMeals: [FavoriteMeals] = []
    
    var dataSharingVC: DataSharingViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Välj en favoritmåltid"
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
        backButton.title = "Tillbaka"
        navigationItem.backBarButtonItem = backButton
        
        let cancelButton = UIBarButtonItem(title: "Avbryt", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = cancelButton
        
        setupSearchBar()
        setupTableView()
        setupNavigationBar()
        fetchFavoriteMeals()
        
        dataSharingVC = DataSharingViewController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchFavoriteMeals()
    }
    
    func favoriteMealDetailViewControllerDidSave(_ controller: FavoriteMealDetailViewController) {
        fetchFavoriteMeals()
    }
    
    @objc private func cancelButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "Sök favoritmåltid"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.barTintColor = .clear//.systemBackground
        searchBar.backgroundColor = .clear//.systemBackground
        searchBar.backgroundImage = UIImage() // Make background clear
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
        tableView.backgroundColor = .clear//.systemBackground
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
            appearance.backgroundColor = .clear//.systemBackground
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        } else {
            navigationController?.navigationBar.barTintColor = .clear//.systemBackground
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.label]
        }
    }
    
    private func fetchFavoriteMeals() {
        let fetchRequest: NSFetchRequest<FavoriteMeals> = FavoriteMeals.fetchRequest()
        
        do {
            favoriteMeals = try CoreDataStack.shared.context.fetch(fetchRequest)
            filteredFavoriteMeals = favoriteMeals
            tableView.reloadData()
        } catch {
            print("Failed to fetch favorite meals: \(error)")
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredFavoriteMeals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        cell.backgroundColor = .clear // Set cell background to clear
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
        print("Selected favorite meal: \(favoriteMeal.name ?? "Unknown")")
        
        if let composeMealVC = navigationController?.viewControllers.first(where: { $0 is ComposeMealViewController }) as? ComposeMealViewController {
            composeMealVC.populateWithFavoriteMeal(favoriteMeal)
            navigationController?.popViewController(animated: true)
            print("Navigated back to ComposeMealViewController and populated with favorite meal.")
        } else {
            print("ComposeMealViewController not found in navigation stack.")
        }
    }
    
    // Implement swipe actions
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: "Ändra") { [weak self] (action, view, completionHandler) in
            self?.editFavoriteMeal(at: indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemBlue
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Radera") { [weak self] (action, view, completionHandler) in
            self?.confirmDeleteFavoriteMeal(at: indexPath)
            completionHandler(true)
        }
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        return configuration
    }
    
    private func editFavoriteMeal(at indexPath: IndexPath) {
        let favoriteMeal = filteredFavoriteMeals[indexPath.row]
        let detailVC = FavoriteMealDetailViewController()
        detailVC.favoriteMeal = favoriteMeal
        detailVC.delegate = self
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    private func confirmDeleteFavoriteMeal(at indexPath: IndexPath) {
        let favoriteMeal = filteredFavoriteMeals[indexPath.row]
        
        let deleteAlert = UIAlertController(title: "Radera favoritmåltid", message: "Bekräfta att du vill radera: '\"\(favoriteMeal.name ?? "")\"'?", preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: "Radera", style: .destructive) { [weak self] _ in
            self?.deleteFavoriteMeal(at: indexPath)
        }
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        
        deleteAlert.addAction(deleteAction)
        deleteAlert.addAction(cancelAction)
        
        present(deleteAlert, animated: true, completion: nil)
    }
    
    private func deleteFavoriteMeal(at indexPath: IndexPath) {
        let favoriteMeal = filteredFavoriteMeals[indexPath.row]
        CoreDataStack.shared.context.delete(favoriteMeal)
        CoreDataStack.shared.saveContext()
        
        favoriteMeals.removeAll { $0 == favoriteMeal }
        filteredFavoriteMeals.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        
        guard let dataSharingVC = dataSharingVC else { return }
        dataSharingVC.exportFavoriteMealsToCSV()
        print("Favorite meals export triggered")
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
}
