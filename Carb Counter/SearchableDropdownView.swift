//
//  SearchableDropdownView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-19.
//

import UIKit

class SearchableDropdownView: UIView, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    var onSelectItem: ((FoodItem) -> Void)?
    var foodItems: [FoodItem] = []
    var filteredFoodItems: [FoodItem] = []

    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search Food Items"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.barTintColor = .systemGray
        searchBar.backgroundImage = UIImage() // Removes the default background image
        
        // Customize the text field inside the search bar
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.backgroundColor = .systemGray4
            textField.tintColor = .label // Set the cursor color
        }
        
        return searchBar
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        addSubview(searchBar)
        addSubview(tableView)

        searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: trailingAnchor),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func updateFoodItems(_ items: [FoodItem]) {
        self.foodItems = items.sorted { ($0.name ?? "") < ($1.name ?? "") }
        self.filteredFoodItems = self.foodItems
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredFoodItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.text = filteredFoodItems[indexPath.row].name
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelectItem?(filteredFoodItems[indexPath.row])
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredFoodItems = foodItems
        } else {
            filteredFoodItems = foodItems.filter { $0.name?.lowercased().contains(searchText.lowercased()) ?? false }
        }
        tableView.reloadData()
    }
}
