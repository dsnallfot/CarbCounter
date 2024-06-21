import UIKit
import CoreData

class FavoriteMealsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var tableView: UITableView!
    var favoriteMeals: [FavoriteMeals] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Favorite Meals"
        
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        fetchFavoriteMeals()
    }
    
    private func fetchFavoriteMeals() {
        let fetchRequest: NSFetchRequest<FavoriteMeals> = FavoriteMeals.fetchRequest()
        
        do {
            favoriteMeals = try CoreDataStack.shared.context.fetch(fetchRequest)
            tableView.reloadData()
        } catch {
            print("Failed to fetch favorite meals: \(error)")
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return favoriteMeals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        let favoriteMeal = favoriteMeals[indexPath.row]
        cell.textLabel?.text = favoriteMeal.name
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let favoriteMeal = favoriteMeals[indexPath.row]
        if let composeMealVC = navigationController?.viewControllers.first(where: { $0 is ComposeMealViewController }) as? ComposeMealViewController {
            composeMealVC.populateWithFavoriteMeal(favoriteMeal)
            navigationController?.popViewController(animated: true)
        }
    }
    
    // Implement swipe actions
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Edit action
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] (action, view, completionHandler) in
            self?.editFavoriteMeal(at: indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemBlue
        
        // Delete action
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completionHandler) in
            self?.confirmDeleteFavoriteMeal(at: indexPath)
            completionHandler(true)
        }
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        return configuration
    }
    
    private func editFavoriteMeal(at indexPath: IndexPath) {
        let favoriteMeal = favoriteMeals[indexPath.row]
        let detailVC = FavoriteMealDetailViewController()
        detailVC.favoriteMeal = favoriteMeal
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    private func confirmDeleteFavoriteMeal(at indexPath: IndexPath) {
        let favoriteMeal = favoriteMeals[indexPath.row]
        
        let deleteAlert = UIAlertController(title: "Delete Favorite Meal", message: "Do you want to delete \"\(favoriteMeal.name ?? "")\"?", preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
            self?.deleteFavoriteMeal(at: indexPath)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        deleteAlert.addAction(deleteAction)
        deleteAlert.addAction(cancelAction)
        
        present(deleteAlert, animated: true, completion: nil)
    }
    
    private func deleteFavoriteMeal(at indexPath: IndexPath) {
        let favoriteMeal = favoriteMeals[indexPath.row]
        CoreDataStack.shared.context.delete(favoriteMeal)
        CoreDataStack.shared.saveContext()
        
        favoriteMeals.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}
