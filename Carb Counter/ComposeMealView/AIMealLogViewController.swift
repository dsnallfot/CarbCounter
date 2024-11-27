//
//  AIMealLogViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-25.
//

import UIKit
import CoreData

class AIMealLogViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    private var tableView: UITableView!
    private var searchBar: UISearchBar!
    private var meals: [AIMeal] = []
    private var filteredMeals: [AIMeal] = []
    
    var dataSharingVC: DataSharingViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "AI Analysslogg"
        updateBackgroundForCurrentMode()

        setupSearchBar()
        setupTableView()
        setupNavigationBar()
        fetchMeals()
        addRefreshControl()
        dataSharingVC = DataSharingViewController()
    }

    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.barTintColor = .clear
        searchBar.backgroundColor = .clear
        searchBar.backgroundImage = UIImage()
        searchBar.placeholder = "Sök måltid i loggen" // "Search meal"
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func updateBackgroundForCurrentMode() {
        // Remove any existing gradient views before updating
        view.subviews.filter { $0 is GradientView }.forEach { $0.removeFromSuperview() }
        
        // Update the background based on the current interface style
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .systemBackground
            // Create the gradient view for dark mode
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
        } else {
            // In light mode, set a solid background
            view.backgroundColor = .systemGray6
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackgroundForCurrentMode()
        }
    }


    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "mealCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func setupNavigationBar() {
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }

    private func fetchMeals() {
        let fetchRequest: NSFetchRequest<AIMeal> = AIMeal.fetchRequest()

        // Exclude meals marked as deleted
        fetchRequest.predicate = NSPredicate(format: "delete == NO OR delete == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "mealDate", ascending: false)]

        do {
            meals = try CoreDataStack.shared.context.fetch(fetchRequest)
            filteredMeals = meals
            tableView.reloadData()
        } catch {
            print("Failed to fetch AI meal log: \(error.localizedDescription)")
        }
    }
    
    private func addRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: NSLocalizedString("Uppdaterar måltidsloggen...", comment: "Message shown while updating meal history"))
        refreshControl.addTarget(self, action: #selector(refreshMealHistory), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    @objc private func refreshMealHistory() {
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else {
            tableView.refreshControl?.endRefreshing()
            return
        }
        
        // Call the desired function
        print("Data import triggered")
        Task {
            await dataSharingVC.importCSVFiles(specificFileName: "AIMealLog.csv")
            
            // End refreshing after completion
            await MainActor.run {
                tableView.refreshControl?.endRefreshing()
                fetchMeals() // Reload meal histories after the import
            }
        }
    }


    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredMeals.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "mealCell", for: indexPath)
        cell = UITableViewCell(style: .subtitle, reuseIdentifier: "mealCell")
        cell.backgroundColor = .clear
        cell.textLabel?.numberOfLines = 1
        cell.detailTextLabel?.numberOfLines = 1

        let meal = filteredMeals[indexPath.row]

        // Configure main text
        cell.textLabel?.text = meal.name ?? "Odefinierad måltid" // Default if name is nil

        // Configure detail text
        if let mealDate = meal.mealDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM HH:mm" // Example: 25 nov. 10:17
            let dateString = formatter.string(from: mealDate)

            let detailText = """
            \(dateString) | Kh \(Int(meal.totalCarbs))g | Fett \(Int(meal.totalFat))g | Prot \(Int(meal.totalProtein))g | Vikt \(Int(meal.totalAdjustedWeight))g
            """
            cell.detailTextLabel?.text = detailText
        }

        // Apply custom formatting
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        cell.detailTextLabel?.textColor = .gray
        
        // Custom selection color
        let customSelectionColor = UIView()
        customSelectionColor.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        cell.selectedBackgroundView = customSelectionColor

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Get the selected meal
        let selectedMeal = filteredMeals[indexPath.row]

        // Safely access attributes from the selected meal
        let totalCarbs = selectedMeal.totalCarbs
        let totalFat = selectedMeal.totalFat
        let totalProtein = selectedMeal.totalProtein
        let totalAdjustedWeight = selectedMeal.totalAdjustedWeight

        // Create and configure the AnalysisModalViewController
        let modalVC = AnalysisModalViewController()
        modalVC.gptCarbs = Int(totalCarbs)
        modalVC.gptFat = Int(totalFat)
        modalVC.gptProtein = Int(totalProtein)
        modalVC.gptTotalWeight = Int(totalAdjustedWeight)
        modalVC.gptName = selectedMeal.name ?? "Analyserad måltid"
        modalVC.savedResponse = selectedMeal.response ?? ""
        modalVC.fromAnalysisLog = true // Set the flag to true

        // Wrap in UINavigationController
        let navController = UINavigationController(rootViewController: modalVC)
        navController.modalPresentationStyle = .pageSheet

        // Configure sheet presentation
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }

        // Present the modal view controller
        present(navController, animated: true)

        // Deselect the row
        tableView.deselectRow(at: indexPath, animated: true)
    }



    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] (action, view, completionHandler) in
            self?.confirmDeleteMeal(at: indexPath)
            completionHandler(true)
        }
        deleteAction.image = UIImage(systemName: "trash.fill")
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    private func confirmDeleteMeal(at indexPath: IndexPath) {
        let meal = filteredMeals[indexPath.row]

        let deleteAlert = UIAlertController(
            title: "Radera från måltidslogg", // "Delete Meal"
            message: "Bekräfta att du vill radera måltiden: '\(meal.name ?? "Odefinierad måltid")'.", // Confirm delete message
            preferredStyle: .actionSheet
        )
        let deleteAction = UIAlertAction(title: "Radera", style: .destructive) { [weak self] _ in
            Task {
                await self?.deleteMeal(at: indexPath)
            }
        }
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)

        deleteAlert.addAction(deleteAction)
        deleteAlert.addAction(cancelAction)
        present(deleteAlert, animated: true)
    }
    private func deleteMeal(at indexPath: IndexPath) async {
        guard let dataSharingVC = dataSharingVC else { return }

        // Step 1: Import the AIMealLog CSV file before deletion
        print("Starting data import for AI Meals before deletion")
        await dataSharingVC.importCSVFiles(specificFileName: "AIMealLog.csv")
        print("Data import complete for AI Meals")

        let meal = filteredMeals[indexPath.row]

        // Step 2: Mark the meal as deleted and update lastEdited
        meal.delete = true
        meal.lastEdited = Date() // Update the last edited timestamp

        // Step 3: Export the updated list of AI meals
        print(NSLocalizedString("AI meals export triggered", comment: "Message when AI meals export is triggered"))
        await dataSharingVC.exportAIMealLogToCSV()

        // Step 4: Save the updated context
        CoreDataStack.shared.saveContext()

        // Step 5: Update the UI by removing the item from the visible list
        filteredMeals.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredMeals = meals
        } else {
            filteredMeals = meals.filter {
                $0.name?.lowercased().contains(searchText.lowercased()) ?? false
            }
        }
        tableView.reloadData()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        filteredMeals = meals
        tableView.reloadData()
        searchBar.resignFirstResponder()
    }
}
