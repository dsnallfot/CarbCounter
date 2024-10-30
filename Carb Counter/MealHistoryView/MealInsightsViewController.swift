//
//  MealInsightsViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-09-29.
//
import UIKit
import CoreData
import DGCharts

class MealInsightsViewController: UIViewController, ChartViewDelegate {
    
    weak var delegate: MealInsightsDelegate?
    
    var prepopulatedSearchText: String?
    var onAveragePortionSelected: ((Double) -> Void)?
    private var selectedEntryName: String?
    private var selectedEntryId: UUID?
    private var isComingFromModal = false
    public var isComingFromFoodItemRow = false
    public var isComingFromDetailView = false
    private var statsViewBottomConstraint: NSLayoutConstraint!
    private var statsTableTopConstraint: NSLayoutConstraint?
    private var statsTableBottomConstraint: NSLayoutConstraint?
    private var chartViewBottomConstraint: NSLayoutConstraint?
    private let combinedStackView = UIStackView()
    public var selectedFoodEntry: FoodItemEntry?
    
    // Bool to track chart data selection state
        private var chartDataSelected = false {
            didSet {
                updateButtonStates()
            }
        }
    
    
    // UI Elements
    private let fromDateLabel = UILabel()
    private let toDateLabel = UILabel()
    private let fromDatePicker = UIDatePicker()
    private let toDatePicker = UIDatePicker()
    private var nightscoutButton: UIBarButtonItem?
    private var scopeButton: UIBarButtonItem?
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
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("Använd genomsnittlig portion", comment: "Default button label"), for: .normal)
        let systemFont = UIFont.systemFont(ofSize: 19, weight: .semibold)
        if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            button.titleLabel?.font = UIFont(descriptor: roundedDescriptor, size: 19)
        } else {
            button.titleLabel?.font = systemFont
        }
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
        
    }()
    
    private let datePresetsSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["3d", "7d", "30d", "90d", ""]) // Leave the first item empty
        if let infinitySymbol = UIImage(systemName: "infinity") {
            control.setImage(infinitySymbol, forSegmentAt: 4) // Set the infinity SF Symbol for the last segment
        }
        return control
    }()
    private let statsTableView = UITableView()
    private let fromTimePicker = UIDatePicker()
    private let toTimePicker = UIDatePicker()
    private let fromTimeLabel = UILabel()
    private let toTimeLabel = UILabel()
    
    private var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = NSLocalizedString("Sök livsmedel", comment: "Search Food Item placeholder")
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.backgroundImage = UIImage()
        
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.tintColor = .label
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.backgroundColor = UIColor.systemGray2.withAlphaComponent(0.2)
            textField.layer.cornerRadius = 8
            textField.layer.masksToBounds = true
            
            // Toolbar setup
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            
            let symbolImage = UIImage(systemName: "keyboard.chevron.compact.down")
            let cancelButton = UIButton(type: .system)
            cancelButton.setImage(symbolImage, for: .normal)
            cancelButton.tintColor = .label
            cancelButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
            cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
            let cancelBarButtonItem = UIBarButtonItem(customView: cancelButton)
            
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Done button"), style: .done, target: self, action: #selector(doneButtonTapped))
            
            toolbar.setItems([cancelBarButtonItem, flexSpace, doneButton], animated: false)
            
            // Attach toolbar to textField's inputAccessoryView
            textField.inputAccessoryView = toolbar
        }
        return searchBar
    }()
    
    // Stats View
    private let statsView = UIView()
    private let statsLabel = UILabel()
    
    // Data
    private var mealHistories: [MealHistory] = []
    var uniqueFoodEntries = [FoodEntryInfo]()
    private var allFilteredFoodEntries: [FoodItemEntry] = []
    
    // Define the LineChartView
    private var lineChartView: LineChartView!
    
    // Declare chartLabel here
    private let chartLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the flag based on whether the view controller is presented modally
        isComingFromModal = isModalPresentation
        
        // Create the Nightscout button if the conditions are met
        if !isComingFromDetailView && !isComingFromFoodItemRow {
            
            // Create the "scope" button
            scopeButton = UIBarButtonItem(
                image: UIImage(systemName: "scope"),
                style: .plain,
                target: self,
                action: #selector(scopeButtonTapped)
            )
            
            if let nightscoutURL = UserDefaultsRepository.nightscoutURL, !nightscoutURL.isEmpty,
               let nightscoutToken = UserDefaultsRepository.nightscoutToken, !nightscoutToken.isEmpty {
                // Load the custom image and resize it to the appropriate navigation bar icon size
                if let nightscoutImage = UIImage(named: "nightscout")?.resized(to: CGSize(width: 28, height: 28)) {
                    nightscoutButton = UIBarButtonItem(
                        image: nightscoutImage,
                        style: .plain,
                        target: self,
                        action: #selector(openNightscoutFromChart)
                    )
                    // Set the right bar buttons with the desired order: Scope button, then Nightscout button
                    if let nightscoutButton = nightscoutButton, let scopeButton = scopeButton {
                        navigationItem.rightBarButtonItems = [nightscoutButton, scopeButton]
                                }
                }
            } else {
                // Optionally, handle missing Nightscout URL or token here (e.g., show an alert)
                print("Nightscout URL or token is missing")
            }
        } else {
            print("No navigationsbuttons added - Coming from mini modals")
        }
        
        if isModalPresentation {
            addCloseButton()
        } else {
            updateStats(for: nil)
        }
        
        // Continue setting up the rest of the views
        updateBackgroundForCurrentMode()
        setupSegmentedControlAndDatePickers()
        setupMealTimesSegmentedControl()
        setupSearchBar()
        setupStatsTableView()
        setupChartView()
        setupStatsView()
        setupActionButton()
        setupTimePickers()
        
        loadDefaultDates()
        setDefaultTimePickers()
        fetchMealHistories()
        
        statsTableView.separatorStyle = .singleLine
        statsTableView.separatorColor = UIColor.systemGray3.withAlphaComponent(1)
        
        // Set default mode to "Insikt livsmedel"
        switchMode(segmentedControl)
        
        // Add the chartLabel to the view
        self.view.addSubview(chartLabel)
        
        // Set up the constraints for the chartLabel
        NSLayoutConstraint.activate([
            chartLabel.topAnchor.constraint(equalTo: lineChartView.topAnchor, constant: 8),
            chartLabel.centerXAnchor.constraint(equalTo: lineChartView.centerXAnchor)
        ])
        
        
        // Delay performing the search until the data is fully loaded
        DispatchQueue.main.async {
            if let searchText = self.prepopulatedSearchText {
                self.searchBar.text = searchText
                self.selectedEntryName = searchText
                // Initialize with default text based on selectedEntryName
                if let entryName = self.selectedEntryName, !entryName.isEmpty {
                    self.chartLabel.text = entryName  // Use the selectedEntryName if it's not empty
                } else {
                    self.chartLabel.text = NSLocalizedString("", comment: "")
                }
                // Sync prepopulatedSearchText with selectedEntryName
                print("searchtext: \(searchText)")  // Now log it before performing the search
                self.performSearch(with: searchText)
            }
        }
        updateButtonStates() // Initialize buttons' state
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Check the variables and update the button title accordingly
        if isComingFromFoodItemRow {
            title = NSLocalizedString("Portionshistorik", comment: "Title for MealInsights screen when coming from fooditemrow")
            actionButton.setTitle(NSLocalizedString("Använd genomsnittlig portion", comment: "Default button label"), for: .normal)
        } else if isComingFromDetailView {
            title = NSLocalizedString("Insikter", comment: "Title for MealInsights screen")
            actionButton.setTitle(NSLocalizedString("+ Lägg till i måltid", comment: "Add to meal button label"), for: .normal)
        } else {
            // Fallback or default title, if neither condition is met
            title = NSLocalizedString("Insikter", comment: "Title for MealInsights screen")
            actionButton.setTitle(NSLocalizedString("Använd genomsnittlig portion", comment: "Default button label"), for: .normal)
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
        self.isComingFromFoodItemRow = false
        self.isComingFromDetailView = false
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Check if the user interface style (light/dark mode) has changed
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackgroundForCurrentMode()
        }
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
    
    // Update your setupChartView function to configure the LineChartView
    private func setupChartView() {
        // Initialize the LineChartView
        lineChartView = LineChartView()
        lineChartView.backgroundColor = UIColor.systemGray2.withAlphaComponent(0.2)
        lineChartView.layer.cornerRadius = 10
        lineChartView.clipsToBounds = true // Ensure content is clipped to rounded corners
        lineChartView.translatesAutoresizingMaskIntoConstraints = false
        lineChartView.delegate = self
        
        
        
        // Set the maxVisibleCount to 15 (or your desired number)
        lineChartView.maxVisibleCount = 15
        lineChartView.extraTopOffset = 30
        
        // Add it to your view
        view.addSubview(lineChartView)
        
        // Create constraints but don't activate them yet
        chartViewBottomConstraint = lineChartView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -162)
        
        NSLayoutConstraint.activate([
            lineChartView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            lineChartView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            lineChartView.heightAnchor.constraint(equalToConstant: 205),
        ])
        
        // Set the chart view delegate to self
        lineChartView.delegate = self
    }
    
    // Call this function after fetching data to populate the chart
    private func updateChartWithCarbsData(_ filteredMeals: [MealHistory]) {
        var carbsEntries: [ChartDataEntry] = []
        
        var minDate: TimeInterval = .greatestFiniteMagnitude
        var maxDate: TimeInterval = 0
        
        // Sort meals by date
        let sortedMeals = filteredMeals.sorted { $0.mealDate ?? Date() < $1.mealDate ?? Date() }
        
        for meal in sortedMeals {
            if let mealDate = meal.mealDate {
                let timeIntervalForXAxis = mealDate.timeIntervalSince1970
                let carbsValue = meal.totalNetCarbs
                
                minDate = min(minDate, timeIntervalForXAxis)
                maxDate = max(maxDate, timeIntervalForXAxis)
                
                // Attach the MealHistory object to the ChartDataEntry
                let carbsEntry = ChartDataEntry(x: timeIntervalForXAxis, y: carbsValue, data: meal)
                carbsEntries.append(carbsEntry)
            }
        }
        
        let carbsDataSet = LineChartDataSet(entries: carbsEntries, label: NSLocalizedString("Kolhydrater (g)", comment: "Carbohydrates"))
        carbsDataSet.colors = [.systemOrange]
        carbsDataSet.circleColors = [.systemOrange]
        carbsDataSet.circleHoleColor = .white
        carbsDataSet.circleRadius = 4.0
        carbsDataSet.lineWidth = 1
        carbsDataSet.axisDependency = .left
        carbsDataSet.drawValuesEnabled = false
        
        // Enable highlighting for the dataset
        carbsDataSet.highlightEnabled = true
        carbsDataSet.highlightColor = .label
        
        let chartData = LineChartData(dataSets: [carbsDataSet])
        
        let xAxis = lineChartView.xAxis
        xAxis.valueFormatter = DateValueFormatter()
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        
        let labelCount = calculateLabelCount(minDate: minDate, maxDate: maxDate)
        xAxis.setLabelCount(labelCount, force: true)
        
        // Re-enable granularity
        xAxis.granularity = 1  // 1 second
        xAxis.granularityEnabled = true
        
        xAxis.axisMinimum = minDate
        xAxis.axisMaximum = maxDate
        
        lineChartView.leftAxis.drawGridLinesEnabled = true
        lineChartView.leftAxis.axisMinimum = 0
        
        lineChartView.rightAxis.enabled = false
        lineChartView.rightAxis.drawGridLinesEnabled = false
        
        lineChartView.isUserInteractionEnabled = true
        lineChartView.dragEnabled = true
        lineChartView.setScaleEnabled(true)
        lineChartView.pinchZoomEnabled = true
        lineChartView.highlightPerDragEnabled = true
        lineChartView.highlightPerTapEnabled = true
        
        lineChartView.data = chartData
        
        let marker = TooltipMarkerView()
        marker.chartView = lineChartView
        lineChartView.marker = marker
        
        lineChartView.notifyDataSetChanged()
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        chartDataSelected = true // Set to true when a data point is selected
    }

    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        chartDataSelected = false // Set to false when no data point is selected
    }
    
    private func updateButtonStates() {
           if chartDataSelected {
               nightscoutButton?.isEnabled = true
               nightscoutButton?.tintColor = .label
               scopeButton?.isEnabled = true
               scopeButton?.tintColor = .label
           } else {
               nightscoutButton?.isEnabled = false
               nightscoutButton?.tintColor = .gray
               scopeButton?.isEnabled = false
               scopeButton?.tintColor = .gray
           }
       }
    
    private func updateChartWithPortionsData(entryId: UUID) {
        var portionEntries: [ChartDataEntry] = []
        
        var minDate: TimeInterval = .greatestFiniteMagnitude
        var maxDate: TimeInterval = 0
        
        // Filter matching entries based on the entryId and entryPortionServed > 0
        let matchingEntries = allFilteredFoodEntries.filter {
            $0.entryId == entryId && $0.entryPortionServed > 0
        }
        
        // Sort entries by meal date
        let sortedEntries = matchingEntries.sorted {
            guard let date1 = $0.mealHistory?.mealDate, let date2 = $1.mealHistory?.mealDate else { return false }
            return date1 < date2
        }
        
        for entry in sortedEntries {
            if let mealDate = entry.mealHistory?.mealDate {
                let timeIntervalForXAxis = mealDate.timeIntervalSince1970
                let portionValue = entry.entryPortionServed - entry.entryNotEaten
                
                minDate = min(minDate, timeIntervalForXAxis)
                maxDate = max(maxDate, timeIntervalForXAxis)
                
                // Attach the FoodItemEntry object to the ChartDataEntry
                let portionEntry = ChartDataEntry(x: timeIntervalForXAxis, y: portionValue, data: entry)
                portionEntries.append(portionEntry)
            }
        }
        
        // Check if there are entries to display
        if portionEntries.isEmpty {
            // Clear the chart if no data
            lineChartView.data = nil
            lineChartView.notifyDataSetChanged()
            return
        }
        
        let portionDataSet = LineChartDataSet(entries: portionEntries, label: NSLocalizedString("Portion uppäten", comment: "Portions"))
        portionDataSet.colors = [.systemBlue]
        portionDataSet.circleColors = [.systemBlue]
        portionDataSet.circleHoleColor = .white
        portionDataSet.circleRadius = 4.0
        portionDataSet.lineWidth = 0
        portionDataSet.axisDependency = .left
        portionDataSet.drawValuesEnabled = false
        
        // Enable highlighting for the dataset
        portionDataSet.highlightEnabled = true
        portionDataSet.highlightColor = .label
        
        // Set the data to the chart
        let chartData = LineChartData(dataSets: [portionDataSet])
        lineChartView.data = chartData
        
        // Configure the xAxis
        let xAxis = lineChartView.xAxis
        xAxis.valueFormatter = DateValueFormatter()
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        
        let labelCount = calculateLabelCount(minDate: minDate, maxDate: maxDate)
        xAxis.setLabelCount(labelCount, force: true)
        
        xAxis.granularity = 1  // 1 second
        xAxis.granularityEnabled = true
        
        xAxis.axisMinimum = minDate
        xAxis.axisMaximum = maxDate
        
        // Left axis configuration
        lineChartView.leftAxis.drawGridLinesEnabled = true
        lineChartView.leftAxis.axisMinimum = 0
        
        // Right axis configuration
        lineChartView.rightAxis.enabled = false
        
        // Chart interaction settings
        lineChartView.isUserInteractionEnabled = true
        lineChartView.dragEnabled = true
        lineChartView.setScaleEnabled(true)
        lineChartView.pinchZoomEnabled = true
        lineChartView.highlightPerDragEnabled = true
        lineChartView.highlightPerTapEnabled = true
        
        // Set the marker
        let marker = TooltipMarkerView()
        marker.chartView = lineChartView
        lineChartView.marker = marker
        
        // Refresh the chart
        lineChartView.notifyDataSetChanged()
    }
    
    private func calculateLabelCount(minDate: TimeInterval, maxDate: TimeInterval) -> Int {
        let totalSeconds = maxDate - minDate
        let days = totalSeconds / (24 * 60 * 60)
        
        // Choose a sensible label count based on the range (e.g., 7 labels per week)
        if days < 1 {
            return 7
        } else if days <= 7 {
            return 7
        } else if days <= 30 {
            return 7
        } else {
            return 7
        }
    }
    
    // Helper function to convert Date to a readable format for the X-axis
    class DateValueFormatter: AxisValueFormatter {
        private let dateFormatter = DateFormatter()
        
        init() {
            dateFormatter.dateFormat = "d MMM" // Customize the format
        }
        
        func stringForValue(_ value: Double, axis: AxisBase?) -> String {
            let date = Date(timeIntervalSince1970: value)
            return dateFormatter.string(from: date)
        }
    }
    
    @objc private func openNightscoutFromChart() {
        // Ensure there is a highlighted entry
        guard let highlight = lineChartView.highlighted.first else {
            let alert = UIAlertController(title: NSLocalizedString("Ingen data", comment: "Error"),
                                          message: NSLocalizedString("\nVälj en datapunkt i grafen nedan innan du öppnar Nightscout", comment: "No data selected."),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        // Retrieve the corresponding ChartDataEntry from the highlighted entry
        guard let dataSet = lineChartView.data?.dataSets[highlight.dataSetIndex],
              let entry = dataSet.entryForXValue(highlight.x, closestToY: highlight.y) as? ChartDataEntry else {
            let alert = UIAlertController(title: NSLocalizedString("Ingen data", comment: "Error"),
                                          message: NSLocalizedString("\nVälj en datapunkt i grafen nedan innan du öppnar Nightscout", comment: "No valid data selected."),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        var mealDate: Date?
        
        // Handle both MealHistory and FoodItemEntry types
        if let mealHistory = entry.data as? MealHistory {
            mealDate = mealHistory.mealDate
        } else if let foodEntry = entry.data as? FoodItemEntry {
            mealDate = foodEntry.mealHistory?.mealDate
        }
        
        // Ensure we have a valid date
        guard let date = mealDate else {
            let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Error"),
                                          message: NSLocalizedString("Ingen giltig data är vald.", comment: "No valid data selected."),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        // Continue with Nightscout URL construction
        guard let nightscoutBaseURL = UserDefaultsRepository.nightscoutURL,
              let nightscoutToken = UserDefaultsRepository.nightscoutToken else {
            let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Error"),
                                          message: NSLocalizedString("Nightscout-URL eller token saknas.", comment: "Nightscout URL or token is missing."),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        // Format the date for the Nightscout URL
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Ensure the base URL ends with '/'
        var baseURL = nightscoutBaseURL
        if !baseURL.hasSuffix("/") {
            baseURL += "/"
        }
        
        // Construct the URL with the token, report type, startDate, and endDate
        var urlComponents = URLComponents(string: baseURL + "report/")
        urlComponents?.queryItems = [
            URLQueryItem(name: "token", value: nightscoutToken),
            URLQueryItem(name: "report", value: "daytoday"),
            URLQueryItem(name: "startDate", value: dateString),
            URLQueryItem(name: "endDate", value: dateString),
            URLQueryItem(name: "autoShow", value: "true"),
            URLQueryItem(name: "hideMenu", value: "true"),
        ]
        
        if let url = urlComponents?.url {
            let nightscoutVC = NightscoutWebViewController()
            nightscoutVC.nightscoutURL = url
            nightscoutVC.mealDate = date
            nightscoutVC.hidesBottomBarWhenPushed = true
            
            // Use the modal presentation check
            if isModalPresentation {
                // If the MealInsightsViewController is presented modally, present NightscoutWebViewController in its own navigation controller
                let navigationController = UINavigationController(rootViewController: nightscoutVC)
                present(navigationController, animated: true, completion: nil)
            } else {
                // If it's not modal, push the NightscoutWebViewController onto the current navigation stack
                navigationController?.pushViewController(nightscoutVC, animated: true)
            }
        } else {
            let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Error"),
                                          message: NSLocalizedString("Kunde inte skapa Nightscout URL.", comment: "Could not create Nightscout URL."),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
    @objc private func scopeButtonTapped() {
        // Ensure there is a highlighted entry
        guard let highlight = lineChartView.highlighted.first else {
            let alert = UIAlertController(title: NSLocalizedString("Ingen data", comment: "Error"),
                                          message: NSLocalizedString("\nVälj en datapunkt i grafen nedan innan du fortsätter", comment: "No data selected."),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        // Retrieve the corresponding ChartDataEntry from the highlighted entry
        guard let dataSet = lineChartView.data?.dataSets[highlight.dataSetIndex],
              let entry = dataSet.entryForXValue(highlight.x, closestToY: highlight.y) as? ChartDataEntry else {
            let alert = UIAlertController(title: NSLocalizedString("Ingen data", comment: "Error"),
                                          message: NSLocalizedString("\nVälj en datapunkt i grafen nedan innan du fortsätter", comment: "No valid data selected."),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        var mealDate: Date?
        
        // Extract the mealDate from either MealHistory or FoodItemEntry
        if let mealHistory = entry.data as? MealHistory {
            mealDate = mealHistory.mealDate
        } else if let foodEntry = entry.data as? FoodItemEntry {
            mealDate = foodEntry.mealHistory?.mealDate
        }
        
        // Ensure we have a valid date
        guard let date = mealDate else {
            let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Error"),
                                          message: NSLocalizedString("Ingen giltig data är vald.", comment: "No valid data selected."),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        // Call a method to navigate to MealHistoryDetailViewController with the selected date
        navigateToMealHistoryDetail(with: date)
    }
    
    private func navigateToMealHistoryDetail(with mealDate: Date) {
        // Fetch the MealHistory entity that matches the mealDate
        let fetchRequest: NSFetchRequest<MealHistory> = MealHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "mealDate == %@", mealDate as NSDate)
        fetchRequest.fetchLimit = 1
        
        do {
            let mealHistories = try CoreDataStack.shared.context.fetch(fetchRequest)
            guard let mealHistory = mealHistories.first else {
                let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Error"),
                                              message: NSLocalizedString("Ingen måltid hittades för det valda datumet.", comment: "No meal found for the selected date."),
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
                return
            }
            
            // Initialize and present the MealHistoryDetailViewController
            let detailVC = MealHistoryDetailViewController()
            detailVC.mealHistory = mealHistory
            detailVC.hidesBottomBarWhenPushed = true
            
            // Use the modal presentation check
            if isModalPresentation {
                // If the MealInsightsViewController is presented modally, present MealHistoryDetailViewController in its own navigation controller
                let navigationController = UINavigationController(rootViewController: detailVC)
                present(navigationController, animated: true, completion: nil)
            } else {
                // If it's not modal, push the MealHistoryDetailViewController onto the current navigation stack
                navigationController?.pushViewController(detailVC, animated: true)
            }
            
        } catch {
            let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Error"),
                                          message: NSLocalizedString("Ett fel inträffade vid hämtning av måltid.", comment: "An error occurred while fetching the meal."),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
    private func setupSegmentedControlAndDatePickers() {
        // Configure From Date Picker and Label
        fromDateLabel.text = NSLocalizedString("Datum", comment: "From Date Label")
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
        toDateLabel.text = NSLocalizedString("→", comment: "To Date Label")
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
        datePickersStackView.axis = .horizontal
        datePickersStackView.spacing = 8
        datePickersStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Main segmented control
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.addTarget(self, action: #selector(switchMode(_:)), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        // Date preset segmented control
        datePresetsSegmentedControl.selectedSegmentIndex = 2 //UISegmentedControl.noSegment
        datePresetsSegmentedControl.addTarget(self, action: #selector(datePresetChanged(_:)), for: .valueChanged)
        datePresetsSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        // Combine the controls and stack views
        combinedStackView.axis = .vertical
        combinedStackView.spacing = isComingFromFoodItemRow || isComingFromDetailView ? 10 : 10  // Set initial spacing here
        combinedStackView.translatesAutoresizingMaskIntoConstraints = false
        combinedStackView.addArrangedSubview(segmentedControl)
        combinedStackView.addArrangedSubview(datePresetsSegmentedControl)
        combinedStackView.addArrangedSubview(datePickersStackView)
        
        // Add the combined stack view to the main view
        view.addSubview(combinedStackView)
        
        // Set constraints for the combined stack view
        NSLayoutConstraint.activate([
            combinedStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            combinedStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            combinedStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }
    
    
    // Action for date presets
    @objc private func datePresetChanged(_ sender: UISegmentedControl) {
        let now = Date()
        var fromDate: Date?
        
        switch sender.selectedSegmentIndex {
        case 0: // 3d
            fromDate = Calendar.current.date(byAdding: .day, value: -3, to: now)
        case 1: // 7d
            fromDate = Calendar.current.date(byAdding: .day, value: -7, to: now)
        case 2: // 30d
            fromDate = Calendar.current.date(byAdding: .day, value: -30, to: now)
        case 3: // 90d
            fromDate = Calendar.current.date(byAdding: .day, value: -90, to: now)
        case 4: // Allt - Get the earliest available date from mealHistories
            fromDate = mealHistories.map { $0.mealDate ?? now }.min() ?? now
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
                if let selectedEntryId = selectedEntryId {
                    // Re-run updateStats with the previously selected entryId
                    updateStats(for: selectedEntryId)
                }
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
            mealTimesSegmentedControl.topAnchor.constraint(equalTo: toDateLabel.bottomAnchor, constant: 10),
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
            setTimePickers(fromHour: 10, fromMinute: 0, toHour: 13, toMinute: 0)
        case 3: // Mellis
            setTimePickers(fromHour: 13, fromMinute: 0, toHour: 16, toMinute: 30)
        case 4: // Middag
            setTimePickers(fromHour: 16, fromMinute: 30, toHour: 20, toMinute: 0)
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
        fromTimeLabel.text = NSLocalizedString("Tid", comment: "From Time Label")
        fromTimeLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        fromTimeLabel.textColor = .label
        fromTimePicker.datePickerMode = .time
        fromTimePicker.preferredDatePickerStyle = .compact  // Set compact style to make it smaller
        fromTimePicker.addTarget(self, action: #selector(timeChanged), for: .valueChanged)
        fromTimePicker.translatesAutoresizingMaskIntoConstraints = false
        fromTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure "Till tid" label and picker
        toTimeLabel.text = NSLocalizedString("→", comment: "To Time Label")
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
        timePickersStackView.axis = .horizontal
        timePickersStackView.spacing = 8
        timePickersStackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(timePickersStackView)
        
        // Ensure proper constraints
        NSLayoutConstraint.activate([
            timePickersStackView.topAnchor.constraint(equalTo: mealTimesSegmentedControl.bottomAnchor, constant: 10),
            timePickersStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            timePickersStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
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
            resetStatsView()
            searchBar.isHidden = true
            searchBar.resignFirstResponder()
            statsTableView.isHidden = true
            lineChartView.isHidden = false
            fromTimePicker.isHidden = false
            toTimePicker.isHidden = false
            fromTimeLabel.isHidden = false
            toTimeLabel.isHidden = false
            mealTimesSegmentedControl.isHidden = false
            actionButton.isHidden = true
            segmentedControl.isHidden = false
            statsViewBottomConstraint.constant = -10
            chartLabel.isHidden = false
            
            // Modify spacing to 16 when in "Insikt måltider" mode
            combinedStackView.spacing = 10
            
            // Set the chartLabel text to "Registrerade måltider"
            chartLabel.text = NSLocalizedString("Registrerade måltider", comment: "Registered meals")
            
            calculateMealStats()
        } else {
            // "Insikt livsmedel" mode
            resetStatsView()
            fromTimePicker.isHidden = true
            toTimePicker.isHidden = true
            fromTimeLabel.isHidden = true
            toTimeLabel.isHidden = true
            mealTimesSegmentedControl.isHidden = true
            
            if isComingFromFoodItemRow || isComingFromDetailView {
                actionButton.isHidden = false
                segmentedControl.isHidden = true
                searchBar.isHidden = true
                statsTableView.isHidden = true
                lineChartView.isHidden = true
                statsViewBottomConstraint.constant = -72
                combinedStackView.spacing = 10
                chartLabel.isHidden = true
            } else {
                actionButton.isHidden = true
                segmentedControl.isHidden = false
                searchBar.isHidden = false
                statsTableView.isHidden = false
                lineChartView.isHidden = false
                statsViewBottomConstraint.constant = -10
                filterFoodEntries()
                chartLabel.isHidden = false
                
                if let selectedEntryId = selectedEntryId {
                    // Update the stats and change chartLabel to entryEmoji and entryName
                    updateStats(for: selectedEntryId)
                    if let entry = allFilteredFoodEntries.first(where: { $0.entryId == selectedEntryId }) {
                        let entryName = entry.entryName ?? ""
                        var entryEmoji = entry.entryEmoji ?? ""
                        entryEmoji = entryEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
                        entryEmoji = entryEmoji.precomposedStringWithCanonicalMapping
                        
                        // Set the chartLabel text to "\(entryEmoji) \(entryName)"
                        chartLabel.text = "\(entryEmoji) \(entryName)"
                    }
                } else {
                    updateStats(for: nil) // Pass nil if there's no selected entry
                }
                combinedStackView.spacing = 10
            }
            updateStatsTableConstraints()
        }
    }
    
    private func setupSearchBar() {
        // Add the already initialized searchBar to the view
        view.addSubview(searchBar)
        
        // Apply the constraints
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: toDateLabel.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBar.heightAnchor.constraint(equalToConstant: 44) // Adjust the height as necessary
        ])
        
        // Set the search bar delegate
        searchBar.delegate = self
    }
    
    @objc private func cancelButtonTapped() {
        // Dismiss the keyboard
        searchBar.resignFirstResponder()
    }
    
    @objc private func doneButtonTapped() {
        // Dismiss the keyboard
        searchBar.resignFirstResponder()
        
        // Set the search text as selectedEntryName
        if let searchText = searchBar.text, !searchText.isEmpty {
            selectedEntryName = searchText
        } else {
            selectedEntryName = nil // Reset if the search text is empty
        }
        
        // Perform the search with the current search text
        performSearch(with: searchBar.text ?? "")
    }
    
    private func findFoodItemById(entryId: UUID) -> FoodItem? {
        let context = CoreDataStack.shared.context
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        fetchRequest.predicate = NSPredicate(format: "id == %@", entryId as CVarArg)
        
        do {
            let foodItems = try context.fetch(fetchRequest)
            return foodItems.first
        } catch {
            print("Failed to fetch food item by id: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func performSearch(with searchText: String) {
        if isComingFromFoodItemRow {
            // Trim the search text to remove any leading/trailing whitespace
            let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            // Filter entries based on the trimmed search text
            self.filterFoodEntries()
            
            // Try to find the matching entry
            if let matchingEntry = allFilteredFoodEntries.first(where: {
                let trimmedEntryName = $0.entryName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                return trimmedEntryName == trimmedSearchText
            }) {
                print("Exact match found \(matchingEntry.entryName ?? "")")
                self.selectedEntryName = matchingEntry.entryName // Store the selected entry name
                self.selectedEntryId = matchingEntry.entryId // Store the entryId for further filtering
                
                // Update stats using entryId
                updateStats(for: matchingEntry.entryId)
            } else {
                print("No exact match found for \(searchText)")
                updateStats(for: nil) // Clear stats if no match
            }
        } else {
            // Execute the same search as when the user manually types into the search bar
            self.filterFoodEntries()
            
            if let selectedEntry = selectedEntryName {
                // Use the stored entry name to update stats
                if let matchingEntry = allFilteredFoodEntries.first(where: { $0.entryName?.lowercased() == selectedEntry.lowercased() }) {
                    self.selectedEntryId = matchingEntry.entryId // Update the selected entryId for the matched name
                    updateStats(for: matchingEntry.entryId)
                } else {
                    updateStats(for: nil) // No match, clear stats
                }
            } else {
                if searchBar.text?.isEmpty ?? true {
                    self.selectedEntryName = nil // Reset the selected entry if search is cleared
                    print("Search text is empty, no match found")
                    updateStats(for: nil) // Clear stats
                }
            }
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
        view.addSubview(statsView)
        
        // Create constraints but don't activate them yet
        statsTableTopConstraint = statsTableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor)
        statsTableBottomConstraint = statsTableView.bottomAnchor.constraint(equalTo: statsView.topAnchor, constant: -226)
        
        // Other necessary constraints
        NSLayoutConstraint.activate([
            statsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Optionally, activate the constraints based on isComingFromFoodItemRow
        updateStatsTableConstraints()
    }
    
    // Method to enable or disable the constraints dynamically
    private func updateStatsTableConstraints() {
        if isComingFromFoodItemRow || isComingFromDetailView {
            // Disable top and bottom constraints to make space in the smaller modal
            statsTableTopConstraint?.isActive = false
            statsTableBottomConstraint?.isActive = false
            chartViewBottomConstraint?.isActive = false
        } else {
            // Enable the top and bottom constraints for the full view
            statsTableTopConstraint?.isActive = true
            statsTableBottomConstraint?.isActive = true
            chartViewBottomConstraint?.isActive = true
        }
        
        // Force layout update after changing constraints
        view.layoutIfNeeded()
    }
    
    private func setupStatsView() {
        statsView.backgroundColor = UIColor.systemGray2.withAlphaComponent(0.2)
        statsView.layer.cornerRadius = 10
        statsView.translatesAutoresizingMaskIntoConstraints = false
        
        statsLabel.numberOfLines = 0
        statsLabel.textAlignment = .center
        statsView.addSubview(statsLabel)
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(statsView)
        
        // Set the initial constraint for statsView
        statsViewBottomConstraint = statsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -76)
        
        NSLayoutConstraint.activate([
            statsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statsViewBottomConstraint, // Activate the initial bottom constraint
            statsView.heightAnchor.constraint(equalToConstant: 135),
            
            statsLabel.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 4),
            statsLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -16),
            statsLabel.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: -4)
        ])
    }
    
    private func resetStatsView() {
        statsLabel.text = ""  // Clear the stats view
    }
    
    private func setupActionButton() {
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        // Add the button to the view
        view.addSubview(actionButton)
        
        // Set the constraints
        NSLayoutConstraint.activate([
            actionButton.leadingAnchor.constraint(equalTo: statsView.leadingAnchor), // Match statsView's leading
            actionButton.trailingAnchor.constraint(equalTo: statsView.trailingAnchor), // Match statsView's trailing
            actionButton.topAnchor.constraint(equalTo: statsView.bottomAnchor, constant: 10),
            actionButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func loadDefaultDates() {
        let now = Date()
        
        // Set the default to 30d
        let fromDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        
        fromDatePicker.date = fromDate
        toDatePicker.date = now
        
        // Now, trigger the date change logic
        datePresetChanged(UISegmentedControl()) // Simulate the preset change to "30d"
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
            updateStats(for: nil)
        } else if segmentedControl.selectedSegmentIndex == 0 {
            // Case: "Insikt måltider"
            calculateMealStats()
        }
    }
    
    private func filterFoodEntries() {
        let fromDate = fromDatePicker.date
        let toDate = toDatePicker.date
        let searchText = searchBar.text?.lowercased() ?? ""
        
        let filteredHistories = mealHistories.filter {
            guard let mealDate = $0.mealDate else { return false }
            return mealDate >= fromDate && mealDate <= toDate
        }
        
        // Collect all entries for calculation (including duplicates) and exclude those with entryPortionServed == 0
        allFilteredFoodEntries = filteredHistories.flatMap { history in
            (history.foodEntries?.allObjects as? [FoodItemEntry] ?? []).filter { $0.entryPortionServed > 0 }
        }
        
        // Use a set to filter unique food item IDs for display
        var uniqueFoodIdsSet = Set<UUID>()
        uniqueFoodEntries = allFilteredFoodEntries.filter { entry in
            guard let entryId = entry.entryId else { return false }
            let entryNameLowercased = entry.entryName?.lowercased() ?? ""
            if entryNameLowercased.contains(searchText) && !uniqueFoodIdsSet.contains(entryId) {
                uniqueFoodIdsSet.insert(entryId)
                return true
            }
            return false
        }.map { entry -> FoodEntryInfo in
            let entryName = entry.entryName ?? ""
            let entryId = entry.entryId
            return FoodEntryInfo(entryName: entryName, entryId: entryId, isPlaceholder: false)
        }
        
        // If no food items are found, insert a placeholder
        if uniqueFoodEntries.isEmpty {
            uniqueFoodEntries.append(FoodEntryInfo(
                entryName: NSLocalizedString("Inga sökträffar inom valt datumintervall", comment: "No search results found in the selected date range"),
                entryId: nil,
                isPlaceholder: true
            ))
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
        
        // Update the chart with filtered data
        updateChartWithCarbsData(filteredMeals)
        
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
        
        // Define font sizes
        let headlineFontSize: CGFloat = 15
        let regularFontSize: CGFloat = 14
        
        // Bold the first line ("Medianvärden i måltider"), center-aligned
        let boldText = "\(NSLocalizedString("Medianvärden måltider (Datum och tid)", comment: "Medians"))\n\n"
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: headlineFontSize),
            .paragraphStyle: centeredParagraphStyle()
        ]
        statsText.append(NSAttributedString(string: boldText, attributes: boldAttributes))
        
        // Create a tab stop for aligning text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: 300)]
        paragraphStyle.defaultTabInterval = 300
        paragraphStyle.alignment = .center
        
        // Use the helper function to format stats values, replacing Inf or 0 with empty string
        let formattedMedianCarbs = formatStatValue(medianCarbs, format: "%.0f g")
        let formattedMedianFat = formatStatValue(medianFat, format: "%.0f g")
        let formattedMedianProtein = formatStatValue(medianProtein, format: "%.0f g")
        let formattedMedianBolus = formatStatValue(medianBolus, format: "%.2f E")
        let formattedInsulinRatio = formatStatValue(insulinRatio, format: "%.0f g/E")
        
        // Regular text for the stats, left-aligned labels and right-aligned values
        let regularText = """
        \(NSLocalizedString("Kolhydrater", comment: "Median Carbs")):\t\(formattedMedianCarbs)
        \(NSLocalizedString("Fett", comment: "Median Fat")):\t\(formattedMedianFat)
        \(NSLocalizedString("Protein", comment: "Median Protein")):\t\(formattedMedianProtein)
        \(NSLocalizedString("Bolus", comment: "Median Bolus")):\t\(formattedMedianBolus)
        \(NSLocalizedString("Verklig insulinkvot", comment: "Actual Insulin Ratio")):\t\(formattedInsulinRatio)
        """
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: regularFontSize),
            .paragraphStyle: paragraphStyle
        ]
        statsText.append(NSAttributedString(string: regularText, attributes: regularAttributes))
        
        // Assign the attributed text to the label
        statsLabel.attributedText = statsText
    }
    
    // Helper function to center-align text for the title
    private func centeredParagraphStyle() -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        return paragraphStyle
    }
    
    private func formatStatValue(_ value: Double, format: String) -> String {
        if value.isNaN || value.isInfinite || value == 0 {
            return "" // Return an empty string for NaN, Inf, or 0
        }
        return String(format: format, value)
    }
    
    // Food item calculations (MEDIAN VALUE VERSION)
    private func updateStats(for entryId: UUID?) {
        guard let entryId = entryId else {
            // Reset stats if no entryId
            statsLabel.text = NSLocalizedString("Välj datum och ett livsmedel för att visa mer information", comment: "Placeholder text for no selection")
            //self.chartLabel.text = NSLocalizedString("Välj datum och ett livsmedel", comment: "Placeholder text for no selection")
            self.chartLabel.text = NSLocalizedString(" ", comment: "Placeholder text for no selection")
            
            // Safely unwrap lineChartView
            if let chartView = lineChartView {
                // Clear the chart
                chartView.data = nil
                chartView.notifyDataSetChanged()
            } else {
                print("lineChartView is nil")
            }
            return
        }
        
        // Filter matching entries based on the entryId and entryPortionServed > 0
        let matchingEntries = allFilteredFoodEntries.filter {
            $0.entryId == entryId && $0.entryPortionServed > 0
        }
        
        // Get the entryName and entryEmoji from the first matching entry, or default to empty string if no entries are found
        let entryName = matchingEntries.first?.entryName ?? ""
        var entryEmoji = matchingEntries.first?.entryEmoji ?? ""
        
        // Clean up the emoji string by trimming unnecessary whitespace or newlines
        entryEmoji = entryEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Normalize the emoji string to avoid formatting issues
        entryEmoji = entryEmoji.precomposedStringWithCanonicalMapping
        
        // Determine if the portions are measured in pieces or grams
        let isPerPiece = matchingEntries.first?.entryPerPiece ?? false
        
        let timesServed = matchingEntries.count
        let portions = matchingEntries.map { $0.entryPortionServed - $0.entryNotEaten }
        
        // Calculate the median portion safely, handling cases with 0 or 1 portion
        let medianPortion: Double
        if portions.isEmpty {
            medianPortion = 0  // No entries, return 0 or a default value
        } else if portions.count == 1 {
            medianPortion = portions.first!  // Only one portion, return that
        } else {
            let sortedPortions = portions.sorted()
            if sortedPortions.count % 2 == 0 {
                // If even, average the two middle values
                medianPortion = (sortedPortions[sortedPortions.count / 2 - 1] + sortedPortions[sortedPortions.count / 2]) / 2.0
            } else {
                // If odd, take the middle value
                medianPortion = sortedPortions[sortedPortions.count / 2]
            }
        }
        
        let largestPortion = portions.max() ?? 0.0
        let smallestPortion = portions.min() ?? 0.0
        
        // Format based on whether it's measured in pieces or grams
        let portionFormat = isPerPiece ? NSLocalizedString("%.1f st", comment: "Per piece portion format") : NSLocalizedString("%.0f g", comment: "Grams portion format")
        
        // Create an attributed string to apply different styles
        let statsText = NSMutableAttributedString()
        
        // Define font sizes
        let headlineFontSize: CGFloat = 15
        let regularFontSize: CGFloat = 14
        
        // Check if entryName and entryEmoji are empty, then use placeholder text
        let boldText: String
        if entryName.isEmpty && entryEmoji.isEmpty {
            if isComingFromModal {
                let searchText = prepopulatedSearchText ?? NSLocalizedString("det valda livsmedlet", comment: "Default text for selected food item")
                boldText = String(format: NSLocalizedString("Ingen måltidshistorik tillgänglig för\n\"%@\"", comment: "Placeholder text for no selection"), searchText)
                actionButton.isEnabled = false
                actionButton.backgroundColor = .systemGray
                if !isComingFromDetailView && !isComingFromFoodItemRow {
                    self.chartLabel.text = NSLocalizedString("Välj datum och ett livsmedel", comment: "Placeholder text for no selection")
                }
            } else {
                boldText = NSLocalizedString("Välj datum och ett livsmedel för att visa mer information", comment: "Placeholder text for no selection")
                self.chartLabel.text = NSLocalizedString("Välj datum och ett livsmedel", comment: "Placeholder text for no selection")
            }
        } else {
            boldText = "\(entryEmoji) \(entryName)\n\n"
            self.chartLabel.text = "\(entryEmoji) \(entryName)"
        }
        
        // Bold the first line (either entryName and entryEmoji or placeholder), center-aligned
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: headlineFontSize),
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
            
            // Use the helper function to format stats values, replacing 0 or NaN with empty string
            let formattedMedianPortion = formatStatValue(medianPortion, format: portionFormat)
            let formattedLargestPortion = formatStatValue(largestPortion, format: portionFormat)
            let formattedSmallestPortion = formatStatValue(smallestPortion, format: portionFormat)
            
            // Regular text for the stats
            let regularText = """
            \(NSLocalizedString("Genomsnittlig portion", comment: "Median portion label")):\t\(formattedMedianPortion)
            \(NSLocalizedString("Största portion", comment: "Largest portion label")):\t\(formattedLargestPortion)
            \(NSLocalizedString("Minsta portion", comment: "Smallest portion label")):\t\(formattedSmallestPortion)
            \(NSLocalizedString("Serverats antal gånger", comment: "Times served label")):\t\(timesServed)
             
            """
            let regularAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: regularFontSize),
                .paragraphStyle: paragraphStyle
            ]
            statsText.append(NSAttributedString(string: regularText, attributes: regularAttributes))
        }
        
        // After calculating stats, update the chart
        updateChartWithPortionsData(entryId: entryId)
        
        // Assign the attributed text to the label
        statsLabel.attributedText = statsText
    }
    
    
    @objc private func actionButtonTapped() {
        guard let entryName = searchBar.text, !entryName.isEmpty else {
            return
        }
        
        if isComingFromDetailView {
            // Attempt to find the corresponding FoodItem by entryId and save it as a FoodItemTemporary
            if let foodEntry = selectedFoodEntry, let entryId = foodEntry.entryId {
                saveFoodItemTemporary(entryId: entryId)
                
                // Dismiss the modal and show the success view after dismissal
                self.dismiss(animated: true) {
                    let successView = SuccessView()
                    
                    // Use the key window for showing the success view
                    if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                        successView.showInView(keyWindow)
                    }
                }
                
                self.isComingFromDetailView = false
            } else {
                // No match found, show an alert
                showFoodItemNotAvailableAlert()
            }
            
            return
        }
        
        // Original logic for handling the action button, if applicable
        let medianPortion = calculateMedianPortion(for: entryName)
        
        if let onAveragePortionSelected = self.onAveragePortionSelected {
            onAveragePortionSelected(medianPortion)
        }
        
        self.dismiss(animated: true, completion: nil)
        self.isComingFromFoodItemRow = false
    }
    
    // Helper function to save the FoodItemTemporary entry with only entryId
    private func saveFoodItemTemporary(entryId: UUID) {
        let context = CoreDataStack.shared.context
        let newFoodItemTemporary = FoodItemTemporary(context: context)
        newFoodItemTemporary.entryId = entryId
        
        do {
            try context.save()
            print("FoodItemTemporary entry saved successfully for entryId: \(entryId)")
        } catch {
            print("Failed to save FoodItemTemporary entry: \(error)")
        }
    }
    
    // Helper function to show the "missing food item" alert
    private func showFoodItemNotAvailableAlert() {
        let alert = UIAlertController(
            title: NSLocalizedString("Saknas i databas", comment: "Missing in database"),
            message: NSLocalizedString("Livsmedlet du försöker lägga till från historiken finns inte längre tillgänglig i databasen", comment: "Food item no longer available"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func addToComposeMealViewController(foodItem: FoodItem) {
        guard let tabBarController = tabBarController else {
            print("Tab bar controller not found")
            return
        }
        
        for viewController in tabBarController.viewControllers ?? [] {
            if let navController = viewController as? UINavigationController {
                for vc in navController.viewControllers {
                    if let composeMealVC = vc as? ComposeMealViewController {
                        // Use the delegate to pass the food item
                        composeMealVC.didAddFoodItem(foodItem)
                        return
                    }
                }
            }
        }
    }
    
    private func calculateMedianPortion(for entryName: String) -> Double {
        // Filter matching entries where the entryName matches and entryPortionServed is greater than 0
        let matchingEntries = allFilteredFoodEntries.filter {
            $0.entryName?.lowercased() == entryName.lowercased() && $0.entryPortionServed > 0
        }
        
        // Map the portion sizes (served - not eaten) for the matching entries
        let portions = matchingEntries.map { $0.entryPortionServed - $0.entryNotEaten }
        
        // Handle cases where no portions are available
        guard !portions.isEmpty else {
            return 0 // No entries, return 0 or any suitable default value
        }
        
        // If only one portion is available, return it as the median
        if portions.count == 1 {
            return portions.first!
        }
        
        // Calculate the median portion
        let sortedPortions = portions.sorted()
        let medianPortion: Double
        if sortedPortions.count % 2 == 0 {
            // If even, average the two middle values
            medianPortion = (sortedPortions[sortedPortions.count / 2 - 1] + sortedPortions[sortedPortions.count / 2]) / 2.0
        } else {
            // If odd, take the middle value
            medianPortion = sortedPortions[sortedPortions.count / 2]
        }
        
        return medianPortion
    }
    
}
extension MealInsightsViewController: UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - UITableViewDataSource Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return uniqueFoodEntries.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "StatsCell", for: indexPath)
        let foodEntryInfo = uniqueFoodEntries[indexPath.row]
        let foodEntryName = foodEntryInfo.entryName
        
        // Custom selection color
        let customSelectionColor = UIView()
        customSelectionColor.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        cell.selectedBackgroundView = customSelectionColor
        
        // If it's the placeholder row, customize it
        if foodEntryInfo.isPlaceholder {
            cell.textLabel?.textColor = .systemGray
            cell.textLabel?.font = UIFont.italicSystemFont(ofSize: 16)
            cell.selectionStyle = .none
            cell.selectedBackgroundView = nil
        } else {
            cell.textLabel?.textColor = .label
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
            cell.selectionStyle = .default
        }
        
        cell.textLabel?.text = foodEntryName
        cell.backgroundColor = .clear
        return cell
    }
    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedFoodEntry = uniqueFoodEntries[indexPath.row]
        
        // Prevent selection if the placeholder is being shown
        if selectedFoodEntry.isPlaceholder {
            return
        }
        
        searchBar.resignFirstResponder()
        
        // Store the selected entry name
        self.selectedEntryName = selectedFoodEntry.entryName
        
        // Store the corresponding entryId
        selectedEntryId = selectedFoodEntry.entryId
        
        // Perform the updateStats with the entryId
        updateStats(for: selectedEntryId)
    }
}

extension MealInsightsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterFoodEntries()
        
        if searchBar.text?.isEmpty ?? true {
            selectedEntryName = nil // Reset the selected entry if search is cleared
            updateStats(for: nil)
        }
        performSearch(with: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Dismiss the keyboard when the search button is clicked
        searchBar.resignFirstResponder()
        
        // Set the search text as selectedEntryName
        if let searchText = searchBar.text, !searchText.isEmpty {
            selectedEntryName = searchText
        } else {
            selectedEntryName = nil // Reset if the search text is empty
        }
        
        // Perform the search with the current search text
        performSearch(with: searchBar.text ?? "")
    }
}

protocol MealInsightsDelegate: AnyObject {
    func didAddFoodItem(_ foodItem: FoodItem)
}

struct FoodEntryInfo {
    let entryName: String
    let entryId: UUID?
    let isPlaceholder: Bool
}

// Helper function to resize the image
extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}
