// Daniel: 500+ lines - To be cleaned
import AVFoundation
import CoreData
import UIKit

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var isProcessingBarcode = false

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Scanna streckkod", comment: "Scanna streckkod")

        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .upce]
        } else {
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
                navigationItem.leftBarButtonItem = closeButton

    }
    
    @objc private func closeButtonTapped() {
            dismiss(animated: true, completion: nil)
        }

    func resetBarcodeProcessingState() {
        DispatchQueue.global(qos: .background).async {
            self.isProcessingBarcode = false
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    func failed() {
        let ac = UIAlertController(title: "Scanning stöds ej", message: "Din enhet stödjer inte scanning av streckkoder. Vänligen använd en enhet med kamera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        DispatchQueue.global(qos: .background).async {
            if (self.captureSession?.isRunning == false) {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        DispatchQueue.global(qos: .background).async {
            if (self.captureSession?.isRunning == true) {
                self.captureSession.stopRunning()
            }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if isProcessingBarcode {
            return
        }

        isProcessingBarcode = true
        DispatchQueue.global(qos: .background).async {
            self.captureSession.stopRunning()
        }

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else {
                isProcessingBarcode = false
                return
            }
            guard let stringValue = readableObject.stringValue else {
                isProcessingBarcode = false
                return
            }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
        }
    }

    func found(code: String) {
        let dabasAPISecret = UserDefaultsRepository.dabasAPISecret

        // Check if the Dabas API secret is empty
        if dabasAPISecret.isEmpty {
            self.fetchFromOpenFoodFacts(code: code)
            return
        }

        // Ensure the code is padded to 14 digits with leading zeros
        let paddedCode = code.padLeft(toLength: 14, withPad: "0")

        let dabasURLString = "https://api.dabas.com/DABASService/V2/article/gtin/\(paddedCode)/JSON?apikey=\(dabasAPISecret)"

        // Print the URL to ensure it's correct
        print("Dabas URL: \(dabasURLString)")

        guard let dabasURL = URL(string: dabasURLString) else {
            showErrorAlert(message: "Invalid Dabas URL")
            isProcessingBarcode = false
            return
        }

        let dabasTask = URLSession.shared.dataTask(with: dabasURL) { data, response, error in
            if let error = error {
                print("Dabas API fel: \(error.localizedDescription)")
                self.fetchFromOpenFoodFacts(code: code)
                return
            }

            guard let data = data else {
                print("Dabas API fel: Ingen data ")
                self.fetchFromOpenFoodFacts(code: code)
                return
            }

            do {
                // Attempt to decode JSON response
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    // Print the entire JSON response
                    print("Dabas API Response: \(jsonResponse)")

                    // Extract product name and nutritional information
                    guard let artikelbenamning = jsonResponse["Artikelbenamning"] as? String,
                          let naringsinfoArray = jsonResponse["Naringsinfo"] as? [[String: Any]],
                          let naringsinfo = naringsinfoArray.first,
                          let naringsvarden = naringsinfo["Naringsvarden"] as? [[String: Any]] else {
                        print("Dabas API Error: Missing Artikelbenamning or Naringsinfo")
                        self.fetchFromOpenFoodFacts(code: code)
                        return
                    }

                    // Initialize nutritional values
                    var carbohydrates = 0.0
                    var fat = 0.0
                    var proteins = 0.0

                    // Extract nutritional values
                    for nutrient in naringsvarden {
                        if let code = nutrient["Kod"] as? String, let amount = nutrient["Mangd"] as? Double {
                            switch code {
                            case "CHOAVL":
                                carbohydrates = amount
                            case "FAT":
                                fat = amount
                            case "PRO-":
                                proteins = amount
                            default:
                                break
                            }
                        }
                    }

                    // Construct message to display
                    let message = """
                    Kolhydrater: \(carbohydrates) g / 100 g
                    Fett: \(fat) g / 100 g
                    Protein: \(proteins) g / 100 g

                    [Källa: Dabas]
                    """

                    // Display product alert on the main thread
                    DispatchQueue.main.async {
                        self.showProductAlert(title: artikelbenamning, message: message, productName: artikelbenamning, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                    }
                    print("Dabas produktmatchning OK")
                } else {
                    print("Dabas API fel: Kunde inte tolka svar från servern")
                    self.fetchFromOpenFoodFacts(code: code)
                }
            } catch {
                print("Dabas API fel: \(error.localizedDescription)")
                self.fetchFromOpenFoodFacts(code: code)
            }
        }

        dabasTask.resume()
    }

    func fetchFromOpenFoodFacts(code: String) {
        let urlString = "https://world.openfoodfacts.net/api/v2/product/\(code)?fields=product_name,nutriments"
        guard let url = URL(string: urlString) else {
            showErrorAlert(message: NSLocalizedString("Invalid URL", comment: "Error message for invalid URL"))
            isProcessingBarcode = false
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            defer {
                DispatchQueue.main.async {
                    self.isProcessingBarcode = false
                }
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: String(format: NSLocalizedString("Fel: %@", comment: "Error message format"), error.localizedDescription))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: NSLocalizedString("Ingen data levererades", comment: "No data received error message"))
                }
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let product = jsonResponse["product"] as? [String: Any],
                       let productName = product["product_name"] as? String,
                       let nutriments = product["nutriments"] as? [String: Any] {

                        // Extract nutritional values
                        let carbohydrates = nutriments["carbohydrates_100g"] as? Double ?? 0.0
                        let fat = nutriments["fat_100g"] as? Double ?? 0.0
                        let proteins = nutriments["proteins_100g"] as? Double ?? 0.0

                        // Round nutritional values
                        let adjustedCarbohydrates = carbohydrates.roundToDecimal(1)
                        let adjustedFat = fat.roundToDecimal(1)
                        let adjustedProteins = proteins.roundToDecimal(1)

                        let message = String(format: NSLocalizedString("""
                        Kolhydrater: %.1f g / 100 g
                        Fett: %.1f g / 100 g
                        Protein: %.1f g / 100 g

                        [Källa: Openfoodfacts]
                        """, comment: "Nutritional information displayed for a food product"),
                        adjustedCarbohydrates, adjustedFat, adjustedProteins)

                        DispatchQueue.main.async {
                            self.showProductAlert(title: productName, message: message, productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                        }
                        print(NSLocalizedString("Openfoodfacts produktmatchning OK", comment: "OpenFoodFacts product match success message"))
                    } else {
                        DispatchQueue.main.async {
                            self.showErrorAlert(message: NSLocalizedString("Kunde inte hitta information om livsmedlet", comment: "Error message for missing product information"))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showErrorAlert(message: NSLocalizedString("Kunde inte tolka svar från servern", comment: "Error message for JSON parsing failure"))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: String(format: NSLocalizedString("Fel vid tolkning JSON: %@", comment: "Error message for JSON decoding failure"), error.localizedDescription))
                }
            }
        }
        task.resume()
    }

    func showProductAlert(title: String, message: String, productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", productName)
        
        var isPerPiece: Bool = false // New flag
        
        do {
            let existingItems = try context.fetch(fetchRequest)
            
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )
            
            alert.addTextField { textField in
                textField.placeholder = NSLocalizedString("Ange vikt per styck i gram (valfritt)", comment: "Placeholder for inputting weight per piece in grams (optional)")
                textField.keyboardType = .decimalPad
            }
            
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("Avbryt", comment: "Cancel button"),
                style: .cancel,
                handler: { _ in
                    DispatchQueue.main.async {
                        self.resetBarcodeProcessingState()
                    }
                })
            )
            
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("Lägg till", comment: "Add button"),
                style: .default,
                handler: { _ in
                    let adjustedProductName = productName
                    if let textField = alert.textFields?.first, let text = textField.text, let weight = Double(text), weight > 0 {
                        let adjustedCarbs = (carbohydrates * weight / 100).roundToDecimal(1)
                        let adjustedFat = (fat * weight / 100).roundToDecimal(1)
                        let adjustedProteins = (proteins * weight / 100).roundToDecimal(1)
                        isPerPiece = true // Update the flag
                        self.navigateToAddFoodItem(productName: adjustedProductName, carbohydrates: adjustedCarbs, fat: adjustedFat, proteins: adjustedProteins, isPerPiece: isPerPiece)
                    } else {
                        self.navigateToAddFoodItem(productName: adjustedProductName, carbohydrates: carbohydrates, fat: fat, proteins: proteins, isPerPiece: isPerPiece)
                    }
                })
            )
            
            if let existingItem = existingItems.first {
                let comparisonMessage = String(
                    format: NSLocalizedString("""
                    Befintlig data    ->    Ny data
                    Kh:       %@  ->  %@ g/100g
                    Fett:    %@  ->  %@ g/100g
                    Protein:  %@  ->  %@ g/100g
                    """, comment: "Comparison of existing and new data for carbohydrates, fat, and protein"),
                    formattedValue(existingItem.carbohydrates),
                    formattedValue(carbohydrates),
                    formattedValue(existingItem.fat),
                    formattedValue(fat),
                    formattedValue(existingItem.protein),
                    formattedValue(proteins)
                )
                
                let duplicateAlert = UIAlertController(
                    title: productName,
                    message: "\(NSLocalizedString("Finns redan inlagt i livsmedelslistan.", comment: "Product already exists message")) \n\n\(NSLocalizedString("Vill du behålla de befintliga näringsvärdena eller uppdatera dem?", comment: "Message asking if user wants to keep existing nutritional values or update them"))\n\n\(comparisonMessage)",
                    preferredStyle: .alert
                )
                duplicateAlert.addAction(UIAlertAction(
                    title: NSLocalizedString("Behåll befintliga", comment: "Keep existing data"),
                    style: .default,
                    handler: { _ in
                        self.navigateToAddFoodItem(foodItem: existingItem)
                    })
                )
                duplicateAlert.addAction(UIAlertAction(
                    title: NSLocalizedString("Uppdatera", comment: "Update existing data"),
                    style: .default,
                    handler: { _ in
                        self.navigateToAddFoodItemWithUpdate(existingItem: existingItem, productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                    })
                )
                duplicateAlert.addAction(UIAlertAction(
                    title: NSLocalizedString("Avbryt", comment: "Cancel button"),
                    style: .cancel,
                    handler: { _ in
                        DispatchQueue.main.async {
                            self.resetBarcodeProcessingState()
                        }
                    })
                )
                present(duplicateAlert, animated: true, completion: nil)
            } else {
                present(alert, animated: true, completion: nil)
            }
        } catch {
            showErrorAlert(message: NSLocalizedString("Ett fel uppstod vid hämtning av livsmedelsdata.", comment: "Error message for fetching food item data"))
        }
    }

    func formattedValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func showExistingFoodItem(_ foodItem: FoodItem) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self as? AddFoodItemDelegate
            addFoodItemVC.foodItem = foodItem
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }

    func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Fel", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            DispatchQueue.main.async {
                self.resetBarcodeProcessingState()            }
        }))
        present(alert, animated: true, completion: nil)
    }

    func navigateToAddFoodItem(foodItem: FoodItem) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self as? AddFoodItemDelegate
            addFoodItemVC.foodItem = foodItem
            presentAddFoodItemViewController(addFoodItemVC)
        }
    }

    func navigateToAddFoodItem(productName: String, carbohydrates: Double, fat: Double, proteins: Double, isPerPiece: Bool = false) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self as? AddFoodItemDelegate
            addFoodItemVC.prePopulatedData = (productName, carbohydrates, fat, proteins)
            addFoodItemVC.isPerPiece = isPerPiece // Pass the flag
            presentAddFoodItemViewController(addFoodItemVC)
        }
    }

    func navigateToAddFoodItemWithUpdate(existingItem: FoodItem, productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self as? AddFoodItemDelegate
            addFoodItemVC.foodItem = existingItem
            addFoodItemVC.prePopulatedData = (productName, carbohydrates, fat, proteins)
            addFoodItemVC.isUpdateMode = true
            presentAddFoodItemViewController(addFoodItemVC)
        }
    }

    private func presentAddFoodItemViewController(_ viewController: UIViewController) {
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true, completion: nil)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

// Extension to pad the string to the left
extension String {
func padLeft(toLength: Int, withPad: String) -> String {
let newLength = self.count
if newLength < toLength {
let pad = String(repeating: withPad, count: toLength - newLength)
return pad + self
} else {
return String(self.suffix(toLength))
}
}
}

class ScannerOverlayView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradientBackground()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradientBackground()
    }
    
    private func setupGradientBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.frame = self.bounds
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Calculate the width and height as a percentage of the screen width
        let rectWidth = rect.width * 0.85 // 85% of screen width
        let rectHeight = rectWidth // Make it a square
        let rectX = (rect.width - rectWidth) / 2
        let rectY = (rect.height - rectHeight) / 2
        let cornerRadius: CGFloat = 30
        
        let rectPath = UIBezierPath(roundedRect: CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight), cornerRadius: cornerRadius)
        context.setFillColor(UIColor.systemBackground.withAlphaComponent(0.8).cgColor)
        context.fill(bounds)
        
        context.setBlendMode(.clear)
        context.addPath(rectPath.cgPath)
        context.fillPath()
        
        // Draw focus corners inside the rectangle
        context.setBlendMode(.normal)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(4.0)
        
        let cornerLength: CGFloat = rectWidth * 0.20 // 20% of the rectangle width
        let inset: CGFloat = 25 // Distance inside the rectangle
        let cornerPath = UIBezierPath()
        
        // Top-left corner
        cornerPath.move(to: CGPoint(x: rectX + inset, y: rectY + inset + cornerLength))
        cornerPath.addLine(to: CGPoint(x: rectX + inset, y: rectY + inset + cornerRadius))
        cornerPath.addArc(withCenter: CGPoint(x: rectX + inset + cornerRadius, y: rectY + inset + cornerRadius), radius: cornerRadius, startAngle: CGFloat.pi, endAngle: 3 * CGFloat.pi / 2, clockwise: true)
        cornerPath.addLine(to: CGPoint(x: rectX + inset + cornerLength, y: rectY + inset))
        
        // Top-right corner
        cornerPath.move(to: CGPoint(x: rectX + rectWidth - inset - cornerLength, y: rectY + inset))
        cornerPath.addLine(to: CGPoint(x: rectX + rectWidth - inset - cornerRadius, y: rectY + inset))
        cornerPath.addArc(withCenter: CGPoint(x: rectX + rectWidth - inset - cornerRadius, y: rectY + inset + cornerRadius), radius: cornerRadius, startAngle: 3 * CGFloat.pi / 2, endAngle: 0, clockwise: true)
        cornerPath.addLine(to: CGPoint(x: rectX + rectWidth - inset, y: rectY + inset + cornerLength))
        
        // Bottom-right corner
        cornerPath.move(to: CGPoint(x: rectX + rectWidth - inset, y: rectY + rectHeight - inset - cornerLength))
        cornerPath.addLine(to: CGPoint(x: rectX + rectWidth - inset, y: rectY + rectHeight - inset - cornerRadius))
        cornerPath.addArc(withCenter: CGPoint(x: rectX + rectWidth - inset - cornerRadius, y: rectY + rectHeight - inset - cornerRadius), radius: cornerRadius, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: true)
        cornerPath.addLine(to: CGPoint(x: rectX + rectWidth - inset - cornerLength, y: rectY + rectHeight - inset))
        
        // Bottom-left corner
        cornerPath.move(to: CGPoint(x: rectX + inset + cornerLength, y: rectY + rectHeight - inset))
        cornerPath.addLine(to: CGPoint(x: rectX + inset + cornerRadius, y: rectY + rectHeight - inset))
        cornerPath.addArc(withCenter: CGPoint(x: rectX + inset + cornerRadius, y: rectY + rectHeight - inset - cornerRadius), radius: cornerRadius, startAngle: CGFloat.pi / 2, endAngle: CGFloat.pi, clockwise: true)
        cornerPath.addLine(to: CGPoint(x: rectX + inset, y: rectY + rectHeight - inset - cornerLength))
        
        context.addPath(cornerPath.cgPath)
        context.strokePath()
    }
}
