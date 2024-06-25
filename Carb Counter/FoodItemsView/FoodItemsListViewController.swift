//
//  FoodItemsListViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-17.
//
import UIKit
import CoreData
import UniformTypeIdentifiers

class FoodItemsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, AddFoodItemDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    var foodItems: [FoodItem] = []
    var filteredFoodItems: [FoodItem] = []
    var sortOption: SortOption = .name
    var segmentedControl: UISegmentedControl!
    var searchBar: UISearchBar!
    
    enum SortOption {
        case name, perPiece, count
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FoodItemTableViewCell.self, forCellReuseIdentifier: "FoodItemCell")
        fetchFoodItems()
        setupAddButton()
        setupClearButton()
        setupNavigationBarTitle()
        setupSearchBar()
        setupSortSegmentedControl()
    }
    
    private func setupAddButton() {
        let addButton = UIBarButtonItem(image: UIImage(systemName: "plus.circle"), style: .plain, target: self, action: #selector(navigateToAddFoodItem))
        navigationItem.rightBarButtonItems = [addButton]
    }
    
    private func setupClearButton() {
        let clearButton = UIBarButtonItem(title: "Rensa", style: .plain, target: self, action: #selector(clearButtonTapped))
        clearButton.tintColor = .red
        navigationItem.leftBarButtonItem = clearButton
    }
    
    private func setupNavigationBarTitle() {
        title = "Livsmedel"
    }
    
    private func createToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
        
        toolbar.setItems([flexSpace, doneButton], animated: false)
        toolbar.isUserInteractionEnabled = true
        
        return toolbar
    }
    
    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "Sök livsmedel"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
            textField.spellCheckingType = .no
            textField.inputAssistantItem.leadingBarButtonGroups = []
            textField.inputAssistantItem.trailingBarButtonGroups = []
            
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
            toolbar.setItems([flexSpace, doneButton], animated: false)
            textField.inputAccessoryView = toolbar
        }
        
        view.addSubview(searchBar)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    @objc private func doneButtonTapped() {
        searchBar.resignFirstResponder()
    }
    
    private func setupSortSegmentedControl() {
        let items = ["Namn A-Ö", "Per Styck", "Populära"]
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
            sortOption = .name
        case 1:
            sortOption = .perPiece
        case 2:
            sortOption = .count
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
        case .name:
            filteredFoodItems.sort { $0.name ?? "" < $1.name ?? "" }
        case .perPiece:
            filteredFoodItems.sort { $0.perPiece && !$1.perPiece }
        case .count:
            filteredFoodItems.sort { $0.count > $1.count }
        }
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredFoodItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FoodItemCell", for: indexPath) as! FoodItemTableViewCell
        let foodItem = filteredFoodItems[indexPath.row]
        cell.configure(with: foodItem)
        return cell
    }
    
    // MARK: - Swipe Actions
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Radera") { (action, view, completionHandler) in
            let foodItem = self.filteredFoodItems[indexPath.row]
            let alertController = UIAlertController(title: "Radera", message: "Vill du radera \(foodItem.name ?? "detta livsmedel")?", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel) { _ in
                completionHandler(false)
            }
            let yesAction = UIAlertAction(title: "Ja", style: .destructive) { _ in
                self.deleteFoodItem(at: indexPath)
                completionHandler(true)
            }
            alertController.addAction(cancelAction)
            alertController.addAction(yesAction)
            self.present(alertController, animated: true, completion: nil)
        }
        let editAction = UIContextualAction(style: .normal, title: "Ändra") { (action, view, completionHandler) in
            self.editFoodItem(at: indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemBlue
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        return configuration
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteFoodItem(at: indexPath)
        }
    }
    
    private func deleteFoodItem(at indexPath: IndexPath) {
        let foodItem = filteredFoodItems[indexPath.row]
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        context.delete(foodItem)
        do {
            try context.save()
            foodItems.remove(at: indexPath.row)
            filteredFoodItems.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        } catch {
            print("Failed to delete food item: (error)")
        }
    }
    private func editFoodItem(at indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            addFoodItemVC.foodItem = filteredFoodItems[indexPath.row]
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }
    
    @objc private func clearButtonTapped() {
        let firstAlertController = UIAlertController(title: "Rensa allt", message: "Vill du radera alla livsmedel från databasen?", preferredStyle: .alert)
        let continueAction = UIAlertAction(title: "Fortsätt", style: .destructive) { _ in
            self.showSecondClearAlert()
        }
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        
        firstAlertController.addAction(continueAction)
        firstAlertController.addAction(cancelAction)
        
        present(firstAlertController, animated: true, completion: nil)
    }
    
    private func showSecondClearAlert() {
        let secondAlertController = UIAlertController(title: "Rensa allt", message: "Är du helt säker? Åtgärden går inte att ångra.", preferredStyle: .alert)
        let clearAction = UIAlertAction(title: "Rensa", style: .destructive) { _ in
            self.clearAllFoodItems()
        }
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        
        secondAlertController.addAction(clearAction)
        secondAlertController.addAction(cancelAction)
        
        present(secondAlertController, animated: true, completion: nil)
    }
    
    private func clearAllFoodItems() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
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