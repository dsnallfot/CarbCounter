//
//  MealHistoryViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-24.
//

import UIKit
import CoreData

class MealHistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var tableView: UITableView!
    var mealHistories: [MealHistory] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Måltidshistorik"
        view.backgroundColor = .systemBackground
        setupTableView()
        fetchMealHistories()
        
        // Add Cancel button to the navigation bar
        let cancelButton = UIBarButtonItem(title: "Avbryt", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = cancelButton
    }
    
    @objc private func cancelButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MealHistoryCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func fetchMealHistories() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<MealHistory>(entityName: "MealHistory")
        let sortDescriptor = NSSortDescriptor(key: "mealDate", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            mealHistories = try context.fetch(fetchRequest)
            tableView.reloadData()
        } catch {
            print("Failed to fetch meal histories: \(error)")
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mealHistories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "MealHistoryCell")
        let mealHistory = mealHistories[indexPath.row]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let mealDateStr = dateFormatter.string(from: mealHistory.mealDate ?? Date())
        
        cell.textLabel?.text = mealDateStr
        
        var detailText = ""
        if mealHistory.totalNetCarbs > 0 {
            detailText += "Kolhydrater: \(String(format: "%.0f", mealHistory.totalNetCarbs)) g"
        }
        if mealHistory.totalNetFat > 0 {
            detailText += detailText.isEmpty ? "" : " • "
            detailText += "Fett: \(String(format: "%.0f", mealHistory.totalNetFat)) g"
        }
        if mealHistory.totalNetProtein > 0 {
            detailText += detailText.isEmpty ? "" : " • "
            detailText += "Protein: \(String(format: "%.0f", mealHistory.totalNetProtein)) g"
        }
        cell.detailTextLabel?.text = detailText
        cell.detailTextLabel?.textColor = .gray
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let mealHistory = mealHistories[indexPath.row]
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            let context = appDelegate.persistentContainer.viewContext
            context.delete(mealHistory)
            
            do {
                try context.save()
                mealHistories.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            } catch {
                print("Failed to delete meal history: \(error)")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mealHistory = mealHistories[indexPath.row]
        let detailVC = MealHistoryDetailViewController()
        detailVC.mealHistory = mealHistory
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
