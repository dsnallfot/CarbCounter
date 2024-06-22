import UIKit
import CoreData

class FavoriteMealsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    var tableView: UITableView!
    var searchBar: UISearchBar!
    var favoriteMeals: [FavoriteMeals] = []
    var filteredFavoriteMeals: [FavoriteMeals] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Favoritmåltider"
        
        setupSearchBar()
        setupTableView()
        fetchFavoriteMeals()
    }
    
    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "Sök favoritmåltid"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
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
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        let favoriteMeal = filteredFavoriteMeals[indexPath.row]
        cell.textLabel?.text = favoriteMeal.name
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let favoriteMeal = filteredFavoriteMeals[indexPath.row]
        if let composeMealVC = navigationController?.viewControllers.first(where: { $0 is ComposeMealViewController }) as? ComposeMealViewController {
            composeMealVC.populateWithFavoriteMeal(favoriteMeal)
            navigationController?.popViewController(animated: true)
        }
    }
    
    // Implement swipe actions
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Edit action
        let editAction = UIContextualAction(style: .normal, title: "Ändra") { [weak self] (action, view, completionHandler) in
            self?.editFavoriteMeal(at: indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemBlue
        
        // Delete action
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
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    private func confirmDeleteFavoriteMeal(at indexPath: IndexPath) {
        let favoriteMeal = filteredFavoriteMeals[indexPath.row]
        
        let deleteAlert = UIAlertController(title: "Radera favoritemåltid", message: "Vill du radera \"\(favoriteMeal.name ?? "")\"?", preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: "Ja", style: .destructive) { [weak self] _ in
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
