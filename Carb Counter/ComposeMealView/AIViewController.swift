import UIKit

class AIViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    private var isSwedish = true // Determines the response language
    
    private let imageView = UIImageView()
    private let analyzeButton = UIButton(type: .system)
    private let resultLabel = UILabel()
    private let selectImageButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    private let debugLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    private func setupUI() {
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .secondarySystemBackground
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        analyzeButton.setTitle(isSwedish ? "Analysera måltid" : "Analyze Meal", for: .normal)
        analyzeButton.addTarget(self, action: #selector(analyzeMeal), for: .touchUpInside)
        analyzeButton.translatesAutoresizingMaskIntoConstraints = false
        
        resultLabel.numberOfLines = 0
        resultLabel.textAlignment = .natural
        resultLabel.font = .systemFont(ofSize: 14)
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        
        selectImageButton.setTitle(isSwedish ? "Välj bild" : "Select Image", for: .normal)
        selectImageButton.addTarget(self, action: #selector(selectImageSource), for: .touchUpInside)
        selectImageButton.translatesAutoresizingMaskIntoConstraints = false
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        debugLabel.numberOfLines = 0
                debugLabel.textAlignment = .natural
                debugLabel.font = .systemFont(ofSize: 12)
                debugLabel.textColor = .systemGray
                debugLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(imageView)
        view.addSubview(selectImageButton)
        view.addSubview(analyzeButton)
        view.addSubview(resultLabel)
        view.addSubview(activityIndicator)
        view.addSubview(debugLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            imageView.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),

            selectImageButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            selectImageButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            analyzeButton.topAnchor.constraint(equalTo: selectImageButton.bottomAnchor, constant: 20),
            analyzeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            resultLabel.topAnchor.constraint(equalTo: analyzeButton.bottomAnchor, constant: 20),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            debugLabel.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 20),
                   debugLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                   debugLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
               
        ])
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
    
    private func analyzeImageDirectly(_ image: UIImage) {
            guard let imageBase64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() else {
                handleError(message: "Failed to convert image to base64")
                return
            }
            
            guard let apiKey = UserDefaults.standard.string(forKey: "gptAPIKey") else {
                handleError(message: "Missing API key")
                return
            }
            
            let prompt = isSwedish ?
                "Analysera bilden av måltiden och ge följande information:\n" +
                "1. Lista alla matvaror som syns i bilden\n" +
                "2. Uppskatta vikten eller portionsstorleken för varje matvara\n" +
                "3. Beräkna näringsinnehåll per matvara:\n" +
                "   - Kolhydrater (g)\n" +
                "   - Protein (g)\n" +
                "   - Fett (g)\n" +
                "4. Summera det totala näringsinnehållet för hela måltiden\n" +
                "Presentera informationen tydligt och strukturerat." :
                "Analyze the meal image and provide the following information:\n" +
                "1. List all food items visible in the image\n" +
                "2. Estimate the weight or portion size for each item\n" +
                "3. Calculate nutritional content per item:\n" +
                "   - Carbohydrates (g)\n" +
                "   - Protein (g)\n" +
                "   - Fat (g)\n" +
                "4. Sum up the total nutritional content for the entire meal\n" +
                "Present the information in a clear, structured format."
            
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
    
    private func handleAnalysisResponse(data: Data?, response: HTTPURLResponse?, error: Error?) {
            activityIndicator.stopAnimating()
            analyzeButton.isEnabled = true
            selectImageButton.isEnabled = true
            
            if let error = error {
                handleError(message: "Network error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response else {
                handleError(message: "No HTTP response received")
                return
            }
            
            debugLabel.text = "HTTP Status: \(httpResponse.statusCode)"
            
            guard httpResponse.statusCode == 200 else {
                if let data = data,
                   let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJSON["error"] as? [String: Any],
                   let message = errorMessage["message"] as? String {
                    handleError(message: "API Error: \(message)")
                } else {
                    handleError(message: "HTTP Error: \(httpResponse.statusCode)")
                }
                return
            }
            
            guard let data = data else {
                handleError(message: "No data received")
                return
            }
            
            do {
                if let responseString = String(data: data, encoding: .utf8) {
                    debugLabel.text = "Response received: \(String(responseString.prefix(100)))..."
                }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let json = json else {
                    handleError(message: "Invalid JSON response")
                    return
                }
                
                guard let choices = json["choices"] as? [[String: Any]] else {
                    handleError(message: "No choices in response")
                    return
                }
                
                guard let firstChoice = choices.first else {
                    handleError(message: "Empty choices array")
                    return
                }
                
                guard let message = firstChoice["message"] as? [String: Any] else {
                    handleError(message: "No message in first choice")
                    return
                }
                
                guard let content = message["content"] as? String else {
                    handleError(message: "No content in message")
                    return
                }
                
                resultLabel.text = content
                debugLabel.text = "Analysis completed successfully"
                
            } catch {
                handleError(message: "JSON parsing error: \(error.localizedDescription)")
            }
        }
    
    private func handleError(message: String) {
            activityIndicator.stopAnimating()
            analyzeButton.isEnabled = true
            selectImageButton.isEnabled = true
            resultLabel.text = "Error: \(message)"
            debugLabel.text = "Error details: \(message)"
            print("Error: \(message)") // Also log to console
        }
    
    @objc private func selectImageSource() {
        let actionSheet = UIAlertController(title: isSwedish ? "Välj bildkälla" : "Select Image Source",
                                          message: nil,
                                          preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: isSwedish ? "Kamera" : "Camera",
                                          style: .default,
                                          handler: { _ in
            self.presentImagePicker(sourceType: .camera)
        }))
        
        actionSheet.addAction(UIAlertAction(title: isSwedish ? "Bildbibliotek" : "Photo Library",
                                          style: .default,
                                          handler: { _ in
            self.presentImagePicker(sourceType: .photoLibrary)
        }))
        
        actionSheet.addAction(UIAlertAction(title: isSwedish ? "Avbryt" : "Cancel",
                                          style: .cancel))
        
        present(actionSheet, animated: true)
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else { return }
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                             didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            imageView.image = image
            resultLabel.text = ""
        }
    }
}
