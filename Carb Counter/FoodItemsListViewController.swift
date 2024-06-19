//
//  FoodItemsListViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-17.
//

import UIKit
import CoreData

class FoodItemsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, AddFoodItemDelegate {

    @IBOutlet weak var tableView: UITableView!
    var foodItems: [FoodItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        fetchFoodItems()
        setupAddButton()
    }

    private func setupAddButton() {
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(navigateToAddFoodItem))
        navigationItem.rightBarButtonItem = addButton
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
            tableView.reloadData()
        } catch {
            print("Failed to fetch food items: \(error)")
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return foodItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FoodItemCell", for: indexPath)
        let foodItem = foodItems[indexPath.row]
        cell.textLabel?.text = foodItem.name
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
}
