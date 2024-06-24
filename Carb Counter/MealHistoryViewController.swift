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
    var filteredMealHistories: [MealHistory] = []
    var datePicker: UIDatePicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Måltidshistorik"
        view.backgroundColor = .systemBackground
        setupDatePicker()
        setupTableView()
        fetchMealHistories()
        
        // Add Cancel button to the navigation bar
        let cancelButton = UIBarButtonItem(title: "Avbryt", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = cancelButton
    }
    
    @objc private func cancelButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupDatePicker() {
        datePicker = UIDatePicker()
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.addTarget(self, action: #selector(datePickerValueChanged), for: .valueChanged)
        
        view.addSubview(datePicker)
        
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    @objc private func datePickerValueChanged() {
        filterMealHistories(by: datePicker.date)
    }
    
    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MealHistoryCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 8),
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
            filteredMealHistories = mealHistories
            tableView.reloadData()
        } catch {
            print("Failed to fetch meal histories: \(error)")
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredMealHistories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "MealHistoryCell")
        let mealHistory = filteredMealHistories[indexPath.row]
        
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
            let mealHistory = filteredMealHistories[indexPath.row]
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            let context = appDelegate.persistentContainer.viewContext
            context.delete(mealHistory)
            
            do {
                try context.save()
                mealHistories.removeAll { $0 == mealHistory }
                filteredMealHistories.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            } catch {
                print("Failed to delete meal history: \(error)")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mealHistory = filteredMealHistories[indexPath.row]
        let detailVC = MealHistoryDetailViewController()
        detailVC.mealHistory = mealHistory
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    private func filterMealHistories(by date: Date) {
        filteredMealHistories = mealHistories.filter { mealHistory in
            if let mealDate = mealHistory.mealDate {
                return Calendar.current.isDate(mealDate, inSameDayAs: date)
            }
            return false
        }
        tableView.reloadData()
    }
}
