import UIKit

class MealHistoryDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
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
    private var nightscoutButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM HH:mm"
        let mealTimeStr = dateFormatter.string(from: mealHistory?.mealDate ?? Date())
        
        title = String(format: NSLocalizedString("Måltid %@", comment: "Meal time format"), mealTimeStr)
        
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
        setupSummaryView()
        setupNightscoutButton()
        setupActionButton()
        setupTableView()
    }
    
    private func setupSummaryView() {
        let summaryContainer = UIView()
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
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -146)
        ])
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
            foodNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
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

        // Attempt to find ComposeMealViewController from the tab bar controller
        if let tabBarController = self.tabBarController {
            for viewController in tabBarController.viewControllers ?? [] {
                if let navController = viewController as? UINavigationController {
                    for vc in navController.viewControllers {
                        if let composeMealVC = vc as? ComposeMealViewController {
                            mealInsightsVC.delegate = composeMealVC // Set the delegate
                            break
                        }
                    }
                }
            }
        } else {
            // If tabBarController is nil, use another way to find ComposeMealViewController, maybe via a delegate or navigation stack
            print("Tab bar controller not found")
        }

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

    private func setupNightscoutButton() {
        guard let nightscoutURL = UserDefaultsRepository.nightscoutURL, !nightscoutURL.isEmpty else {
            // If the nightscoutURL is empty or nil, do not show the button
            return
        }
        
        nightscoutButton = UIButton(type: .system)
        nightscoutButton.setTitle(NSLocalizedString("Visa i Nightscout", comment: "Show in Nightscout"), for: .normal)
        
        // Use the custom light blue color from the color picker
        let lightBlueColor = UIColor(red: 209/255, green: 230/255, blue: 255/255, alpha: 1.0) // RGB(209, 230, 255)
        nightscoutButton.backgroundColor = lightBlueColor
        nightscoutButton.setTitleColor(UIColor.systemBlue, for: .normal)  // System blue text color
        nightscoutButton.titleLabel?.font = UIFont.systemFont(ofSize: 19, weight: .semibold)
        nightscoutButton.layer.cornerRadius = 10
        nightscoutButton.translatesAutoresizingMaskIntoConstraints = false
        nightscoutButton.addTarget(self, action: #selector(openNightscout), for: .touchUpInside)
        
        view.addSubview(nightscoutButton)
        
        NSLayoutConstraint.activate([
            nightscoutButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nightscoutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nightscoutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            nightscoutButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Open Nightscout Action
    
    @objc private func openNightscout() {
        guard let nightscoutBaseURL = UserDefaultsRepository.nightscoutURL,
              let nightscoutToken = UserDefaultsRepository.nightscoutToken,
              let mealDate = mealHistory?.mealDate else {
            // Handle error: show an alert that Nightscout URL or token is not set
            let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Error"), message: NSLocalizedString("Nightscout-URL eller token är inte angiven. Gå till inställningar för att ange dem.", comment: "Nightscout URL or token not set. Please set them in settings."), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        // Construct the URL
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: mealDate)
        
        // Ensure the base URL ends with '/'
        var baseURL = nightscoutBaseURL
        if !baseURL.hasSuffix("/") {
            baseURL += "/"
        }
        
        // Construct the URL components safely
        var urlComponents = URLComponents(string: baseURL + "report/")
        urlComponents?.queryItems = [
            URLQueryItem(name: "token", value: nightscoutToken),
            URLQueryItem(name: "report", value: "daytoday"),
            URLQueryItem(name: "startDate", value: dateString),
            URLQueryItem(name: "endDate", value: dateString),
            URLQueryItem(name: "autoShow", value: "true")
        ]
        
        if let url = urlComponents?.url {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            // Handle error: invalid URL
            let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Error"), message: NSLocalizedString("Kunde inte skapa Nightscout URL.", comment: "Could not create Nightscout URL."), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
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

        // Find an existing instance of ComposeMealViewController in the navigation stack
        if let navigationController = navigationController,
           let composeMealVC = navigationController.viewControllers.first(where: { $0 is ComposeMealViewController }) as? ComposeMealViewController {
            
            composeMealVC.checkAndHandleExistingMeal(replacementAction: {
                composeMealVC.addMealHistory(mealHistory)
            }, additionAction: {
                composeMealVC.addMealHistory(mealHistory)
            }, completion: {
                navigationController.popToViewController(composeMealVC, animated: true)
            })
            
        } else {
            // If no existing instance found, instantiate a new one
            let composeMealVC = ComposeMealViewController()
            composeMealVC.addMealHistory(mealHistory)
            navigationController?.pushViewController(composeMealVC, animated: true)
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

}

