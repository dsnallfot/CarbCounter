
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
        tableView.register(FoodItemTableViewCell.self, forCellReuseIdentifier: "FoodItemCell")
        fetchFoodItems()
        setupAddButton()
        setupNavigationBarTitle()
        setupSearchBar()
        setupSortSegmentedControl()
    }
    
    private func setupAddButton() {
        let addButton = UIBarButtonItem(image: UIImage(systemName: "plus.circle"), style: .plain, target: self, action: #selector(navigateToAddFoodItem))
        let exportButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportFoodItemsToCSV))
        let importButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importFoodItemsFromCSV))
        navigationItem.leftBarButtonItems = [exportButton, importButton]
        navigationItem.rightBarButtonItems = [addButton]
    }
    
    private func setupNavigationBarTitle() {
        // Set the title of the navigation bar
        title = "Food Items"
    }
    
    private func createToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
        
        toolbar.setItems([flexSpace, doneButton], animated: false)
        toolbar.isUserInteractionEnabled = true
        
        return toolbar
    }
    
    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "Search Food Items"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Disable predictive text and autocomplete
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
            textField.spellCheckingType = .no
            textField.inputAssistantItem.leadingBarButtonGroups = []
            textField.inputAssistantItem.trailingBarButtonGroups = []
            
            // Add "Done" button to the keyboard
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonTapped))
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "FoodItemCell", for: indexPath) as! FoodItemTableViewCell
        let foodItem = filteredFoodItems[indexPath.row]
        cell.configure(with: foodItem)
        return cell
    }
    
    // MARK: - Swipe Actions
    
    // For iOS 11 and later
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (action, view, completionHandler) in
            let foodItem = self.filteredFoodItems[indexPath.row]
            let alertController = UIAlertController(title: "Delete", message: "Do you want to delete \(foodItem.name ?? "this item")?", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(false) // Don't delete the item
            }
            let yesAction = UIAlertAction(title: "Yes", style: .destructive) { _ in
                self.deleteFoodItem(at: indexPath)
                completionHandler(true) //Delete the item
            }
            alertController.addAction(cancelAction)
            alertController.addAction(yesAction)
            self.present(alertController, animated: true, completion: nil)
        }
        let editAction = UIContextualAction(style: .normal, title: "Edit") { (action, view, completionHandler) in
            self.editFoodItem(at: indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemBlue
        
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
            print("Failed to delete food item: \(error)")
        }
    }
    
    // Edit Food Item
    private func editFoodItem(at indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self
            addFoodItemVC.foodItem = filteredFoodItems[indexPath.row]
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }
    
    // MARK: - UISearchBar Delegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if (searchText.isEmpty) {
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
    
    @objc private func exportFoodItemsToCSV() {
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        
        do {
            let foodItems = try context.fetch(fetchRequest)
            let csvData = createCSV(from: foodItems)
            saveCSV(data: csvData)
        } catch {
            print("Failed to fetch food items: \(error)")
        }
    }
    
    private func createCSV(from foodItems: [FoodItem]) -> String {
        var csvString = "id,name,carbohydrates,carbsPP,fat,fatPP,netCarbs,netFat,netProtein,perPiece,protein,proteinPP\n"
        
        for item in foodItems {
            let id = item.id?.uuidString ?? ""
            let name = item.name ?? ""
            let carbohydrates = item.carbohydrates
            let carbsPP = item.carbsPP
            let fat = item.fat
            let fatPP = item.fatPP
            let netCarbs = item.netCarbs
            let netFat = item.netFat
            let netProtein = item.netProtein
            let perPiece = item.perPiece
            let protein = item.protein
            let proteinPP = item.proteinPP
            
            csvString += "\(id),\(name),\(carbohydrates),\(carbsPP),\(fat),\(fatPP),\(netCarbs),\(netFat),\(netProtein),\(perPiece),\(protein),\(proteinPP)\n"
        }
        
        return csvString
    }
    
    private func saveCSV(data: String) {
        let fileName = "FoodItems.csv"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        do {
            try data.write(to: path!, atomically: true, encoding: String.Encoding.utf8)
            let activityViewController = UIActivityViewController(activityItems: [path!], applicationActivities: nil)
            present(activityViewController, animated: true, completion: nil)
        } catch {
            print("Failed to create file: \(error)")
        }
    }
    
    @objc private func importFoodItemsFromCSV() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    private func parseCSV(at url: URL) {
        do {
            let csvData = try String(contentsOf: url, encoding: .utf8)
            let rows = csvData.components(separatedBy: "\n").filter { !$0.isEmpty }
            let columns = rows[0].components(separatedBy: ";")

            guard columns.count == 12 else {
                print("CSV file does not have the correct format")
                showAlert(title: "Import Failed", message: "CSV file does not have the correct format")
                return
            }

            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            let context = appDelegate.persistentContainer.viewContext

            for row in rows[1...] {
                let values = row.components(separatedBy: ";")
                if values.count == 12 {
                    let foodItem = FoodItem(context: context)
                    foodItem.id = UUID(uuidString: values[0])
                    foodItem.name = values[1]
                    foodItem.carbohydrates = Double(values[2]) ?? 0.0
                    foodItem.carbsPP = Double(values[3]) ?? 0.0
                    foodItem.fat = Double(values[4]) ?? 0.0
                    foodItem.fatPP = Double(values[5]) ?? 0.0
                    foodItem.netCarbs = Double(values[6]) ?? 0.0
                    foodItem.netFat = Double(values[7]) ?? 0.0
                    foodItem.netProtein = Double(values[8]) ?? 0.0
                    foodItem.perPiece = values[9] == "true"
                    foodItem.protein = Double(values[10]) ?? 0.0
                    foodItem.proteinPP = Double(values[11]) ?? 0.0
                }
            }

            try context.save()
            fetchFoodItems()
            tableView.reloadData()
            showAlert(title: "Import Successful", message: "Food items have been successfully imported.")
        } catch {
            print("Failed to read CSV file: \(error)")
            showAlert(title: "Import Failed", message: "Failed to read CSV file: \(error)")
        }
    }

    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
}

extension FoodItemsListViewController: UIDocumentPickerDelegate {
func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
guard let url = urls.first else { return }
parseCSV(at: url)
}
}
