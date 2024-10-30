import UIKit
import WebKit

class MealHistoryDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, WKNavigationDelegate {
    
    var mealHistory: MealHistory?
    
    // Summary labels
    var totalBolusAmountLabel: UILabel!
    var totalNetCarbsLabel: UILabel!
    var totalNetFatLabel: UILabel!
    var totalNetProteinLabel: UILabel!
    
    // Container views for bolus, fat, protein, and carbs
    var bolusContainer: UIView!
    var fatContainer: UIView!
    var proteinContainer: UIView!
    var carbsContainer: UIView!
    
    // TableView for food entries
    var tableView: UITableView!
    
    // Buttons
    private var actionButton: UIButton!
    //private var nightscoutButton: UIButton!
    
    // Nightscout
    private var nightscoutChartView: UIView!
    private var webView: WKWebView!
    private var tableViewBottomConstraint: NSLayoutConstraint!
    private var summaryContainer: UIView!
    
    // Overlay and Activity Indicator
    private var overlayView: UIView!
    private var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM HH:mm"
        let mealTimeStr = dateFormatter.string(from: mealHistory?.mealDate ?? Date())
        
        title = String(format: NSLocalizedString("Måltid %@", comment: "Meal time format"), mealTimeStr)
        
        view.backgroundColor = .systemBackground
        
        // Check if the view controller is presented modally and add a close button
        if isModalPresentation {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closeButtonTapped)
            )
        }
        
        // Check if the app is in dark mode and set the background accordingly
        updateBackgroundForCurrentMode()
        
        setupSummaryView()
        setupActionButton()
        setupNightscoutChartView()
        setupTableView()
        
        // Check if Nightscout URL and token are available
        if let nightscoutURL = UserDefaultsRepository.nightscoutURL, !nightscoutURL.isEmpty,
           let nightscoutToken = UserDefaultsRepository.nightscoutToken, !nightscoutToken.isEmpty {
            nightscoutChartView.isHidden = false

            // Update the tableView's bottom constraint
            tableViewBottomConstraint.isActive = false
            tableViewBottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -250)
            tableViewBottomConstraint.isActive = true

            view.layoutIfNeeded()

            loadNightscoutChart()
        } else {
            nightscoutChartView.isHidden = true

            // Update the tableView's bottom constraint
            tableViewBottomConstraint.isActive = false
            tableViewBottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -82)
            tableViewBottomConstraint.isActive = true

            view.layoutIfNeeded()
        }
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
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    private var isModalPresentation: Bool {
        return presentingViewController != nil ||
               navigationController?.presentingViewController?.presentedViewController == navigationController ||
               tabBarController?.presentingViewController is UITabBarController
    }
    
    private func setupSummaryView() {
        summaryContainer = UIView()
        summaryContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(summaryContainer)
        
        // Create and add the container views
        bolusContainer = createContainerView(backgroundColor: .systemIndigo)
        totalBolusAmountLabel = createLabel(text: formatBolusAmount(mealHistory?.totalNetBolus ?? 0, unit: "E"))
        setupContainer(bolusContainer, title: "BOLUS", valueLabel: totalBolusAmountLabel)
        
        fatContainer = createContainerView(backgroundColor: .systemBrown)
        totalNetFatLabel = createLabel(text: formatAmount(mealHistory?.totalNetFat ?? 0, unit: "g"))
        setupContainer(fatContainer, title: "FETT", valueLabel: totalNetFatLabel)
        
        proteinContainer = createContainerView(backgroundColor: .systemBrown)
        totalNetProteinLabel = createLabel(text: formatAmount(mealHistory?.totalNetProtein ?? 0, unit: "g"))
        setupContainer(proteinContainer, title: "PROTEIN", valueLabel: totalNetProteinLabel)
        
        carbsContainer = createContainerView(backgroundColor: .systemOrange)
        totalNetCarbsLabel = createLabel(text: formatAmount(mealHistory?.totalNetCarbs ?? 0, unit: "g"))
        setupContainer(carbsContainer, title: "KOLHYDRATER", valueLabel: totalNetCarbsLabel)
        
        // Add all containers into a horizontal stack
        let hStack = UIStackView(arrangedSubviews: [bolusContainer, fatContainer, proteinContainer, carbsContainer])
        hStack.axis = .horizontal
        hStack.spacing = 8
        hStack.distribution = .fillEqually
        hStack.translatesAutoresizingMaskIntoConstraints = false
        
        summaryContainer.addSubview(hStack)
        
        NSLayoutConstraint.activate([
            summaryContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            summaryContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            hStack.leadingAnchor.constraint(equalTo: summaryContainer.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: summaryContainer.trailingAnchor),
            hStack.topAnchor.constraint(equalTo: summaryContainer.topAnchor),
            hStack.bottomAnchor.constraint(equalTo: summaryContainer.bottomAnchor),
            summaryContainer.heightAnchor.constraint(equalToConstant: 45)
        ])
    }

    
    private func setupContainer(_ container: UIView, title: String, valueLabel: UILabel) {
        let titleLabel = createLabel(text: NSLocalizedString(title, comment: title), fontSize: 9, weight: .bold, color: .white)
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }

    private func createContainerView(backgroundColor: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = backgroundColor
        container.layer.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }
    
    private func createLabel(text: String, fontSize: CGFloat = 18, weight: UIFont.Weight = .bold, color: UIColor = .white) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func formatAmount(_ amount: Double, unit: String) -> String {
        return String(format: "%.0f %@", amount, unit) // Always show 0 decimals
    }
    
    private func formatBolusAmount(_ amount: Double, unit: String) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f %@", amount, unit) // No decimals for whole numbers
        } else if amount * 10 == floor(amount * 10) {
            return String(format: "%.1f %@", amount, unit) // 1 decimal place if there is only one non-zero decimal
        } else {
            return String(format: "%.2f %@", amount, unit) // 2 decimal places otherwise
        }
    }
    
    private func formatGramsAmount(_ amount: Double) -> String {
        return String(format: "%.0f", amount) // Always 0 decimals
    }
    
    private func formatPPAmount(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount) // No decimals if whole number
        } else {
            return String(format: "%.1f", amount) // 1 decimal otherwise
        }
    }
    
    private func setupNightscoutChartView() {
        nightscoutChartView = UIView()
        nightscoutChartView.translatesAutoresizingMaskIntoConstraints = false
        nightscoutChartView.layer.cornerRadius = 10
        nightscoutChartView.clipsToBounds = true
        nightscoutChartView.isHidden = true  // Initially hidden

        // Initialize the web view
        webView = WKWebView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.isUserInteractionEnabled = false
        nightscoutChartView.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: nightscoutChartView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: nightscoutChartView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: nightscoutChartView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: nightscoutChartView.bottomAnchor)
        ])

        // Initialize and add the overlay view
        overlayView = UIView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = .white
        overlayView.layer.cornerRadius = 10
        overlayView.clipsToBounds = true
        nightscoutChartView.addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: nightscoutChartView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: nightscoutChartView.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: nightscoutChartView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: nightscoutChartView.bottomAnchor)
        ])

        // Initialize and add the nightscout image view
        let imageView = UIImageView(image: UIImage(named: "nightscout")?.withRenderingMode(.alwaysTemplate))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray
        overlayView.addSubview(imageView)

        // Initialize and add the activity indicator
        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .systemGray
        activityIndicator.startAnimating()
        overlayView.addSubview(activityIndicator)

        let fetchingLabel = UILabel()
        fetchingLabel.translatesAutoresizingMaskIntoConstraints = false
        fetchingLabel.text = NSLocalizedString("Hämtar rapport", comment: "Fetching report text")
        fetchingLabel.textAlignment = .center
        fetchingLabel.textColor = .systemGray

        // Use a rounded font if available
        let systemFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            fetchingLabel.font = UIFont(descriptor: roundedDescriptor, size: 14)
        } else {
            fetchingLabel.font = systemFont
        }

        overlayView.addSubview(fetchingLabel)

        // Add constraints for image, activity indicator, and label
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            imageView.bottomAnchor.constraint(equalTo: activityIndicator.topAnchor, constant: -12),
            imageView.heightAnchor.constraint(equalToConstant: 45), // Adjust size as needed
            
            activityIndicator.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: 20),
            
            fetchingLabel.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            fetchingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8)
        ])

        // Add the nightscoutChartView to the view hierarchy
        view.addSubview(nightscoutChartView)

        // Set up constraints for the nightscoutChartView
        NSLayoutConstraint.activate([
            nightscoutChartView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nightscoutChartView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nightscoutChartView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -82),
            nightscoutChartView.heightAnchor.constraint(equalToConstant: 160)
        ])
        
        // Add a tap gesture recognizer to the nightscoutChartView
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openNightscout))
        nightscoutChartView.addGestureRecognizer(tapGesture)
    }


    
    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MealHistoryCell")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: summaryContainer.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Set the initial bottom constraint
        tableViewBottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -82)
        tableViewBottomConstraint.isActive = true
    }


    // MARK: - UITableView DataSource and Delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mealHistory?.foodEntries?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MealHistoryCell", for: indexPath)
        
        if let foodEntries = mealHistory?.foodEntries?.allObjects as? [FoodItemEntry] {
            let foodEntry = foodEntries[indexPath.row]
            
            // Create food name label
            let foodNameLabel = UILabel()
            foodNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            foodNameLabel.text = foodEntry.entryName
            
            // Create details label (smaller, gray text)
            let foodDetailLabel = UILabel()
            foodDetailLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            foodDetailLabel.textColor = .gray
            foodDetailLabel.text = formatFoodEntry(foodEntry)
            
            
            // Setup stack view to hold both labels
            let stackView = UIStackView(arrangedSubviews: [foodNameLabel, foodDetailLabel])
            stackView.axis = .vertical
            stackView.spacing = 2
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            // Add stack view to the cell's content view
            cell.contentView.addSubview(stackView)
            cell.backgroundColor = .clear
            
            // Custom selection color
            let customSelectionColor = UIView()
            customSelectionColor.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            cell.selectedBackgroundView = customSelectionColor
            
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                stackView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                stackView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                stackView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
        }
        
        return cell
    }

    // Handle row selection to present MealInsightsViewController
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let foodEntries = mealHistory?.foodEntries?.allObjects as? [FoodItemEntry] else {
            return
        }
        let foodEntry = foodEntries[indexPath.row]
        
        presentMealInsightsViewController(with: foodEntry)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }


    // Present MealInsightsViewController
    private func presentMealInsightsViewController(with foodEntry: FoodItemEntry) {
        let mealInsightsVC = MealInsightsViewController()

        // Pass the foodEntry to MealInsightsViewController
        mealInsightsVC.prepopulatedSearchText = foodEntry.entryName ?? ""
        mealInsightsVC.isComingFromDetailView = true
        mealInsightsVC.selectedFoodEntry = foodEntry  // Pass the foodEntry with entryId

        // Present MealInsightsViewController in a sheet
        let navController = UINavigationController(rootViewController: mealInsightsVC)
        navController.modalPresentationStyle = .pageSheet

        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.preferredCornerRadius = 24
        }

        present(navController, animated: true, completion: nil)
    }
    
    // MARK: - Open Nightscout Action
    
    @objc private func openNightscout() {
        guard let nightscoutBaseURL = UserDefaultsRepository.nightscoutURL,
              let nightscoutToken = UserDefaultsRepository.nightscoutToken,
              let mealDate = mealHistory?.mealDate else {
            let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Error"),
                                          message: NSLocalizedString("Nightscout-URL eller token är inte angiven. Gå till inställningar för att ange dem.", comment: "Nightscout URL or token not set. Please set them in settings."),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        // Format the date for the Nightscout URL
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: mealDate)
        
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
            nightscoutVC.mealDate = mealDate
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
    
    private func loadNightscoutChart() {
        guard let nightscoutBaseURL = UserDefaultsRepository.nightscoutURL,
              let nightscoutToken = UserDefaultsRepository.nightscoutToken,
              let mealDate = mealHistory?.mealDate else {
            print("Nightscout URL, token, or meal date is missing.")
            return
        }

        // Format the date for the Nightscout URL
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: mealDate)

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
            URLQueryItem(name: "hideStats", value: "true"),
        ]

        if let url = urlComponents?.url {
            // Load the URL in the webView
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            webView.load(request)
        } else {
            print("Could not create Nightscout URL.")
        }
    }



    private func setupActionButton() {
        let actionButton = UIButton(type: .system)
        actionButton.setTitle(NSLocalizedString("Servera hela måltiden igen", comment: "Serve the same meal again"), for: .normal)

        let systemFont = UIFont.systemFont(ofSize: 19, weight: .semibold)
        if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            actionButton.titleLabel?.font = UIFont(descriptor: roundedDescriptor, size: 19)
        } else {
            actionButton.titleLabel?.font = systemFont
        }

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
            return
        }

        // Check if presented modally
        if isModalPresentation {
            // Save food items to Core Data as FoodItemTemporary entities when presented modally
            saveFoodItemsTemporary(from: mealHistory)
            
            // Show the success view after saving the food items
            let successView = SuccessView()
            
            // Use the key window for showing the success view
            if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                successView.showInView(keyWindow)
            }
            
            // Dismiss the view after showing the success view
            dismiss(animated: true, completion: nil)
            
        } else {
            // Handle the flow when not presented modally
            if let navigationController = navigationController,
               let composeMealVC = navigationController.viewControllers.first(where: { $0 is ComposeMealViewController }) as? ComposeMealViewController {
                
                composeMealVC.checkAndHandleExistingMeal(
                    replacementAction: {
                        composeMealVC.addMealHistory(mealHistory)
                    },
                    additionAction: {
                        composeMealVC.addMealHistory(mealHistory)
                    },
                    completion: {
                        navigationController.popToViewController(composeMealVC, animated: true)
                    }
                )
            } else {
                // If no existing instance found, instantiate a new one
                let composeMealVC = ComposeMealViewController()
                composeMealVC.addMealHistory(mealHistory)
                navigationController?.pushViewController(composeMealVC, animated: true)
            }
        }
    }
    
    private func saveFoodItemsTemporary(from mealHistory: MealHistory) {
        // Get the context from your Core Data stack
        let context = CoreDataStack.shared.context

        for foodEntry in mealHistory.foodEntries?.allObjects as? [FoodItemEntry] ?? [] {
            // Create a new FoodItemTemporary entity for each food item
            let newFoodItemTemporary = FoodItemTemporary(context: context)
            newFoodItemTemporary.entryId = foodEntry.entryId
            newFoodItemTemporary.entryPortionServed = foodEntry.entryPortionServed

            // Add any other properties that are relevant to the FoodItemRow entity
        }

        // Save the context
        do {
            try context.save()
            print("FoodItemTemporary entries saved successfully")
        } catch {
            print("Failed to save FoodItemRow entries: \(error)")
        }
    }
    
    private func formatFoodEntry(_ foodEntry: FoodItemEntry) -> String {
        let portionServedFormatted = formatGramsAmount(foodEntry.entryPortionServed) // Always 0 decimals for grams
        let portionServedFormattedPP = formatPPAmount(foodEntry.entryPortionServed) // 0 or 1 decimals for pieces
        
        let notEatenFormatted = formatGramsAmount(foodEntry.entryNotEaten) // Always 0 decimals for grams
        let notEatenFormattedPP = formatPPAmount(foodEntry.entryNotEaten) // 0 or 1 decimals for pieces
        
        let eatenAmount = foodEntry.entryPortionServed - foodEntry.entryNotEaten
        let eatenAmountFormatted = formatGramsAmount(eatenAmount) // Always 0 decimals for grams
        let eatenAmountFormattedPP = formatPPAmount(eatenAmount) // 0 or 1 decimals for pieces
        
        if foodEntry.entryNotEaten > 0 {
            if foodEntry.entryPerPiece {
                return String(format: NSLocalizedString("Åt upp %@ st [Serverades %@ st - Lämnade %@ st]", comment: "Ate up format (pieces)"), eatenAmountFormattedPP, portionServedFormattedPP, notEatenFormattedPP)
            } else {
                return String(format: NSLocalizedString("Åt upp %@ g [Serverades %@ g - Lämnade %@ g]", comment: "Ate up format (grams)"), eatenAmountFormatted, portionServedFormatted, notEatenFormatted)
            }
        } else {
            if foodEntry.entryPerPiece {
                return String(format: NSLocalizedString("Åt upp %@ st", comment: "Ate up format (pieces)"), portionServedFormattedPP)
            } else {
                return String(format: NSLocalizedString("Åt upp %@ g", comment: "Ate up format (grams)"), portionServedFormatted)
            }
        }
    }
    
    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Hide the overlay when content has loaded
        fadeOutOverlay()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Hide the overlay if there's an error
        fadeOutOverlay()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Hide the overlay if there's an error
        fadeOutOverlay()
    }
    
    private func fadeOutOverlay() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.5, animations: {
                self.overlayView.alpha = 0
            }) { _ in
                self.overlayView.removeFromSuperview()
            }
        }
    }

}

