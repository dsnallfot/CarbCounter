import Photos
import UIKit

class AIViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDataSource, UITableViewDelegate {
    
    private var isSwedish = true // Determines the response language
    private var gptCarbs: String? = "0"
    private var gptFat: String? = "0"
    private var gptProtein: String? = "0"
    private var gptTotalWeight: String? = "0"
    private var gptName: String? = ""
    
    private let savedImageKey = "savedImageKey"
    private let savedResponseKey = "savedResponseKey"
    
    private var fullGPTResponse: String?
    
    private let imageView = UIImageView()
    private var analyzeButton = UIButton()
    private let selectImageButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let overlayLabel = UILabel()
    
    private let mealNameLabel = UILabel()
    private let totalWeightLabel = UILabel()
    
    //private let scrollView = UIScrollView()
    //private let contentView = UIView()
    private let resultLabel = UILabel()
    private let debugLabel = UILabel()
    private let tableView = UITableView()
    
    private var tableData: [[String]] = [] // Parsed table data
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupNavigationBar()
        setupUI()
        // Check if the app is in dark mode and set the background accordingly
        updateBackgroundForCurrentMode()
        
        // Load persisted data
        loadPersistedData()
        resultLabel.isHidden = true
    }
    
    private func loadPersistedData() {
        if let savedImage = UserDefaults.standard.loadImage(forKey: savedImageKey) {
            imageView.image = savedImage
            overlayLabel.isHidden = true
        }

        if let savedResponse = UserDefaults.standard.loadString(forKey: savedResponseKey) {
            print("DEBUG: Loaded savedResponse from UserDefaults:\n\(savedResponse)")

            // Parse the saved CSV string into structured data
            let parsedData = parseCSV(savedResponse)
            debugLabel.text = "ⓘ Senaste analyserade bild laddades från minnet"
            debugLabel.textColor = .systemCyan.withAlphaComponent(0.8)

            // Update the header view and table view
            if let mealName = parsedData.mealName, let mealTotalWeight = parsedData.mealTotalWeight {
                gptName = mealName
                gptTotalWeight = String(mealTotalWeight)
                tableData = parsedData.ingredients
                updateHeaderView() // Refresh the header view
                tableView.reloadData() // Refresh the table view
                tableView.isHidden = false
            } else {
                print("DEBUG: Failed to parse meal name or total weight from savedResponse.")
            }
        } else {
            print("DEBUG: No savedResponse found in UserDefaults.")
        }
    }
    
    private func savePersistedData(image: UIImage?, csvBlock: [String]) {
        if let image = image {
            UserDefaults.standard.saveImage(image, forKey: savedImageKey)
        }
        if !csvBlock.isEmpty {
            let csvString = csvBlock.joined(separator: "\n") // Convert array to string
            UserDefaults.standard.saveString(csvString, forKey: savedResponseKey)
        }
    }
    
    private func setupNavigationBar() {
        title = isSwedish ? "AI Måltidsanalys" : "AI Meal Analysis"
        
        // Close button
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
        
        // Trash button
        let trashButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(trashButtonTapped)
        )
        trashButton.tintColor = .systemRed
        
        // Calendar button
        let calendarButton = UIBarButtonItem(
            image: UIImage(systemName: "calendar"),
            style: .plain,
            target: self,
            action: #selector(openMealLog)
        )
        calendarButton.tintColor = .label
        
        // Add buttons to the right navigation bar
        navigationItem.rightBarButtonItems = [trashButton, calendarButton]
    }
    
    private func setupUI() {
        // Configure header view
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear
        
        // Add a tap gesture to the header view
        let headerTapGesture = UITapGestureRecognizer(target: self, action: #selector(openAnalysisModal))
        headerView.addGestureRecognizer(headerTapGesture)
        headerView.isUserInteractionEnabled = true
        
        // Configure meal name label
        mealNameLabel.text = gptName
        mealNameLabel.font = UIFont.boldSystemFont(ofSize: 30)
        mealNameLabel.textAlignment = .center
        mealNameLabel.numberOfLines = 0 // Allow unlimited lines
        mealNameLabel.lineBreakMode = .byWordWrapping
        mealNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure total weight label
        if let totalWeight = gptTotalWeight, let totalWeightValue = Int(totalWeight), totalWeightValue > 0 {
            totalWeightLabel.text = "Total portion: \(totalWeightValue) g"
        } else {
            totalWeightLabel.text = ""
        }
        totalWeightLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        totalWeightLabel.textColor = .gray
        totalWeightLabel.textAlignment = .center
        totalWeightLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add labels to header view
        headerView.addSubview(mealNameLabel)
        headerView.addSubview(totalWeightLabel)
        
        // Configure imageView
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .label.withAlphaComponent(0.1)
        imageView.layer.cornerRadius = 20
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure overlayLabel
        let symbolAttachment = NSTextAttachment()
        symbolAttachment.image = UIImage(systemName: "photo.badge.plus")?.withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal)
        symbolAttachment.bounds = CGRect(x: 0, y: -4, width: 26, height: 22) // Adjust bounds for symbol size and alignment

        let symbolString = NSAttributedString(attachment: symbolAttachment)
        let textString = NSAttributedString(string: " \(isSwedish ? "Välj en bild" : "Select an Image")", attributes: [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 20, weight: .medium)
        ])

        let combinedString = NSMutableAttributedString()
        combinedString.append(symbolString)
        combinedString.append(textString)

        overlayLabel.attributedText = combinedString
        overlayLabel.textAlignment = .center
        overlayLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayLabel.isHidden = false
        // Add tap gesture to imageView
        let imageTapGesture = UITapGestureRecognizer(target: self, action: #selector(selectImageSource))
        imageView.addGestureRecognizer(imageTapGesture)
        
        // Configure analyzeButton
        analyzeButton = createStyledButton(title: isSwedish ? "Analysera bild" : "Analyze Picture")
        analyzeButton.addTarget(self, action: #selector(analyzeMeal), for: .touchUpInside)
        analyzeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure resultLabel
        resultLabel.numberOfLines = 0
        resultLabel.textAlignment = .natural
        resultLabel.font = .systemFont(ofSize: 14)
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.isHidden = true
        
        // Add tap gesture to resultLabel
        let resultLabelTapGesture = UITapGestureRecognizer(target: self, action: #selector(openAnalysisModal))
        resultLabel.isUserInteractionEnabled = true
        resultLabel.addGestureRecognizer(resultLabelTapGesture)
        
        // Configure activityIndicator
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure debugLabel
        debugLabel.numberOfLines = 0
        debugLabel.textAlignment = .center

        // Create an italic font
        let baseFont = UIFont.systemFont(ofSize: 11)
        if let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
            debugLabel.font = UIFont(descriptor: italicDescriptor, size: 11)
        } else {
            debugLabel.font = baseFont // Fallback to base font if italic descriptor is unavailable
        }

        debugLabel.textColor = .systemCyan.withAlphaComponent(0.8)
        debugLabel.translatesAutoresizingMaskIntoConstraints = false
        let debugLabelTapGesture = UITapGestureRecognizer(target: self, action: #selector(debugLabelTapped))
        debugLabel.isUserInteractionEnabled = true
        debugLabel.addGestureRecognizer(debugLabelTapGesture)
        
        // Configure tableView
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.isHidden = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        
        // Add subviews to the main view
        view.addSubview(imageView)
        imageView.addSubview(overlayLabel)
        view.addSubview(analyzeButton)
        view.addSubview(activityIndicator)
        view.addSubview(headerView)
        view.addSubview(tableView)
        view.addSubview(resultLabel)
        view.addSubview(debugLabel)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // imageView constraints
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 5),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            imageView.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.65),
            
            // overlayLabel constraints
            overlayLabel.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            overlayLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            overlayLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 8),
            overlayLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -8),
            
            // analyzeButton constraints
            analyzeButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 15),
            analyzeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // activityIndicator constraints
            activityIndicator.trailingAnchor.constraint(equalTo: analyzeButton.leadingAnchor, constant: 30),
            activityIndicator.centerYAnchor.constraint(equalTo: analyzeButton.centerYAnchor),
            
            // headerView constraints
            headerView.topAnchor.constraint(equalTo: analyzeButton.bottomAnchor, constant: 15),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // mealNameLabel constraints
           // mealNameLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            mealNameLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 5),
            mealNameLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor) ,
            mealNameLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            mealNameLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            // totalWeightLabel constraints
            //totalWeightLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            totalWeightLabel.topAnchor.constraint(equalTo: mealNameLabel.bottomAnchor, constant: 4),
            totalWeightLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -5),
            totalWeightLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // tableView constraints
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -70),
            
            // debugLabel constraints
            debugLabel.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 10),
            debugLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            debugLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // resultLabel constraints
            resultLabel.topAnchor.constraint(equalTo: debugLabel.bottomAnchor, constant: 10),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

        ])
    }
    
    private func updateAnalyzeButtonTitle(to newTitle: String) {
        DispatchQueue.main.async {
            self.updateStyledButtonTitle(self.analyzeButton, with: newTitle)
        }
    }
    
    private func updateStyledButtonTitle(_ button: UIButton, with title: String) {
        if #available(iOS 15.0, *) {
            guard var config = button.configuration else { return }
            
            // Update the title with the correct styling
            let systemFont = UIFont.systemFont(ofSize: 19, weight: .semibold)
            let font = systemFont.fontDescriptor.withDesign(.rounded).flatMap { UIFont(descriptor: $0, size: 19) } ?? systemFont
            
            var attributedTitle = AttributedString(title)
            attributedTitle.font = font
            attributedTitle.foregroundColor = UIColor.white
            
            config.attributedTitle = attributedTitle
            button.configuration = config
        } else {
            // Fallback for earlier iOS versions
            button.setTitle(title, for: .normal)
        }
    }
    
    private func createStyledButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = .systemBlue
            config.baseForegroundColor = .white
            config.cornerStyle = .medium
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 40, bottom: 10, trailing: 40) // Add padding
            
            // Custom font for the title
            let systemFont = UIFont.systemFont(ofSize: 19, weight: .semibold)
            let font = systemFont.fontDescriptor.withDesign(.rounded).flatMap { UIFont(descriptor: $0, size: 19) } ?? systemFont
            
            var attributedTitle = AttributedString(title)
            attributedTitle.font = font
            attributedTitle.foregroundColor = UIColor.white
            
            config.attributedTitle = attributedTitle
            button.configuration = config
        } else {
            // Fallback for earlier iOS versions
            button.setTitle(title, for: .normal)
            let systemFont = UIFont.systemFont(ofSize: 19, weight: .semibold)
            if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
                button.titleLabel?.font = UIFont(descriptor: roundedDescriptor, size: 19)
            } else {
                button.titleLabel?.font = systemFont
            }
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 10
            button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 40, bottom: 10, right: 40) // Add padding
        }
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func trashButtonTapped() {
        // Confirm clearing data
        let alert = UIAlertController(
            title: NSLocalizedString("Rensa analys?", comment: "Rensa analys?"),
            message: NSLocalizedString("Är du säker på att du vill rensa bild och text för den senast analyserade måltiden?", comment: "Är du säker på att du vill rensa bild och text för den senast analyserade måltiden?"),
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Rensa", comment: "Rensa"), style: .destructive, handler: { [weak self] _ in
            self?.clearData()
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel))
        
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func openMealLog() {
        let logVC = AIMealLogViewController()
        let navController = UINavigationController(rootViewController: logVC)
        navController.modalPresentationStyle = .formSheet // Present as a form sheet
        
        present(navController, animated: true)
    }
    
    private func clearData() {
        // Clear the image and response
        UserDefaults.standard.removeObject(forKey: savedImageKey)
        UserDefaults.standard.removeObject(forKey: savedResponseKey)
        
        // Reset views
        imageView.image = nil
        overlayLabel.isHidden = false
        resultLabel.text = ""
        debugLabel.text = ""
        
        // Reset meal name and total weight
        mealNameLabel.text = ""
        totalWeightLabel.text = ""
        
        // Clear table data
        tableData.removeAll()
        tableView.reloadData()
        tableView.isHidden = true
        
        updateAnalyzeButtonTitle(to: isSwedish ? "Analysera bild" : "Analyze Picture")
        
        //print("DEBUG: Cleared all saved data and reset views")
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
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackgroundForCurrentMode()
        }
    }
    
    @objc private func closeViewController() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func debugLabelTapped() {
        // Try fetching the response from memory first
        let response = fullGPTResponse ?? UserDefaults.standard.string(forKey: "savedResponseKey")
        
        // If neither is available, show the default message
        let message = response ?? "Inget svar tillgängligt."
        
        // Create and present the alert
        let alert = UIAlertController(
            title: "ChatGPT detaljerat svar\n",
            message: message,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func analyzeMeal() {
        guard let image = imageView.image else {
            resultLabel.text = isSwedish ? "Välj en bild först." : "Please select an image first."
            return
        }
        
        activityIndicator.startAnimating()
        analyzeButton.isEnabled = false
        selectImageButton.isEnabled = false
        analyzeImageDirectly(image)
    }
    
    private func handleAnalysisResponse(data: Data?, response: HTTPURLResponse?, error: Error?) {
        activityIndicator.stopAnimating()
        analyzeButton.isEnabled = true
        selectImageButton.isEnabled = true

        guard error == nil, let data = data, let httpResponse = response, httpResponse.statusCode == 200 else {
            handleError(message: "Förfrågan misslyckades, eller ingen data togs emot.")
            return
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let choices = json?["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                handleError(message: "Invalid response structure.")
                return
            }

            print("Received content:\n\(content)")
            
            // Save the full response for later use
            self.fullGPTResponse = content

            // Parse the CSV string into a structured format
            let parsedData = parseCSV(content)

            // Present the parsed data in the table view
            if let mealName = parsedData.mealName, let mealTotalWeight = parsedData.mealTotalWeight {
                print("Successfully extracted meal name: \(mealName), total weight: \(mealTotalWeight) g")
                gptName = mealName
                gptTotalWeight = String(mealTotalWeight)
                tableData = parsedData.ingredients
                updateHeaderView()
                tableView.reloadData()
                tableView.isHidden = false
                debugLabel.text = "ⓘ Förfrågan lyckades!"
                debugLabel.textColor = .systemCyan.withAlphaComponent(0.8)
                updateAnalyzeButtonTitle(to: isSwedish ? "Analysera igen" : "Analyze Again")

                // Save only the CSV block to UserDefaults
                savePersistedData(image: imageView.image, csvBlock: parsedData.csvBlock)

            } else {
                print("Failed to extract meal name or total weight.")
                handleError(message: "Failed to extract meal data.")
            }

        } catch {
            print("JSON parsing error: \(error.localizedDescription)")
            handleError(message: "JSON parsing error: \(error.localizedDescription)")
        }
    }
    
    private func parseCSV(_ csvString: String) -> (mealName: String?, mealTotalWeight: Int?, ingredients: [[String]], csvBlock: [String]) {
        var mealName: String?
        var mealTotalWeight: Int?
        var ingredients: [[String]] = []

        // Debug: Print the raw CSV string
        // Daniel: Keeping for future debugging // print("Raw CSV String:\n\(csvString)")

        // Locate the start of the CSV block by finding the header
        guard let csvStartIndex = csvString.range(of: "Måltid, MåltidTotalViktGram, Matvara, MatvaraViktGram, MatvaraKolhydraterGram, MatvaraFettGram, MatvaraProteinGram") else {
            print("No valid CSV header found in response.")
            return (nil, nil, [], [])
        }

        // Extract the CSV portion starting from the header
        let csvBlock = csvString[csvStartIndex.lowerBound...]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.starts(with: "This is a basic estimation") } // Exclude unrelated text

        // Daniel: Keeping for future debugging // print("Filtered CSV Lines: \(csvBlock)")

        // Skip the header (first line)
        for (index, line) in csvBlock.enumerated() {
            if index == 0 { continue } // Skip header row

            // Remove quotes and split by commas
            let components = line
                .replacingOccurrences(of: "\"", with: "") // Remove double quotes
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            // Daniel: Keeping for future debugging // print("Line \(index): \(components)")

            if index == 1, components.count >= 2 { // Extract meal name and total weight only
                mealName = components[0]
                mealTotalWeight = Int(components[1])
                // Daniel: Keeping for future debugging // print("Extracted Meal Name: \(mealName ?? "nil"), Total Weight: \(mealTotalWeight ?? 0)")
            }

            if components.count >= 7 { // Ingredient rows
                let ingredientName = components[2]
                let weight = components[3]
                let carbs = components[4]
                let fat = components[5]
                let protein = components[6]
                ingredients.append([ingredientName, weight, carbs, fat, protein])
                // Daniel: Keeping for future debugging // print("Ingredient Added: \(ingredients.last ?? [])")
            }
        }

        print("Final Extracted Meal Name: \(mealName ?? "nil")")
        print("Final Extracted Meal Total Weight: \(mealTotalWeight ?? 0)")
        print("Final Ingredients List: \(ingredients)")

        return (mealName, mealTotalWeight, ingredients, Array(csvBlock))
    }
    
    private func updateHeaderView() {
        // Daniel: Keeping for future debugging // print("DEBUG: Updating header view...")
        // Daniel: Keeping for future debugging // print("DEBUG: Meal Name: \(gptName ?? "nil")")
        // Daniel: Keeping for future debugging // print("DEBUG: Total Weight: \(gptTotalWeight ?? "nil")")

        mealNameLabel.text = gptName ?? ""
        if let totalWeight = gptTotalWeight, let totalWeightValue = Int(totalWeight), totalWeightValue > 0 {
            totalWeightLabel.text = "Total portion: \(totalWeightValue) g"
        } else {
            totalWeightLabel.text = ""
        }
    }
    
    
    private func handleError(message: String) {
        activityIndicator.stopAnimating()
        analyzeButton.isEnabled = true
        selectImageButton.isEnabled = true
        resultLabel.text = "Fel: \(message)"
        debugLabel.text = "⚠ Feldetaljer: \(message)"
        debugLabel.textColor = .systemRed.withAlphaComponent(0.8)
        updateAnalyzeButtonTitle(to: isSwedish ? "Försök igen" : "Try Again")
    }
    
    private func parseTable(_ markdown: String) -> [[String]] {
        var rows: [[String]] = []
        let lines = markdown.split(separator: "\n")
        for line in lines where line.contains("|") && !line.contains("---") {
            let columns = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            rows.append(columns)
        }
        return rows
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "IngredientCell")
        cell.backgroundColor = .clear

        // Ingredient Rows
        let ingredient = tableData[indexPath.row]

        // Ensure we have at least 5 elements in the ingredient array
        guard ingredient.count >= 5 else { return cell }

        // Main text for the ingredient name
        cell.textLabel?.text = "• \(ingredient[0])" // Ingredient name
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)

        // Subtitle text for detailed nutritional information
        cell.detailTextLabel?.text = "   Portion: \(ingredient[1]) g | Kh: \(ingredient[2]) g | Fett: \(ingredient[3]) g | Protein: \(ingredient[4]) g"
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        cell.detailTextLabel?.textColor = .gray
        
        // Custom selection color
        let customSelectionColor = UIView()
        customSelectionColor.backgroundColor = UIColor.clear//.white.withAlphaComponent(0.3)
        cell.selectedBackgroundView = customSelectionColor

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true) // Deselect the row for better UX
        openAnalysisModal() // Call the function to open the modal
    }
    
    // Optional: Add method to set row height for better readability
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.row == 0 || indexPath.row == 1 ? 50 : 60
    }
    
    @objc private func selectImageSource() {
        let actionSheet = UIAlertController(title: isSwedish ? "Välj bildkälla" : "Select Image Source",
                                            message: nil,
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: isSwedish ? "Kamera" : "Camera", style: .default, handler: { _ in
            self.presentImagePicker(sourceType: .camera)
        }))
        actionSheet.addAction(UIAlertAction(title: isSwedish ? "Bildbibliotek" : "Photo Library", style: .default, handler: { _ in
            self.presentImagePicker(sourceType: .photoLibrary)
        }))
        actionSheet.addAction(UIAlertAction(title: isSwedish ? "Avbryt" : "Cancel", style: .cancel))
        present(actionSheet, animated: true)
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else { return }
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        
        // Reset meal name, total weight, and clear table data
        mealNameLabel.text = ""
        totalWeightLabel.text = ""
        tableData.removeAll()
        tableView.reloadData()
        
        if let originalImage = info[.originalImage] as? UIImage {
            // Resize the image before further processing
            let resizedImage = originalImage.resized(toWidth: 800) ?? originalImage
            
            // Update the image view with the resized image
            imageView.image = resizedImage
            overlayLabel.isHidden = true
            resultLabel.text = ""
            debugLabel.text = ""
            
            // Save the resized image to the specific album only if sourceType is .camera
            if picker.sourceType == .camera {
                saveImageToAlbum(image: resizedImage, albumName: "Carb Counter")
            }
            
            // Clear persisted response
            UserDefaults.standard.removeObject(forKey: savedResponseKey)
        }
    }
    
    private func saveImageToAlbum(image: UIImage, albumName: String) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.debugLabel.text = "⚠ Åtkomst nekad att spara bilder till bildbiblioteket."
                    self.debugLabel.textColor = .systemRed.withAlphaComponent(0.8)
                }
                return
            }
            
            // Check if album exists
            var albumPlaceholder: PHObjectPlaceholder?
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
            let fetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            
            if let album = fetchResult.firstObject {
                // Album exists; save image
                self.saveImage(image, to: album)
            } else {
                // Album doesn't exist; create it
                PHPhotoLibrary.shared().performChanges {
                    let albumCreationRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                    albumPlaceholder = albumCreationRequest.placeholderForCreatedAssetCollection
                } completionHandler: { success, error in
                    if success, let placeholder = albumPlaceholder {
                        let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                        if let album = fetchResult.firstObject {
                            self.saveImage(image, to: album)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.debugLabel.text = "⚠ Kunde inte skapa album: \(error?.localizedDescription ?? "Okänt fel")"
                            self.debugLabel.textColor = .systemRed.withAlphaComponent(0.8)
                        }
                    }
                }
            }
        }
    }
    
    private func saveImage(_ image: UIImage, to album: PHAssetCollection) {
        PHPhotoLibrary.shared().performChanges {
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
               let assetPlaceholder = assetChangeRequest.placeholderForCreatedAsset {
                albumChangeRequest.addAssets([assetPlaceholder] as NSFastEnumeration)
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    self.debugLabel.text = "ⓘ Bild sparades till album \(album.localizedTitle ?? "")."
                    self.debugLabel.textColor = .systemCyan.withAlphaComponent(0.8)
                } else {
                    self.debugLabel.text = "⚠ Kunde inte spara bild till album: \(error?.localizedDescription ?? "Okänt fel")"
                    self.debugLabel.textColor = .systemRed.withAlphaComponent(0.8)
                }
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    private func analyzeImageDirectly(_ image: UIImage) {
        // Resize the image to a reasonable size for efficient processing
        guard let resizedImage = image.resized(toWidth: 800) else {
            handleError(message: "Failed to resize the image.")
            return
        }
        
        // Convert the resized image to Base64
        guard let imageBase64 = resizedImage.jpegData(compressionQuality: 0.8)?.base64EncodedString() else {
            handleError(message: "Failed to convert image to Base64.")
            return
        }
        
        // Retrieve the API key
        guard let apiKey = UserDefaults.standard.string(forKey: "gptAPIKey") else {
            handleError(message: "Missing API key. Please configure it in the settings.")
            print("DEBUG: API key is missing.")
            return
        }
        // Daniel: Keeping for future debugging // print("DEBUG: API key found: \(apiKey)")
        let prompt =
            """
            Analysera bilden av måltiden och ge följande data som en komma-separerad textsträng (CSV):
            
            Rubriker:
            "Måltid, MåltidTotalViktGram, Matvara, MatvaraViktGram, MatvaraKolhydraterGram, MatvaraFettGram, MatvaraProteinGram"
            
            För varje matvara som identifieras i bilden, ange en ny rad med följande värden:
            - Måltid: [Ange ett lämpligt namn på måltiden t.ex. "Kyckling med ris"]
            - MåltidTotalViktGram: [Summerad vikt av hela måltiden i gram]
            - Matvara: [Namnet på matvaran, t.ex. "Potatis", "Kyckling"]
            - MatvaraViktGram: [Uppskattad vikt av matvaran i gram]
            - MatvaraKolhydraterGram: [Kolhydratmängd i gram för matvaran]
            - MatvaraFettGram: [Fettmängd i gram för matvaran]
            - MatvaraProteinGram: [Proteininnehåll i gram för matvaran]
            
            Exempel på output:
            "Måltid, MåltidTotalViktGram, Matvara, MatvaraViktGram, MatvaraKolhydraterGram, MatvaraFettGram, MatvaraProteinGram"
            "Kycklingmiddag, 550, Kyckling, 200, 0, 10, 40"
            "Kycklingmiddag, 550, Potatis, 300, 60, 0, 6"
            "Kycklingmiddag, 550, Sås, 50, 4, 8, 1"
            
            Regler:
            1. Om vissa data inte kan beräknas med säkerhet, gör en bästa bedömning baserat på tillgänglig information.
            2. Om något absolut inte kan uppskattas, använd värdet 0.
            3. Följ strikt formatet ovan. Inga decimaler används (t.ex. 0, 1, 10).
            4. Svara alltid med svenska namn på måltiden och matvarorna
            """
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(imageBase64)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1000
        ]
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            handleError(message: "Failed to create request: \(error.localizedDescription)")
            return
        }
        
        debugLabel.text = "ⓘ Skickar förfrågan..."
        debugLabel.textColor = .systemCyan.withAlphaComponent(0.8)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleAnalysisResponse(data: data, response: response as? HTTPURLResponse, error: error)
            }
        }
        task.resume()
    }
    
    @objc private func openAnalysisModal() {
        // Calculate the totals for carbs, fat, protein, and weight
        let gptCarbsInt = tableData.reduce(0) { total, ingredient in
            total + (Int(ingredient[2]) ?? 0) // Sum up ingredient[2] (Carbs)
        }
        let gptFatInt = tableData.reduce(0) { total, ingredient in
            total + (Int(ingredient[3]) ?? 0) // Sum up ingredient[3] (Fat)
        }
        let gptProteinInt = tableData.reduce(0) { total, ingredient in
            total + (Int(ingredient[4]) ?? 0) // Sum up ingredient[4] (Protein)
        }
        let gptWeightInt = Int(gptTotalWeight ?? "0") ?? 0 // Keep total weight as it is

        // Check if the values are valid before proceeding
        guard gptCarbsInt > 0 || gptFatInt > 0 || gptProteinInt > 0 || gptWeightInt > 0 else {
            print("DEBUG: Invalid nutritional values.")
            return
        }
        
        // Load the saved response from UserDefaults
        let savedResponse = UserDefaults.standard.loadString(forKey: savedResponseKey) ?? ""

        let modalVC = AnalysisModalViewController()
        modalVC.gptCarbs = gptCarbsInt
        modalVC.gptFat = gptFatInt
        modalVC.gptProtein = gptProteinInt
        modalVC.gptTotalWeight = gptWeightInt
        modalVC.gptName = gptName ?? "Analyserad måltid" // Pass the gptName
        modalVC.savedResponse = savedResponse // Pass the saved response

        // Wrap in UINavigationController
        let navController = UINavigationController(rootViewController: modalVC)
        navController.modalPresentationStyle = .pageSheet

        // Enable swipe down to dismiss
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium()] // Covers half the screen
            sheet.prefersGrabberVisible = false // Optionally show grabber handle
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true // Allows swiping down to dismiss
        }

        present(navController, animated: true)
    }
    
}

// Helper extension for regex matching
extension String {
    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}

extension UserDefaults {
    func saveImage(_ image: UIImage, forKey key: String) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            set(data, forKey: key)
        }
    }
    
    func loadImage(forKey key: String) -> UIImage? {
        if let data = data(forKey: key) {
            return UIImage(data: data)
        }
        return nil
    }
    
    func saveString(_ value: String, forKey key: String) {
        set(value, forKey: key)
    }
    
    func loadString(forKey key: String) -> String? {
        return string(forKey: key)
    }
}

extension UIImage {
    /// Resizes the image to the specified width while maintaining the aspect ratio.
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width / self.size.width * self.size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, self.scale)
        defer { UIGraphicsEndImageContext() }
        self.draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
