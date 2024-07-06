import AVFoundation
import CoreData
import UIKit

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var isProcessingBarcode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417]
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
        
        // Add cancel button to the navigation bar
        let cancelButton = UIBarButtonItem(title: "Avbryt", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = cancelButton
    }
    
    func resetBarcodeProcessingState() {
        DispatchQueue.global(qos: .background).async {
            self.isProcessingBarcode = false
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    @objc private func cancelButtonTapped() {
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
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
            showErrorAlert(message: "Invalid URL")
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
                    self.showErrorAlert(message: "Fel: \(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Ingen data levererades")
                }
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let product = jsonResponse["product"] as? [String: Any],
                       let productName = product["product_name"] as? String,
                       let nutriments = product["nutriments"] as? [String: Any] {
                        
                        let carbohydrates = nutriments["carbohydrates_100g"] as? Double ?? 0.0
                        let fat = nutriments["fat_100g"] as? Double ?? 0.0
                        let proteins = nutriments["proteins_100g"] as? Double ?? 0.0
                        
                        let message = """
                        Kolhydrater: \(carbohydrates) g / 100 g
                        Fett: \(fat) g / 100 g
                        Protein: \(proteins) g / 100 g
                        
                        [Källa: Openfoodfacts]
                        """
                        
                        DispatchQueue.main.async {
                            self.showProductAlert(title: productName, message: message, productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                        }
                        print("Openfoodfacts produktmatchning OK")
                    } else {
                        DispatchQueue.main.async {
                            self.showErrorAlert(message: "Kunde inte hitta information om livsmedlet")
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showErrorAlert(message: "Kunde inte tolka svar från servern")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Fel vid tolkning JSON: (error.localizedDescription)")
                }
            }
        }
        task.resume()
    }
    
    func showProductAlert(title: String, message: String, productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", productName)
        
        do {
            let existingItems = try context.fetch(fetchRequest)
            
            if let existingItem = existingItems.first {
                let comparisonMessage = """
            Befintlig data    ->    Ny data
            Kh:       \(formattedValue(existingItem.carbohydrates))  ->  \(formattedValue(carbohydrates)) g/100g
            Fett:    \(formattedValue(existingItem.fat))  ->  \(formattedValue(fat)) g/100g
            Protein:  \(formattedValue(existingItem.protein))  ->  \(formattedValue(proteins)) g/100g
            """
                
                let duplicateAlert = UIAlertController(title: productName, message: "Finns redan inlagt i livsmedelslistan. \n\nVill du behålla de befintliga näringsvärdena eller uppdatera dem?\n\n\(comparisonMessage)", preferredStyle: .alert)
                duplicateAlert.addAction(UIAlertAction(title: "Behåll befintliga", style: .default, handler: { _ in
                    self.navigateToAddFoodItem(foodItem: existingItem)
                }))
                duplicateAlert.addAction(UIAlertAction(title: "Uppdatera", style: .default, handler: { _ in
                    self.navigateToAddFoodItemWithUpdate(existingItem: existingItem, productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                }))
                duplicateAlert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { _ in
                    DispatchQueue.main.async {
                        self.resetBarcodeProcessingState()
                    }
                }))
                present(duplicateAlert, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { _ in
                    DispatchQueue.main.async {
                        self.resetBarcodeProcessingState()
                    }
                }))
                alert.addAction(UIAlertAction(title: "Lägg till", style: .default, handler: { _ in
                    self.navigateToAddFoodItem(productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                }))
                present(alert, animated: true, completion: nil)
            }
        } catch {
            showErrorAlert(message: "Ett fel uppstod vid hämtning av livsmedelsdata.")
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
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }
    
    func navigateToAddFoodItem(productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self as? AddFoodItemDelegate
            addFoodItemVC.prePopulatedData = (productName, carbohydrates, fat, proteins)
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }
    
    func navigateToAddFoodItemWithUpdate(existingItem: FoodItem, productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self as? AddFoodItemDelegate
            addFoodItemVC.foodItem = existingItem
            addFoodItemVC.prePopulatedData = (productName, carbohydrates, fat, proteins)
            addFoodItemVC.isUpdateMode = true
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
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
