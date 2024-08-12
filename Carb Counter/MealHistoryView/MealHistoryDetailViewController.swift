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
        // Create the gradient view
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
        
        setupDetailView()
        setupActionButton()
    }
    
    private func setupActionButton() {
        let actionButton = UIButton(type: .system)
        actionButton.setTitle("Servera samma måltid igen", for: .normal)
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 19, weight: .semibold)
        actionButton.backgroundColor = .systemBlue
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 10
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.addTarget(self, action: #selector(repeatMeal), for: .touchUpInside)
        
        view.addSubview(actionButton)
        
        NSLayoutConstraint.activate([
            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            actionButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func repeatMeal() {
        guard let mealHistory = mealHistory else {
            //print("mealHistory is nil")
            return
        }

        // Find an existing instance of ComposeMealViewController in the navigation stack
        if let navigationController = navigationController,
           let composeMealVC = navigationController.viewControllers.first(where: { $0 is ComposeMealViewController }) as? ComposeMealViewController {
            composeMealVC.populateWithMealHistory(mealHistory)
            navigationController.popToViewController(composeMealVC, animated: true)
        } else {
            // If no existing instance found, instantiate a new one
            let composeMealVC = ComposeMealViewController()
            composeMealVC.populateWithMealHistory(mealHistory)
            navigationController?.pushViewController(composeMealVC, animated: true)
        }
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
        summaryLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
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
            foodNameLabel.text = "\(foodEntry.entryName ?? "")"
            view.addSubview(foodNameLabel)
            
            NSLayoutConstraint.activate([
                foodNameLabel.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 18),
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
        var summaryText = ""
        
        if mealHistory.totalNetCarbs > 0 {
            let carbs = mealHistory.totalNetCarbs.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", mealHistory.totalNetCarbs) :
                String(format: "%.0f", mealHistory.totalNetCarbs)
            summaryText += "Kolhydrater \(carbs) g"
        }
        if mealHistory.totalNetFat > 0 {
            if !summaryText.isEmpty { summaryText += " • " }
            let fat = mealHistory.totalNetFat.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", mealHistory.totalNetFat) :
                String(format: "%.0f", mealHistory.totalNetFat)
            summaryText += "Fett \(fat) g"
        }
        if mealHistory.totalNetProtein > 0 {
            if !summaryText.isEmpty { summaryText += " • " }
            let protein = mealHistory.totalNetProtein.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", mealHistory.totalNetProtein) :
                String(format: "%.0f", mealHistory.totalNetProtein)
            summaryText += "Protein \(protein) g"
        }
        
        return "★ \(summaryText)"
    }
    
    private func formatFoodEntry(_ foodEntry: FoodItemEntry) -> String {
        var detailText = ""
        let portionServedFormatted = foodEntry.entryPortionServed.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", foodEntry.entryPortionServed) : String(format: "%.0f", foodEntry.entryPortionServed)
        let notEatenFormatted = foodEntry.entryNotEaten.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", foodEntry.entryNotEaten) : String(format: "%.0f", foodEntry.entryNotEaten)
        let eatenAmount = foodEntry.entryPortionServed - foodEntry.entryNotEaten
        let eatenAmountFormatted = eatenAmount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", eatenAmount) : String(format: "%.0f", eatenAmount)

        if foodEntry.entryNotEaten > 0 {
            if foodEntry.entryPerPiece {
                detailText = "Åt upp \(eatenAmountFormatted) st  [Serverades \(portionServedFormatted) st - Lämnade \(notEatenFormatted) st]"
            } else {
                detailText = "Åt upp \(eatenAmountFormatted) g  [Serverades \(portionServedFormatted) g - Lämnade \(notEatenFormatted) g]"
            }
        } else {
            if foodEntry.entryPerPiece {
                detailText = "Åt upp \(portionServedFormatted) st"
            } else {
                detailText = "Åt upp \(portionServedFormatted) g"
            }
        }
        
        return detailText
    }
}
