//
//  FoodItemsListViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-17.
//

import UIKit
import CoreData

class FoodItemsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, AddFoodItemDelegate {

    @IBOutlet weak var tableView: UITableView!
    var foodItems: [FoodItem] = []
    var filteredFoodItems: [FoodItem] = []
    var sortOption: SortOption = .nameAsc
    var segmentedControl: UISegmentedControl!
    var searchBar: UISearchBar!

    enum SortOption {
        case nameAsc, nameDesc, carbsAsc, carbsDesc, fatAsc, fatDesc, proteinAsc, proteinDesc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        fetchFoodItems()
        setupAddButton()
        setupNavigationBarTitle()
        setupSearchBar()
        setupSortSegmentedControl()
    }

    private func setupAddButton() {
        let addButton = UIBarButtonItem(image: UIImage(systemName: "plus.circle"), style: .plain, target: self, action: #selector(navigateToAddFoodItem))
        navigationItem.rightBarButtonItem = addButton
    }

    private func setupNavigationBarTitle() {
        // Set the title of the navigation bar
        title = "Food Items"
    }

    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "Search Food Items"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(searchBar)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func setupSortSegmentedControl() {
        let items = ["Name", "Carbs", "Fat", "Protein"]
        segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(sortSegmentChanged(_:)), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(segmentedControl)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func sortSegmentChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            sortOption = sortOption == .nameAsc ? .nameDesc : .nameAsc
        case 1:
            sortOption = sortOption == .carbsDesc ? .carbsAsc : .carbsDesc
        case 2:
            sortOption = sortOption == .fatDesc ? .fatAsc : .fatDesc
        case 3:
            sortOption = sortOption == .proteinDesc ? .proteinAsc : .proteinDesc
        default:
            break
        }
        sortFoodItems()
    }

    @objc private func navigateToAddFoodItem() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            navigationController?.pushViewController(addFoodItemVC, animated: true)
            print("Navigated to AddFoodItemViewController")
        } else {
            print("Failed to instantiate AddFoodItemViewController")
        }
    }

    func didAddFoodItem() {
        fetchFoodItems()
    }

    func fetchFoodItems() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        do {
            foodItems = try context.fetch(fetchRequest)
            filteredFoodItems = foodItems
            sortFoodItems()
        } catch {
            print("Failed to fetch food items: \(error)")
        }
    }

    func sortFoodItems() {
        switch sortOption {
        case .nameAsc:
            filteredFoodItems.sort { $0.name ?? "" < $1.name ?? "" }
        case .nameDesc:
            filteredFoodItems.sort { $0.name ?? "" > $1.name ?? "" }
        case .carbsAsc:
            filteredFoodItems.sort { $0.carbohydrates < $1.carbohydrates }
        case .carbsDesc:
            filteredFoodItems.sort { $0.carbohydrates > $1.carbohydrates }
        case .fatAsc:
            filteredFoodItems.sort { $0.fat < $1.fat }
        case .fatDesc:
            filteredFoodItems.sort { $0.fat > $1.fat }
        case .proteinAsc:
            filteredFoodItems.sort { $0.protein < $1.protein }
        case .proteinDesc:
            filteredFoodItems.sort { $0.protein > $1.protein }
        }
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredFoodItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FoodItemCell", for: indexPath)
        let foodItem = filteredFoodItems[indexPath.row]
        
        let name = foodItem.name ?? ""
        let carbs = String(format: "%.0f", foodItem.carbohydrates)
        let fat = String(format: "%.0f", foodItem.fat)
        let protein = String(format: "%.0f", foodItem.protein)
        
        let formattedText = "\(name) • Kh: \(carbs)g F: \(fat)g P: \(protein)g"
        cell.textLabel?.text = formattedText
        
        return cell
    }

    // MARK: - Swipe Actions

    // For iOS 11 and later
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (action, view, completionHandler) in
            self.deleteFoodItem(at: indexPath)
            completionHandler(true)
        }
        let editAction = UIContextualAction(style: .normal, title: "Edit") { (action, view, completionHandler) in
            self.editFoodItem(at: indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = .blue

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        return configuration
    }

    // For iOS 10 and earlier
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteFoodItem(at: indexPath)
        }
    }

    // Delete Food Item
    private func deleteFoodItem(at indexPath: IndexPath) {
        let foodItem = foodItems[indexPath.row]
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        context.delete(foodItem)
        do {
            try context.save()
            foodItems.remove(at: indexPath.row)
            filteredFoodItems.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        } catch {
            print("Failed to delete food item: \(error)")
        }
    }

    // Edit Food Item
    private func editFoodItem(at indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            addFoodItemVC.foodItem = foodItems[indexPath.row]
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }
    // MARK: - UISearchBar Delegate

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            if searchText.isEmpty {
                filteredFoodItems = foodItems
            } else {
                filteredFoodItems = foodItems.filter { $0.name?.lowercased().contains(searchText.lowercased()) ?? false }
            }
            sortFoodItems()
            }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        filteredFoodItems = foodItems
        sortFoodItems()
        searchBar.resignFirstResponder()
    }
}
