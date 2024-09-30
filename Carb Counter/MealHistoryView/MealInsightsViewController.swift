//
//  MealInsightsViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-09-29.
//
import UIKit
import CoreData

class MealInsightsViewController: UIViewController {
    
    var prepopulatedSearchText: String?

    // UI Elements
    private let fromDateLabel = UILabel()
    private let toDateLabel = UILabel()
    private let fromDatePicker = UIDatePicker()
    private let toDatePicker = UIDatePicker()
    private let segmentedControl = UISegmentedControl(items: [
        NSLocalizedString("Måltider", comment: "Meal insights segment title"),
        NSLocalizedString("Livsmedel", comment: "Food insights segment title")
    ])
    private let mealTimesSegmentedControl = UISegmentedControl(items: [
        NSLocalizedString("Dygn", comment: "Day time period"),
        NSLocalizedString("Frukost", comment: "Breakfast time period"),
        NSLocalizedString("Lunch", comment: "Lunch time period"),
        NSLocalizedString("Mellis", comment: "Snack time period"),
        NSLocalizedString("Middag", comment: "Dinner time period")
    ])
    private let datePresetsSegmentedControl = UISegmentedControl(items: ["Allt", "3d", "7d", "30d", "90d"])
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
    private var uniqueFoodEntries: [String] = []
    private var allFilteredFoodEntries: [FoodItemEntry] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Måltidsinsikter", comment: "Title for MealInsights screen")
        view.backgroundColor = .systemBackground
    
        // Add the close button when the view is presented modally
        if isModalPresentation {
            addCloseButton()
        } else {
            updateStats(for: "")
        }
        
        setupGradientView()
        setupSegmentedControlAndDatePickers()
        setupMealTimesSegmentedControl()
        setupSearchTextField()
        setupStatsTableView()
        setupStatsView()
        setupTimePickers()

        loadDefaultDates()
        setDefaultTimePickers()
        fetchMealHistories()

        // Set default mode to "Insikt livsmedel"
        switchMode(segmentedControl)
        
        // Delay performing the search until the data is fully loaded
        DispatchQueue.main.async {
            if let searchText = self.prepopulatedSearchText {
                self.searchTextField.text = searchText
                print("searchtext: \(searchText)")  // Now log it before performing the search
                self.performSearch(with: searchText)
            }
        }
    }
    
    // Function to check if the view controller is presented modally
    private var isModalPresentation: Bool {
        return presentingViewController != nil || navigationController?.presentingViewController?.presentedViewController == navigationController || tabBarController?.presentingViewController is UITabBarController
    }

    // Add a close button to the navigation bar
    private func addCloseButton() {
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(dismissModal))
        navigationItem.leftBarButtonItem = closeButton
    }

    // Action to dismiss the view controller
    @objc private func dismissModal() {
        dismiss(animated: true, completion: nil)
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

        // Date pickers stack view
        let datePickersStackView = UIStackView(arrangedSubviews: [fromDateStackView, toDateStackView])
        datePickersStackView.axis = .vertical
        datePickersStackView.spacing = 16
        datePickersStackView.translatesAutoresizingMaskIntoConstraints = false

        // Main segmented control
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.addTarget(self, action: #selector(switchMode(_:)), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        // Date preset segmented control
        datePresetsSegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        datePresetsSegmentedControl.addTarget(self, action: #selector(datePresetChanged(_:)), for: .valueChanged)
        datePresetsSegmentedControl.translatesAutoresizingMaskIntoConstraints = false

        // Combine the controls and stack views
        let combinedStackView = UIStackView(arrangedSubviews: [segmentedControl, datePresetsSegmentedControl, datePickersStackView])
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

    // Action for date presets
    @objc private func datePresetChanged(_ sender: UISegmentedControl) {
        let now = Date()
        var fromDate: Date?

        switch sender.selectedSegmentIndex {
        case 0: // Allt - Get the earliest available date from mealHistories
            fromDate = mealHistories.map { $0.mealDate ?? now }.min() ?? now
        case 1: // 3d
            fromDate = Calendar.current.date(byAdding: .hour, value: -72, to: now)
        case 2: // 7d
            fromDate = Calendar.current.date(byAdding: .hour, value: -144, to: now)
        case 3: // 30d
            fromDate = Calendar.current.date(byAdding: .day, value: -30, to: now)
        case 4: // 90d
            fromDate = Calendar.current.date(byAdding: .day, value: -90, to: now)
        default:
            break
        }

        if let fromDate = fromDate {
            fromDatePicker.date = fromDate
            toDatePicker.date = now

            // Check if the selected case in segmentedControl is "Insikt livsmedel" or "Insikt måltider"
            if segmentedControl.selectedSegmentIndex == 1 {
                // Case: "Insikt livsmedel"
                filterFoodEntries()
                updateStats(for: "")
            } else if segmentedControl.selectedSegmentIndex == 0 {
                // Case: "Insikt måltider"
                calculateMealStats()
            }
        }
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
            mealTimesSegmentedControl.topAnchor.constraint(equalTo: toDateLabel.bottomAnchor, constant: 16),
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
    
    // Time pickers for "Insikt måltider" mode
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
            // "Insikt måltider" mode
            searchTextField.isHidden = true
            searchTextField.resignFirstResponder() // Hide keyboard if it is up
            statsTableView.isHidden = true
            fromTimePicker.isHidden = false
            toTimePicker.isHidden = false
            fromTimeLabel.isHidden = false
            toTimeLabel.isHidden = false
            mealTimesSegmentedControl.isHidden = false // Show the meal times control

            calculateMealStats()
        } else {
            // "Insikt livsmedel" mode
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
        searchTextField.backgroundColor = UIColor.systemGray2.withAlphaComponent(0.2)
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Enable the default clear button
        searchTextField.clearButtonMode = .whileEditing  // This is the default clear button
        
        view.addSubview(searchTextField)
        
        NSLayoutConstraint.activate([
            searchTextField.topAnchor.constraint(equalTo: toDateLabel.bottomAnchor, constant: 16),
            searchTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchTextField.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func performSearch(with searchText: String) {
        // Trim the search text to remove any leading/trailing whitespace
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Filter entries based on the trimmed search text
        self.filterFoodEntries()

        // Try to find the matching entry
        if let matchingEntry = allFilteredFoodEntries.first(where: {
            let trimmedEntryName = $0.entryName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            return trimmedEntryName == trimmedSearchText
        }) {
            print("match found \(matchingEntry.entryName ?? "")")
            updateStats(for: matchingEntry.entryName ?? "")
        } else {
            print("no match found \(searchText)")
            updateStats(for: "")
        }
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
        statsView.backgroundColor = UIColor.systemGray2.withAlphaComponent(0.2)
        statsView.layer.cornerRadius = 10
        statsView.layer.borderWidth = 1
        statsView.layer.borderColor = UIColor.white.cgColor
        statsView.translatesAutoresizingMaskIntoConstraints = false

        statsLabel.numberOfLines = 0
        statsLabel.textAlignment = .center
        statsView.addSubview(statsLabel)
        statsLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(statsView)

        NSLayoutConstraint.activate([
            statsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            statsView.heightAnchor.constraint(equalToConstant: 220),

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
        // Check if the selected case in segmentedControl is "Insikt livsmedel" or "Insikt måltider"
        if segmentedControl.selectedSegmentIndex == 1 {
            // Case: "Insikt livsmedel"
            filterFoodEntries()
            updateStats(for: "")
        } else if segmentedControl.selectedSegmentIndex == 0 {
            // Case: "Insikt måltider"
            calculateMealStats()
        }
    }
    
    @objc private func searchTextChanged() {
        filterFoodEntries()

        if searchTextField.text?.isEmpty ?? true {
            updateStats(for: "")
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
        
        // If no food items are found, insert a placeholder
        if uniqueFoodEntries.isEmpty {
            uniqueFoodEntries.append(NSLocalizedString("Inga sökträffar inom valt datumintervall", comment: "No search results found in the selected date range"))
        }
        
        statsTableView.reloadData()
    }
    
    // Meal insights calculations (MEDIAN VALUES VERSION)
    private func calculateMealStats() {
        let fromDate = fromDatePicker.date
        let toDate = toDatePicker.date
        let calendar = Calendar.current

        // Extract the time components from the time pickers
        let fromTimeComponents = calendar.dateComponents([.hour, .minute], from: fromTimePicker.date)
        let toTimeComponents = calendar.dateComponents([.hour, .minute], from: toTimePicker.date)

        let filteredMeals = mealHistories.filter { history in
            guard let mealDate = history.mealDate else { return false }

            // Step 1: Filter based on the date range
            if mealDate < fromDate || mealDate > toDate {
                return false
            }

            // Step 2: Filter based on the time range (only consider the time part of each meal)
            let mealTimeComponents = calendar.dateComponents([.hour, .minute], from: mealDate)

            // Ensure the meal's time is within the selected time range
            let isWithinTimeRange = (
                mealTimeComponents.hour! > fromTimeComponents.hour! ||
                (mealTimeComponents.hour == fromTimeComponents.hour && mealTimeComponents.minute! >= fromTimeComponents.minute!)
            ) && (
                mealTimeComponents.hour! < toTimeComponents.hour! ||
                (mealTimeComponents.hour == toTimeComponents.hour && mealTimeComponents.minute! <= toTimeComponents.minute!)
            )

            // Step 3: Return true if the meal is within both date and time range, and it has a valid totalNetCarbs
            return isWithinTimeRange && history.totalNetCarbs > 0
        }

        // Extract values for each category (carbohydrates, fat, protein, bolus)
        let carbsValues = filteredMeals.map { $0.totalNetCarbs }.sorted()
        let fatValues = filteredMeals.map { $0.totalNetFat }.sorted()
        let proteinValues = filteredMeals.map { $0.totalNetProtein }.sorted()
        let bolusValues = filteredMeals.map { $0.totalNetBolus }.sorted()

        // Helper function to calculate the median of an array
        func median(of values: [Double]) -> Double {
            guard !values.isEmpty else { return 0 }
            let sortedValues = values.sorted()
            let count = sortedValues.count
            if count % 2 == 0 {
                // If even, take the average of the two middle values
                return (sortedValues[count / 2 - 1] + sortedValues[count / 2]) / 2.0
            } else {
                // If odd, return the middle value
                return sortedValues[count / 2]
            }
        }

        // Calculate medians
        let medianCarbs = median(of: carbsValues)
        let medianFat = median(of: fatValues)
        let medianProtein = median(of: proteinValues)
        let medianBolus = median(of: bolusValues)
        let insulinRatio = medianCarbs / medianBolus

        // Create an attributed string to apply different styles
        let statsText = NSMutableAttributedString()

        // Bold the first line ("Medianvärden i måltider"), center-aligned
        let boldText = "\(NSLocalizedString("Medianvärden måltider (Datum och tid)", comment: "Medians"))\n\n"
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: statsLabel.font.pointSize),
            .paragraphStyle: centeredParagraphStyle()
        ]
        statsText.append(NSAttributedString(string: boldText, attributes: boldAttributes))

        // Create a tab stop for aligning text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: 300)]
        paragraphStyle.defaultTabInterval = 300
        paragraphStyle.alignment = .center

        // Regular text for the stats, left-aligned labels and right-aligned values
        let regularText = """
        \(NSLocalizedString("Kolhydrater", comment: "Median Carbs")):\t\(String(format: "%.0f g", medianCarbs))
        \(NSLocalizedString("Fett", comment: "Median Fat")):\t\(String(format: "%.0f g", medianFat))
        \(NSLocalizedString("Protein", comment: "Median Protein")):\t\(String(format: "%.0f g", medianProtein))
        \(NSLocalizedString("Bolus", comment: "Median Bolus")):\t\(String(format: "%.2f E", medianBolus))
        \(NSLocalizedString("Verklig insulinkvot", comment: "Actual Insulin Ratio")):\t\(String(format: "%.0f g/E", insulinRatio))
        """
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: statsLabel.font.pointSize),
            .paragraphStyle: paragraphStyle
        ]
        statsText.append(NSAttributedString(string: regularText, attributes: regularAttributes))

        // Assign the attributed text to the label
        statsLabel.attributedText = statsText
    }
    
    /*
    // Meal insights calculations (AVERAGE VALUES VERSION)
    private func calculateMealStats() {
        let fromDate = fromDatePicker.date
        let toDate = toDatePicker.date
        let calendar = Calendar.current

        // Extract the time components from the time pickers
        let fromTimeComponents = calendar.dateComponents([.hour, .minute], from: fromTimePicker.date)
        let toTimeComponents = calendar.dateComponents([.hour, .minute], from: toTimePicker.date)

        let filteredMeals = mealHistories.filter { history in
            guard let mealDate = history.mealDate else { return false }

            // Step 1: Filter based on the date range
            if mealDate < fromDate || mealDate > toDate {
                return false
            }

            // Step 2: Filter based on the time range (only consider the time part of each meal)
            let mealTimeComponents = calendar.dateComponents([.hour, .minute], from: mealDate)

            // Ensure the meal's time is within the selected time range
            let isWithinTimeRange = (
                mealTimeComponents.hour! > fromTimeComponents.hour! ||
                (mealTimeComponents.hour == fromTimeComponents.hour && mealTimeComponents.minute! >= fromTimeComponents.minute!)
            ) && (
                mealTimeComponents.hour! < toTimeComponents.hour! ||
                (mealTimeComponents.hour == toTimeComponents.hour && mealTimeComponents.minute! <= toTimeComponents.minute!)
            )

            // Step 3: Return true if the meal is within both date and time range, and it has a valid totalNetCarbs
            return isWithinTimeRange && history.totalNetCarbs > 0
        }

        // Calculate statistics based on the filtered meals
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

        // Create an attributed string to apply different styles
        let statsText = NSMutableAttributedString()

        // Bold the first line ("Medelvärden i måltider"), center-aligned
        let boldText = "\(NSLocalizedString("Medelvärden måltider (Datum och tid)", comment: "Averages"))\n\n"
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: statsLabel.font.pointSize),
            .paragraphStyle: centeredParagraphStyle()
        ]
        statsText.append(NSAttributedString(string: boldText, attributes: boldAttributes))

        // Create a tab stop for aligning text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: 300)]
        paragraphStyle.defaultTabInterval = 300
        paragraphStyle.alignment = .center

        // Regular text for the stats, left-aligned labels and right-aligned values
        let regularText = """
        \(NSLocalizedString("Kolhydrater", comment: "Average Carbs")):\t\(String(format: "%.0f g", avgCarbs))
        \(NSLocalizedString("Fett", comment: "Average Fat")):\t\(String(format: "%.0f g", avgFat))
        \(NSLocalizedString("Protein", comment: "Average Protein")):\t\(String(format: "%.0f g", avgProtein))
        \(NSLocalizedString("Bolus", comment: "Average Bolus")):\t\(String(format: "%.2f E", avgBolus))
        \(NSLocalizedString("Verklig insulinkvot", comment: "Actual Insulin Ratio")):\t\(String(format: "%.0f g/E", insulinRatio))
        """
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: statsLabel.font.pointSize),
            .paragraphStyle: paragraphStyle
        ]
        statsText.append(NSAttributedString(string: regularText, attributes: regularAttributes))

        // Assign the attributed text to the label
        statsLabel.attributedText = statsText
    }
    */

    // Helper function to center-align text for the title
    private func centeredParagraphStyle() -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        return paragraphStyle
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

        // Check if entryName and entryEmoji are empty, then use placeholder text
        let boldText: String
        if entryName.isEmpty && entryEmoji.isEmpty {
            boldText = NSLocalizedString("Välj datum och ett livsmedel för att visa mer information", comment: "Placeholder text for no selection")
        } else {
            boldText = "\(entryName) \(entryEmoji)\n\n"
        }

        // Bold the first line (either entryName and entryEmoji or placeholder), center-aligned
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: statsLabel.font.pointSize),
            .paragraphStyle: centeredParagraphStyle()
        ]
        statsText.append(NSAttributedString(string: boldText, attributes: boldAttributes))

        // If the boldText is not the placeholder, add the detailed stats
        if !(entryName.isEmpty && entryEmoji.isEmpty) {
            // Create a tab stop for aligning text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: 300)]
            paragraphStyle.defaultTabInterval = 300
            paragraphStyle.alignment = .center

            // Regular text for the stats
            let regularText = """
            \(NSLocalizedString("Genomsnittlig portion", comment: "Average portion label")):\t\(String(format: portionFormat, averagePortion))
            \(NSLocalizedString("Största portion", comment: "Largest portion label")):\t\(String(format: portionFormat, largestPortion))
            \(NSLocalizedString("Minsta portion", comment: "Smallest portion label")):\t\(String(format: portionFormat, smallestPortion))\n
            \(NSLocalizedString("Serverats antal gånger", comment: "Times served label")):\t\(timesServed)
            """
            let regularAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: statsLabel.font.pointSize),
                .paragraphStyle: paragraphStyle
            ]
            statsText.append(NSAttributedString(string: regularText, attributes: regularAttributes))
        }

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
            
            // Custom selection color
            let customSelectionColor = UIView()
            customSelectionColor.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            cell.selectedBackgroundView = customSelectionColor

            // If it's the placeholder row, customize it
            if foodEntryName == NSLocalizedString("Inga sökträffar inom valt datumintervall", comment: "No search results found in the selected date range") {
                cell.textLabel?.textColor = .systemGray
                cell.textLabel?.font = UIFont.italicSystemFont(ofSize: 16)
                cell.selectionStyle = .none  // Disable selection for the placeholder row
                cell.selectedBackgroundView = nil  // No selection effect for placeholder
            } else {
                cell.textLabel?.textColor = .label  // Default text color
                cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
                cell.selectionStyle = .default  // Enable selection for normal rows
                cell.selectedBackgroundView = customSelectionColor  // Use custom selection color
            }
            
            cell.textLabel?.text = foodEntryName
            cell.backgroundColor = .clear
            return cell
        }

        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            let selectedEntry = uniqueFoodEntries[indexPath.row]
            
            // Prevent selection if the placeholder is being shown
            if selectedEntry == NSLocalizedString("Inga sökträffar inom valt datumintervall", comment: "No search results found in the selected date range") {
                return
            }

            searchTextField.resignFirstResponder()
            updateStats(for: selectedEntry)
        }
    }
