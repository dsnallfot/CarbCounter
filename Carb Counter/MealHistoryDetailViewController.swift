//
//  MealHistoryDetailViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-24.
//

import UIKit

class MealHistoryDetailViewController: UIViewController {
    
    var mealHistory: MealHistory?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupDetailView()
        
        // Add Cancel button to the navigation bar
        let cancelButton = UIBarButtonItem(title: "Avbryt", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = cancelButton
    }
    
    @objc private func cancelButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupDetailView() {
        guard let mealHistory = mealHistory else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let mealTimeStr = dateFormatter.string(from: mealHistory.mealDate ?? Date())
        
        title = "Måltid \(mealTimeStr)"
        
        let summaryLabel = UILabel()
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.numberOfLines = 0
        summaryLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        summaryLabel.text = formatSummary(mealHistory)
        view.addSubview(summaryLabel)
        
        NSLayoutConstraint.activate([
            summaryLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        var lastView: UIView = summaryLabel
        
        for foodEntry in mealHistory.foodEntries?.allObjects as? [FoodItemEntry] ?? [] {
            let foodNameLabel = UILabel()
            foodNameLabel.translatesAutoresizingMaskIntoConstraints = false
            foodNameLabel.numberOfLines = 0
            foodNameLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            foodNameLabel.text = "\(foodEntry.name ?? "")"
            view.addSubview(foodNameLabel)
            
            NSLayoutConstraint.activate([
                foodNameLabel.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 12),
                foodNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                foodNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
            ])
            
            let foodDetailLabel = UILabel()
            foodDetailLabel.translatesAutoresizingMaskIntoConstraints = false
            foodDetailLabel.numberOfLines = 0
            foodDetailLabel.font = UIFont.systemFont(ofSize: 14, weight: .light)
            foodDetailLabel.textColor = .gray
            foodDetailLabel.text = formatFoodEntry(foodEntry)
            view.addSubview(foodDetailLabel)
            
            NSLayoutConstraint.activate([
                foodDetailLabel.topAnchor.constraint(equalTo: foodNameLabel.bottomAnchor, constant: 4),
                foodDetailLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                foodDetailLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
            ])
            
            lastView = foodDetailLabel
        }
    }
    
    private func formatSummary(_ mealHistory: MealHistory) -> String {
        var summaryText = "Summa:   "
        
        if mealHistory.totalNetCarbs > 0 {
            summaryText += "Kh \(String(format: "%.0f", mealHistory.totalNetCarbs)) g"
        }
        if mealHistory.totalNetFat > 0 {
            summaryText += summaryText.isEmpty ? "" : " • "
            summaryText += "Fett \(String(format: "%.0f", mealHistory.totalNetFat)) g"
        }
        if mealHistory.totalNetProtein > 0 {
            summaryText += summaryText.isEmpty ? "" : " • "
            summaryText += "Protein \(String(format: "%.0f", mealHistory.totalNetProtein)) g"
        }
        
        return summaryText
    }
    
    private func formatFoodEntry(_ foodEntry: FoodItemEntry) -> String {
        var detailText = ""
        
        if foodEntry.portionServed > 0 {
            if foodEntry.perPiece {
                detailText += "Serverades: \(String(format: "%.0f", foodEntry.portionServed)) st"
            } else {
                detailText += "Serverades: \(String(format: "%.0f", foodEntry.portionServed)) g"
            }
        }
        
        if foodEntry.notEaten > 0 {
            detailText += detailText.isEmpty ? "" : " • "
            if foodEntry.perPiece {
                detailText += "Lämnade: \(String(format: "%.0f", foodEntry.notEaten)) st"
            } else {
                detailText += "Lämnade: \(String(format: "%.0f", foodEntry.notEaten)) g"
            }
        }
        
        return detailText
    }
}
