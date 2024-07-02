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
                        """

                        DispatchQueue.main.async {
                            self.showProductAlert(title: productName, message: message, productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showErrorAlert(message: "Kunde inte hämta livsmedelsdetaljer")
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showErrorAlert(message: "Kunde inte tolka JSON svar")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Fel vid tolkning JSON: \(error.localizedDescription)")
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
                let duplicateAlert = UIAlertController(title: productName, message: "Finns redan i livsmedelslistan. \n\nVill du visa eller uppdatera den befintliga posten?", preferredStyle: .alert)
                duplicateAlert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { _ in
                    DispatchQueue.global(qos: .background).async {
                        self.captureSession.startRunning()
                    }
                }))
                duplicateAlert.addAction(UIAlertAction(title: "Visa", style: .default, handler: { _ in
                    self.navigateToAddFoodItem(foodItem: existingItem)
                }))
                duplicateAlert.addAction(UIAlertAction(title: "Uppdatera", style: .default, handler: { _ in
                    self.navigateToAddFoodItemWithUpdate(existingItem: existingItem, productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
                }))
                present(duplicateAlert, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { _ in
                    DispatchQueue.global(qos: .background).async {
                        self.captureSession.startRunning()
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

    func showExistingFoodItem(_ foodItem: FoodItem) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
            addFoodItemVC.delegate = self as? AddFoodItemDelegate
            addFoodItemVC.foodItem = foodItem
            navigationController?.pushViewController(addFoodItemVC, animated: true)
        }
    }

    func updateExistingFoodItem(_ foodItem: FoodItem, carbohydrates: Double, fat: Double, proteins: Double) {
        foodItem.carbohydrates = carbohydrates
        foodItem.fat = fat
        foodItem.protein = proteins

        do {
            try CoreDataStack.shared.context.save()
            showErrorAlert(message: "Livsmedel uppdaterad")
        } catch {
            showErrorAlert(message: "Fel vid uppdatering av livsmedel")
        }
    }
    func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Fel", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
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
