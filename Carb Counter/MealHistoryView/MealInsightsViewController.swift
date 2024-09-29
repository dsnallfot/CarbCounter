//
//  MealInsightsViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-09-29.
//
import UIKit
import CoreData

class MealInsightsViewController: UIViewController {
    
    // UI Elements
    private let fromDateLabel = UILabel()
    private let toDateLabel = UILabel()
    private let fromDatePicker = UIDatePicker()
    private let toDatePicker = UIDatePicker()
    private let searchTextField = UITextField()
    private let statsTableView = UITableView()
    
    // Stats View
    private let statsView = UIView()
    private let statsLabel = UILabel()
    
    // Data
    private var mealHistories: [MealHistory] = []
    private var uniqueFoodEntries: [String] = []  // To store unique food names for display
    private var allFilteredFoodEntries: [FoodItemEntry] = []  // To store all entries (including duplicates) for stats calculations
    private var selectedFoodEntry: String?  // To track the selected food entry
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Måltidsinsikter", comment: "Title for MealInsights screen")
        view.backgroundColor = .systemBackground
        
        setupGradientView()
        setupDatePickers()
        setupSearchTextField()
        setupStatsTableView()
        setupStatsView()
        loadDefaultDates()
        fetchMealHistories()
    }
    private func setupGradientView() {
        let colors: [CGColor] = [
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        ]
        let gradientView = GradientView(colors: colors)
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)
        
        NSLayoutConstraint.activate([
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupDatePickers() {
        // Configure From Date Picker and Label
        fromDateLabel.text = NSLocalizedString("Från datum", comment: "From Date Label")
        fromDateLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        fromDateLabel.textColor = .label
        fromDatePicker.datePickerMode = .date
        fromDatePicker.preferredDatePickerStyle = .compact
        fromDatePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        
        let fromDateStackView = UIStackView(arrangedSubviews: [fromDateLabel, fromDatePicker])
        fromDateStackView.axis = .horizontal
        fromDateStackView.spacing = 8 // Space between label and picker
        fromDateStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure To Date Picker and Label
        toDateLabel.text = NSLocalizedString("Till datum", comment: "To Date Label")
        toDateLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        toDateLabel.textColor = .label
        toDatePicker.datePickerMode = .date
        toDatePicker.preferredDatePickerStyle = .compact
        toDatePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        
        let toDateStackView = UIStackView(arrangedSubviews: [toDateLabel, toDatePicker])
        toDateStackView.axis = .horizontal
        toDateStackView.spacing = 8
        toDateStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Stack both date rows vertically
        let datePickersStackView = UIStackView(arrangedSubviews: [fromDateStackView, toDateStackView])
        datePickersStackView.axis = .vertical
        datePickersStackView.spacing = 16
        datePickersStackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(datePickersStackView)
        
        NSLayoutConstraint.activate([
            datePickersStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            datePickersStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            datePickersStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupSearchTextField() {
        searchTextField.placeholder = NSLocalizedString("Sök livsmedel", comment: "Search Food Item placeholder")
        searchTextField.borderStyle = .roundedRect
        searchTextField.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.6)
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Enable the default clear button
        searchTextField.clearButtonMode = .whileEditing  // This is the default clear button
        
        view.addSubview(searchTextField)
        
        NSLayoutConstraint.activate([
            searchTextField.topAnchor.constraint(equalTo: toDatePicker.bottomAnchor, constant: 16),
            searchTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchTextField.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupStatsTableView() {
        statsTableView.dataSource = self
        statsTableView.delegate = self
        statsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "StatsCell")
        statsTableView.translatesAutoresizingMaskIntoConstraints = false
        statsTableView.separatorStyle = .none
        statsTableView.backgroundColor = .clear

        // Make sure both statsTableView and statsView are added to the view hierarchy before setting constraints
        view.addSubview(statsTableView)
        view.addSubview(statsView)  // Ensure statsView is added before applying constraints

        NSLayoutConstraint.activate([
            statsTableView.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 16),
            statsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Constrain the bottom of the table to the top of the stats view
            statsTableView.bottomAnchor.constraint(equalTo: statsView.topAnchor, constant: -10)  // Adjust the spacing as needed
        ])
    }

    private func setupStatsView() {
        statsView.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.6)
        statsView.layer.cornerRadius = 10
        statsView.translatesAutoresizingMaskIntoConstraints = false
        
        statsLabel.numberOfLines = 0
        statsLabel.textAlignment = .center
        statsView.addSubview(statsLabel)
        statsLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            statsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            statsView.heightAnchor.constraint(equalToConstant: 190),
            
            statsLabel.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 16),
            statsLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -16),
            statsLabel.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: -16)
        ])
    }
    private func loadDefaultDates() {
        if let earliestMealDate = mealHistories.map({ $0.mealDate ?? Date() }).min() {
            fromDatePicker.date = earliestMealDate
        }
        toDatePicker.date = Date()
    }
    
    private func fetchMealHistories() {
        let context = CoreDataStack.shared.context
        let fetchRequest = NSFetchRequest<MealHistory>(entityName: "MealHistory")
        let sortDescriptor = NSSortDescriptor(key: "mealDate", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        fetchRequest.predicate = NSPredicate(format: "delete == NO OR delete == nil")
        
        do {
            let mealHistories = try context.fetch(fetchRequest)
            DispatchQueue.main.async {
                self.mealHistories = mealHistories
                self.filterFoodEntries()
                self.loadDefaultDates()
            }
        } catch {
            DispatchQueue.main.async {
                print("Failed to fetch meal histories: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func dateChanged() {
        filterFoodEntries()
        resetStatsView()  // Clear stats when date changes
    }
    
    @objc private func searchTextChanged() {
        filterFoodEntries()
        
        // Reset stats if search field is cleared
        if searchTextField.text?.isEmpty ?? true {
            resetStatsView()
        }
    }
    
    private func filterFoodEntries() {
        let fromDate = fromDatePicker.date
        let toDate = toDatePicker.date
        let searchText = searchTextField.text?.lowercased() ?? ""
        
        let filteredHistories = mealHistories.filter {
            guard let mealDate = $0.mealDate else { return false }
            return mealDate >= fromDate && mealDate <= toDate
        }
        
        // Collect all entries for calculation (including duplicates) and exclude those with entryPortionServed == 0
        allFilteredFoodEntries = filteredHistories.flatMap { history in
            (history.foodEntries?.allObjects as? [FoodItemEntry] ?? []).filter { $0.entryPortionServed > 0 }
        }
        
        // Use a set to filter unique food item names for display
        var uniqueFoodNamesSet = Set<String>()
        uniqueFoodEntries = allFilteredFoodEntries.filter { entry in
            let entryName = entry.entryName?.lowercased() ?? ""
            if entryName.contains(searchText) && !uniqueFoodNamesSet.contains(entryName) {
                uniqueFoodNamesSet.insert(entryName)
                return true
            }
            return false
        }.map { $0.entryName ?? "" }
        
        statsTableView.reloadData()
    }
    
    private func resetStatsView() {
        statsLabel.text = ""  // Clear the stats view
    }
    
    private func updateStats(for entryName: String) {
        // Filter matching entries where the entryName matches and entryPortionServed is greater than 0
        let matchingEntries = allFilteredFoodEntries.filter {
            $0.entryName?.lowercased() == entryName.lowercased() && $0.entryPortionServed > 0
        }
        
        // Get the emoji from the first matching entry, or default to an empty string if no entries are found
        let entryEmoji = matchingEntries.first?.entryEmoji ?? ""
        
        // Determine if the portions are measured in pieces or grams
        let isPerPiece = matchingEntries.first?.entryPerPiece ?? false
        
        let timesServed = matchingEntries.count
        let portions = matchingEntries.map { $0.entryPortionServed - $0.entryNotEaten }
        let averagePortion = portions.reduce(0, +) / Double(portions.count)
        let largestPortion = portions.max() ?? 0.0
        let smallestPortion = portions.min() ?? 0.0
        
        // Format based on whether it's measured in pieces or grams
        let portionFormat = isPerPiece ? NSLocalizedString("%.1f st", comment: "Per piece portion format") : NSLocalizedString("%.0f g", comment: "Grams portion format")
        
        // Create an attributed string to apply different styles
        let statsText = NSMutableAttributedString()
        
        // Bold the first line (entryName and entryEmoji)
        let boldText = "\(entryName) \(entryEmoji)\n\n"
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: statsLabel.font.pointSize)
        ]
        statsText.append(NSAttributedString(string: boldText, attributes: boldAttributes))
        
        // Regular text for the rest
        let regularText = """
        • \(NSLocalizedString("Genomsnittlig portion", comment: "Average portion label")): \(String(format: portionFormat, averagePortion))
        • \(NSLocalizedString("Största portion", comment: "Largest portion label")): \(String(format: portionFormat, largestPortion))
        • \(NSLocalizedString("Minsta portion", comment: "Smallest portion label")): \(String(format: portionFormat, smallestPortion))
        • \(NSLocalizedString("Serverats antal gånger", comment: "Times served label")): \(timesServed)
        """
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: statsLabel.font.pointSize)
        ]
        statsText.append(NSAttributedString(string: regularText, attributes: regularAttributes))
        
        // Assign the attributed text to the label
        statsLabel.attributedText = statsText
    }
}
    extension MealInsightsViewController: UITableViewDataSource, UITableViewDelegate {
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return uniqueFoodEntries.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "StatsCell", for: indexPath)
            let foodEntryName = uniqueFoodEntries[indexPath.row]
            cell.textLabel?.text = foodEntryName
            cell.backgroundColor = .clear
            return cell
        }
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            let selectedEntry = uniqueFoodEntries[indexPath.row]
            
            searchTextField.resignFirstResponder()
            updateStats(for: selectedEntry)
        }
    }
