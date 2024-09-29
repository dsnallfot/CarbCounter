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
    private let segmentedControl = UISegmentedControl(items: ["Analys måltider", "Analys livsmedel"])
    private let mealTimesSegmentedControl = UISegmentedControl(items: ["Dygn", "Frukost", "Lunch", "Mellis", "Middag"])
    private let searchTextField = UITextField()
    private let statsTableView = UITableView()
    private let fromTimePicker = UIDatePicker()
    private let toTimePicker = UIDatePicker()
    private let fromTimeLabel = UILabel()
    private let toTimeLabel = UILabel()

    // Stats View
    private let statsView = UIView()
    private let statsLabel = UILabel()

    // Data
    private var mealHistories: [MealHistory] = []
    private var uniqueFoodEntries: [String] = [] // To store unique food names for display
    private var allFilteredFoodEntries: [FoodItemEntry] = [] // For stats calculations

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Måltidsinsikter", comment: "Title for MealInsights screen")
        view.backgroundColor = .systemBackground

        setupGradientView()
        setupSegmentedControlAndDatePickers()
        setupMealTimesSegmentedControl() // Setup new control
        setupSearchTextField()
        setupStatsTableView()
        setupStatsView()
        setupTimePickers()

        loadDefaultDates()
        setDefaultTimePickers() // Set default times
        fetchMealHistories()

        // Set default mode to "Analys livsmedel"
        switchMode(segmentedControl)
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
    
    private func setupSegmentedControlAndDatePickers() {
        // Configure From Date Picker and Label
        fromDateLabel.text = NSLocalizedString("Från datum", comment: "From Date Label")
        fromDateLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        fromDateLabel.textColor = .label
        fromDatePicker.datePickerMode = .date
        fromDatePicker.preferredDatePickerStyle = .compact
        fromDatePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)

        let fromDateStackView = UIStackView(arrangedSubviews: [fromDateLabel, fromDatePicker])
        fromDateStackView.axis = .horizontal
        fromDateStackView.spacing = 8
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

        // Create a stack view to hold the date pickers and the segmented control
        let datePickersStackView = UIStackView(arrangedSubviews: [fromDateStackView, toDateStackView])
        datePickersStackView.axis = .vertical
        datePickersStackView.spacing = 16
        datePickersStackView.translatesAutoresizingMaskIntoConstraints = false

        // Add the segmented control
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.addTarget(self, action: #selector(switchMode(_:)), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        // Create a stack view that includes both the date pickers and the segmented control
        let combinedStackView = UIStackView(arrangedSubviews: [datePickersStackView, segmentedControl])
        combinedStackView.axis = .vertical
        combinedStackView.spacing = 16
        combinedStackView.translatesAutoresizingMaskIntoConstraints = false

        // Add the combined stack view to the main view
        view.addSubview(combinedStackView)

        // Set constraints for the combined stack view
        NSLayoutConstraint.activate([
            combinedStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            combinedStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            combinedStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }
    
    // Set default times for time pickers
    private func setDefaultTimePickers() {
        let calendar = Calendar.current
        if let fromTime = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date()),
           let toTime = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: Date()) {
            fromTimePicker.date = fromTime
            toTimePicker.date = toTime
        }
    }

    private func setupMealTimesSegmentedControl() {
        mealTimesSegmentedControl.selectedSegmentIndex = 0
        mealTimesSegmentedControl.addTarget(self, action: #selector(mealTimesSegmentChanged(_:)), for: .valueChanged)
        mealTimesSegmentedControl.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mealTimesSegmentedControl)

        NSLayoutConstraint.activate([
            mealTimesSegmentedControl.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            mealTimesSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mealTimesSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    // Action when meal times segment is changed
    @objc private func mealTimesSegmentChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0: // Dygn
            setTimePickers(fromHour: 0, fromMinute: 0, toHour: 23, toMinute: 59)
        case 1: // Frukost
            setTimePickers(fromHour: 6, fromMinute: 0, toHour: 10, toMinute: 0)
        case 2: // Lunch
            setTimePickers(fromHour: 10, fromMinute: 0, toHour: 14, toMinute: 0)
        case 3: // Mellis
            setTimePickers(fromHour: 14, fromMinute: 0, toHour: 17, toMinute: 0)
        case 4: // Middag
            setTimePickers(fromHour: 17, fromMinute: 0, toHour: 20, toMinute: 0)
        default:
            break
        }
        // Immediately trigger the calculations after changing the meal times
        calculateMealStats()
    }
    
    // Helper function to set time pickers
    private func setTimePickers(fromHour: Int, fromMinute: Int, toHour: Int, toMinute: Int) {
        let calendar = Calendar.current
        if let fromTime = calendar.date(bySettingHour: fromHour, minute: fromMinute, second: 0, of: Date()),
           let toTime = calendar.date(bySettingHour: toHour, minute: toMinute, second: 0, of: Date()) {
            fromTimePicker.date = fromTime
            toTimePicker.date = toTime
        }
    }
    
    // Time pickers for "Analys måltider" mode
    private func setupTimePickers() {
        // Configure "Från tid" label and picker
        fromTimeLabel.text = NSLocalizedString("Från tid", comment: "From Time Label")
        fromTimeLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        fromTimeLabel.textColor = .label
        fromTimePicker.datePickerMode = .time
        fromTimePicker.preferredDatePickerStyle = .compact  // Set compact style to make it smaller
        fromTimePicker.addTarget(self, action: #selector(timeChanged), for: .valueChanged)
        fromTimePicker.translatesAutoresizingMaskIntoConstraints = false
        fromTimeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Configure "Till tid" label and picker
        toTimeLabel.text = NSLocalizedString("Till tid", comment: "To Time Label")
        toTimeLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        toTimeLabel.textColor = .label
        toTimePicker.datePickerMode = .time
        toTimePicker.preferredDatePickerStyle = .compact  // Set compact style to make it smaller
        toTimePicker.addTarget(self, action: #selector(timeChanged), for: .valueChanged)
        toTimePicker.translatesAutoresizingMaskIntoConstraints = false
        toTimeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Stack views for time pickers with labels
        let fromTimeStackView = UIStackView(arrangedSubviews: [fromTimeLabel, fromTimePicker])
        fromTimeStackView.axis = .horizontal
        fromTimeStackView.spacing = 8
        fromTimeStackView.translatesAutoresizingMaskIntoConstraints = false

        let toTimeStackView = UIStackView(arrangedSubviews: [toTimeLabel, toTimePicker])
        toTimeStackView.axis = .horizontal
        toTimeStackView.spacing = 8
        toTimeStackView.translatesAutoresizingMaskIntoConstraints = false

        // Combine both time pickers into one stack
        let timePickersStackView = UIStackView(arrangedSubviews: [fromTimeStackView, toTimeStackView])
        timePickersStackView.axis = .vertical
        timePickersStackView.spacing = 16
        timePickersStackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(timePickersStackView)

        // Ensure proper constraints
        NSLayoutConstraint.activate([
            timePickersStackView.topAnchor.constraint(equalTo: mealTimesSegmentedControl.bottomAnchor, constant: 16),
            timePickersStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            timePickersStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Adjust bottom to fit with statsView
            //timePickersStackView.bottomAnchor.constraint(equalTo: statsView.topAnchor, constant: -16),

            // Set the height of the time pickers to be similar to the date pickers
            fromTimePicker.heightAnchor.constraint(equalToConstant: 40),
            toTimePicker.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // Trigger calculations when time is changed
    @objc private func timeChanged() {
        calculateMealStats()
    }

    @objc private func switchMode(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            // "Analys måltider" mode
            searchTextField.isHidden = true
            statsTableView.isHidden = true
            fromTimePicker.isHidden = false
            toTimePicker.isHidden = false
            fromTimeLabel.isHidden = false
            toTimeLabel.isHidden = false
            mealTimesSegmentedControl.isHidden = false // Show the meal times control

            calculateMealStats()
        } else {
            // "Analys livsmedel" mode
            searchTextField.isHidden = false
            statsTableView.isHidden = false
            fromTimePicker.isHidden = true
            toTimePicker.isHidden = true
            fromTimeLabel.isHidden = true
            toTimeLabel.isHidden = true
            mealTimesSegmentedControl.isHidden = true // Hide the meal times control
        }
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
            searchTextField.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
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

        // Add both statsTableView and statsView to the hierarchy first
        view.addSubview(statsTableView)
        view.addSubview(statsView)  // Adding both views before setting constraints

        NSLayoutConstraint.activate([
            statsTableView.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 16),
            statsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
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

        // Make sure statsView is added to the view hierarchy before applying constraints
        view.addSubview(statsView)

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
    
    // Meal analysis calculations
    private func calculateMealStats() {
        let fromDate = fromDatePicker.date
        let toDate = toDatePicker.date
        let fromTime = fromTimePicker.date
        let toTime = toTimePicker.date
        
        let filteredMeals = mealHistories.filter {
            guard let mealDate = $0.mealDate else { return false }
            let calendar = Calendar.current
            let mealTime = calendar.dateComponents([.hour, .minute], from: mealDate)
            let fromTimeComponents = calendar.dateComponents([.hour, .minute], from: fromTime)
            let toTimeComponents = calendar.dateComponents([.hour, .minute], from: toTime)
            
            return mealDate >= fromDate && mealDate <= toDate &&
                (mealTime.hour! >= fromTimeComponents.hour! && mealTime.minute! >= fromTimeComponents.minute!) &&
                (mealTime.hour! <= toTimeComponents.hour! && mealTime.minute! <= toTimeComponents.minute!) &&
                $0.totalNetCarbs > 0  // Filter out meals with totalNetCarbs == 0
        }
        
        let totalCarbs = filteredMeals.map { $0.totalNetCarbs }.reduce(0, +)
        let totalFat = filteredMeals.map { $0.totalNetFat }.reduce(0, +)
        let totalProtein = filteredMeals.map { $0.totalNetProtein }.reduce(0, +)
        let totalBolus = filteredMeals.map { $0.totalNetBolus }.reduce(0, +)
        let count = Double(filteredMeals.count)
        
        let avgCarbs = totalCarbs / count
        let avgFat = totalFat / count
        let avgProtein = totalProtein / count
        let avgBolus = totalBolus / count
        let insulinRatio = avgCarbs / avgBolus
        
        statsLabel.text = """
        • \(NSLocalizedString("Genomsnitt Kolhydrater", comment: "Average Carbs")): \(String(format: "%.0f g", avgCarbs))
        • \(NSLocalizedString("Genomsnitt Fett", comment: "Average Fat")): \(String(format: "%.0f g", avgFat))
        • \(NSLocalizedString("Genomsnitt Protein", comment: "Average Protein")): \(String(format: "%.0f g", avgProtein))
        • \(NSLocalizedString("Genomsnitt Bolus", comment: "Average Bolus")): \(String(format: "%.2f E", avgBolus))
        • \(NSLocalizedString("Verklig insulinkvot", comment: "Actual Insulin Ratio")): \(String(format: "%.0f g/E", insulinRatio))
        """
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
