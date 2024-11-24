import UIKit

class AIViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDataSource, UITableViewDelegate {
    
    private var isSwedish = true // Determines the response language
    private var gptCarbs: String? = "0"
    private var gptFat: String? = "0"
    private var gptProtein: String? = "0"
    
    private let imageView = UIImageView()
    private let analyzeButton = UIButton(type: .system)
    private let selectImageButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let overlayLabel = UILabel()
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
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
        setupCloseButton()
    }
    
    private func setupNavigationBar() {
        title = isSwedish ? "AI Måltidsanalys" : "AI Meal Analysis"
        
    }
    
    private func setupUI() {
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .label.withAlphaComponent(0.1)
        imageView.layer.cornerRadius = 20
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true // Enable interaction
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure the overlay label
        overlayLabel.text = isSwedish ? "Välj en bild" : "Select an Image"
        overlayLabel.textColor = .secondaryLabel
        overlayLabel.font = .systemFont(ofSize: 18, weight: .medium)
        overlayLabel.textAlignment = .center
        overlayLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayLabel.isHidden = false // Initially visible
        
        // Add tap gesture recognizer to the imageView
        let imageTapGesture = UITapGestureRecognizer(target: self, action: #selector(selectImageSource))
        imageView.addGestureRecognizer(imageTapGesture)
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = isSwedish ? "Analysera måltid" : "Analyze Meal"
            config.baseBackgroundColor = .systemBlue
            config.baseForegroundColor = .white
            config.cornerStyle = .medium
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20) // Add padding

            analyzeButton.configuration = config
            analyzeButton.addTarget(self, action: #selector(analyzeMeal), for: .touchUpInside)
            analyzeButton.translatesAutoresizingMaskIntoConstraints = false
        } else {
            // Fallback for earlier iOS versions
            analyzeButton.setTitle(isSwedish ? "Analysera måltid" : "Analyze Meal", for: .normal)
            analyzeButton.setTitleColor(.white, for: .normal)
            analyzeButton.backgroundColor = .systemBlue
            analyzeButton.layer.cornerRadius = 10
            analyzeButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
            analyzeButton.addTarget(self, action: #selector(analyzeMeal), for: .touchUpInside)
            analyzeButton.translatesAutoresizingMaskIntoConstraints = false
        }
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        resultLabel.numberOfLines = 0
        resultLabel.textAlignment = .natural
        resultLabel.font = .systemFont(ofSize: 14)
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        debugLabel.numberOfLines = 0
        debugLabel.textAlignment = .natural
        debugLabel.font = .systemFont(ofSize: 12)
        debugLabel.textColor = .systemGray
        debugLabel.translatesAutoresizingMaskIntoConstraints = false
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.isHidden = true
        
        view.addSubview(imageView)
        imageView.addSubview(overlayLabel) // Add overlay label to imageView
        view.addSubview(analyzeButton)
        view.addSubview(activityIndicator)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(resultLabel)
        contentView.addSubview(debugLabel)
        contentView.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            imageView.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            
            // Overlay label constraints
            overlayLabel.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            overlayLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            overlayLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 8),
            overlayLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -8),
            
            analyzeButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            analyzeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scrollView.topAnchor.constraint(equalTo: analyzeButton.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            resultLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            resultLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            debugLabel.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 20),
            debugLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            debugLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            tableView.topAnchor.constraint(equalTo: debugLabel.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: analyzeButton.bottomAnchor, constant: 20),
            //activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupCloseButton() {
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
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
            handleError(message: "Request failed or no data received.")
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
            
            tableData = parseTable(content)
            if !tableData.isEmpty {
                tableView.isHidden = false
                tableView.reloadData()
            } else {
                tableView.isHidden = true
            }
            
            resultLabel.attributedText = formatMarkdownToAttributedString(content)
            debugLabel.text = "Analys lyckades"
        } catch {
            handleError(message: "JSON parsing error: \(error.localizedDescription)")
        }
    }
    
    private func handleError(message: String) {
        activityIndicator.stopAnimating()
        analyzeButton.isEnabled = true
        selectImageButton.isEnabled = true
        resultLabel.text = "Fel: \(message)"
        debugLabel.text = "Feldetaljer: \(message)"
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
    
    private func formatMarkdownToAttributedString(_ markdown: String) -> NSAttributedString {
        // Remove ** markers
        let cleanedMarkdown = markdown.replacingOccurrences(of: "\\*\\*", with: "", options: .regularExpression)
        
        let attributedString = NSMutableAttributedString(string: cleanedMarkdown)
        let fullRange = NSRange(location: 0, length: cleanedMarkdown.count)
        
        // Define regex patterns
        let headerRegex = try! NSRegularExpression(pattern: "### (.*?)\\n")
        
        // Process headers (apply specific formatting)
        for match in headerRegex.matches(in: cleanedMarkdown, range: fullRange).reversed() {
            if let range = Range(match.range(at: 1), in: cleanedMarkdown) {
                let headerText = String(cleanedMarkdown[range])
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 16),
                    .foregroundColor: UIColor.gray
                ]
                let newAttributedString = NSAttributedString(string: headerText + "\n", attributes: attributes)
                attributedString.replaceCharacters(in: match.range, with: newAttributedString)
            }
        }
        
        // Additional headline formatting for specific Swedish headlines
        let lines = cleanedMarkdown.components(separatedBy: "\n")
        var currentPosition = 0
        
        for line in lines {
            let lineLength = line.count + 1 // +1 for newline
            let lineRange = NSRange(location: currentPosition, length: lineLength)
            
            if line.matches(pattern: "^[A-Za-zÀ-ÖØ-öø-ÿ ]+ näringsinnehåll$") ||
                line.matches(pattern: "^Synliga matvaror$") ||
                line.matches(pattern: "^Uppskattning av portionsstorlek$") {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 16),
                    .foregroundColor: UIColor.systemGray
                ]
                attributedString.addAttributes(attributes, range: lineRange)
            }
            
            currentPosition += lineLength
        }
        
        // Extract nutritional values
        extractTotals(from: cleanedMarkdown)
        
        return attributedString
    }
    
    private func extractTotals(from text: String) {
        // Pattern that handles "Ca", "ca", "~", "Cirka", "cirka" before the number
        let approximatePattern = "(ca |Ca |~|Cirka |cirka )?\\s*"
        
        let carbsRegex = try! NSRegularExpression(
            pattern: "Kolhydrater.*?\(approximatePattern)(\\d+)\\s*g",
            options: .caseInsensitive
        )
        let fatRegex = try! NSRegularExpression(
            pattern: "Fett.*?\(approximatePattern)(\\d+)\\s*g",
            options: .caseInsensitive
        )
        let proteinRegex = try! NSRegularExpression(
            pattern: "Protein.*?\(approximatePattern)(\\d+)\\s*g",
            options: .caseInsensitive
        )
        
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        
        // Extract and set carbs
        if let match = carbsRegex.firstMatch(in: text, range: fullRange),
           let carbsRange = Range(match.range(at: 2), in: text) {
            gptCarbs = String(text[carbsRange])
            print("DEBUG: Carbs set to: \(gptCarbs ?? "nil")")
        }
        
        // Extract and set fat
        if let match = fatRegex.firstMatch(in: text, range: fullRange),
           let fatRange = Range(match.range(at: 2), in: text) {
            gptFat = String(text[fatRange])
            print("DEBUG: Fat set to: \(gptFat ?? "nil")")
        }
        
        // Extract and set protein
        if let match = proteinRegex.firstMatch(in: text, range: fullRange),
           let proteinRange = Range(match.range(at: 2), in: text) {
            gptProtein = String(text[proteinRange])
            print("DEBUG: Protein set to: \(gptProtein ?? "nil")")
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let row = tableData[indexPath.row]
        cell.textLabel?.text = row.joined(separator: " | ")
        cell.textLabel?.font = UIFont.systemFont(ofSize: 12)
        cell.textLabel?.numberOfLines = 0
        return cell
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
        if let image = info[.originalImage] as? UIImage {
            imageView.image = image
            overlayLabel.isHidden = true // Hide overlay when image is selected
            resultLabel.text = ""
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    private func analyzeImageDirectly(_ image: UIImage) {
        guard let imageBase64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() else {
            handleError(message: "Failed to convert image to Base64.")
            return
        }
        
        guard let apiKey = UserDefaults.standard.string(forKey: "gptAPIKey") else {
            handleError(message: "Missing API key. Please configure it in the settings.")
            return
        }
        
        let prompt = isSwedish
        ? """
            Analysera bilden av måltiden och uppskatta följande information i angiven ordning på rubrikerna 1-4:
            1. Summering totalt näringsinnehåll för hela måltiden 
            Använd exakt dessa benämningar och använd enheten gram (g):
                - Kolhydrater totalt:
                - Protein totalt:
                - Fett totalt:
            2. Lista över alla matvaror som syns i bilden
            3. Uppskattad vikt eller portionsstorlek för varje matvara
            4. Beräknat näringsinnehåll per matvara i gram:
                - Kolhydrater:
                - Protein:
                - Fett:
            Presentera informationen i punktform under varje rubrik
            """
        : """
            Analyze the meal image and provide the following information:
            1. Sum up the total nutritional content for the entire meal.
                - Carbohydrates (g)
                - Protein (g)
                - Fat (g)
            1. List all food items visible in the image.
            2. Estimate the weight or portion size for each item.
            3. Calculate nutritional content per item
            4. Sum up the total nutritional content for the entire meal.
            Present the information as bullets under each headline.
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
        
        debugLabel.text = "Sending request..."
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleAnalysisResponse(data: data, response: response as? HTTPURLResponse, error: error)
            }
        }
        task.resume()
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
