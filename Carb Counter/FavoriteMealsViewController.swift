//
//  FavoriteMealsViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-21.
//

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
        let favoriteMeals = favoriteMeals[indexPath.row]
        cell.textLabel?.text = favoriteMeals.name
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let favoriteMeals = favoriteMeals[indexPath.row]
        // Handle selection of a favorite meal
        // You can navigate to a detail view or use the meal data as needed
    }
}
