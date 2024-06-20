import UIKit
import CoreData

protocol AddFoodItemDelegate: AnyObject {
    func didAddFoodItem()
}

class AddFoodItemViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var carbsTextField: UITextField!
    @IBOutlet weak var fatTextField: UITextField!
    @IBOutlet weak var proteinTextField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var foodItemView: UIView!
    @IBOutlet weak var carbohydratesView: UIView!
    @IBOutlet weak var proteinView: UIView!
    @IBOutlet weak var fatView: UIView!
    @IBOutlet weak var carbsUnits: UILabel!
    @IBOutlet weak var fatUnits: UILabel!
    @IBOutlet weak var proteinUnits: UILabel!
    
    weak var delegate: AddFoodItemDelegate?
    var foodItem: FoodItem?
    var isPerPiece: Bool = false // To keep track of the selected segment
    var segmentedControl: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupSegmentedControl()
        setupSaveButton()
        setupUI()
        
        foodItemView.layer.cornerRadius = 8
        foodItemView.layer.masksToBounds = true
        
        carbohydratesView.layer.cornerRadius = 8
        carbohydratesView.layer.masksToBounds = true
        
        proteinView.layer.cornerRadius = 8
        proteinView.layer.masksToBounds = true
        
        fatView.layer.cornerRadius = 8
        fatView.layer.masksToBounds = true
        
        // Set delegates
        nameTextField.delegate = self
        carbsTextField.delegate = self
        fatTextField.delegate = self
        proteinTextField.delegate = self
        
        // Disable autocorrect
        nameTextField.autocorrectionType = .no
        carbsTextField.autocorrectionType = .no
        fatTextField.autocorrectionType = .no
        proteinTextField.autocorrectionType = .no
        
        // Add toolbar with "Next" and "Done" buttons
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let nextButton = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(nextButtonTapped))
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneButtonTapped))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.setItems([nextButton, flexibleSpace, doneButton], animated: false)
        
        nameTextField.inputAccessoryView = toolbar
        carbsTextField.inputAccessoryView = toolbar
        fatTextField.inputAccessoryView = toolbar
        proteinTextField.inputAccessoryView = toolbar
        
        // Add Cancel button to the navigation bar
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = cancelButton
    }
    
    @objc func nextButtonTapped() {
        if nameTextField.isFirstResponder {
            carbsTextField.becomeFirstResponder()
        } else if carbsTextField.isFirstResponder {
            fatTextField.becomeFirstResponder()
        } else if fatTextField.isFirstResponder {
            proteinTextField.becomeFirstResponder()
        } else if proteinTextField.isFirstResponder {
            nameTextField.becomeFirstResponder()
        }
    }
    
    @objc func doneButtonTapped() {
        view.endEditing(true)
    }
    
    @objc func cancelButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameTextField.becomeFirstResponder() // Make nameTextField the first responder
    }
    
    // Hide the autocorrect bar
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        textField.autocorrectionType = .no
        return true
    }
    
    private func setupSegmentedControl() {
        segmentedControl = UISegmentedControl(items: ["Per 100g", "Per Piece"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(segmentedControl)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    @objc func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        isPerPiece = sender.selectedSegmentIndex == 1
        updateUnitsLabels()
        clearOppositeFields()
    }
    
    private func updateUnitsLabels() {
        if isPerPiece {
            carbsUnits.text = "g/piece"
            fatUnits.text = "g/piece"
            proteinUnits.text = "g/piece"
        } else {
            carbsUnits.text = "g/100g"
            fatUnits.text = "g/100g"
            proteinUnits.text = "g/100g"
        }
    }
    
    private func clearOppositeFields() {
        if isPerPiece {
            carbsTextField.text = ""
            fatTextField.text = ""
            proteinTextField.text = ""
        } else {
            carbsTextField.text = ""
            fatTextField.text = ""
            proteinTextField.text = ""
        }
    }
    
    private func setupSaveButton() {
        saveButton.setTitle("Save", for: .normal)
        saveButton.addTarget(self, action: #selector(saveButtonTap), for: .touchUpInside)
    }
    
    private func setupUI() {
        if let foodItem = foodItem {
            title = "Edit Food Item"
            nameTextField.text = foodItem.name
            if foodItem.perPiece {
                isPerPiece = true
                segmentedControl.selectedSegmentIndex = 1
                carbsTextField.text = String(foodItem.carbsPP)
                fatTextField.text = String(foodItem.fatPP)
                proteinTextField.text = String(foodItem.proteinPP)
            } else {
                isPerPiece = false
                segmentedControl.selectedSegmentIndex = 0
                carbsTextField.text = String(foodItem.carbohydrates)
                fatTextField.text = String(foodItem.fat)
                proteinTextField.text = String(foodItem.protein)
            }
        } else {
            title = "Add Food Item"
        }
        updateUnitsLabels() // Ensure labels are set correctly when the view is loaded
    }
    
    @IBAction func saveButtonTap(_ sender: UIButton) {
        saveFoodItem()
        print("Save button tapped")
    }
    
    private func saveFoodItem() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        
        // Helper method to replace commas with periods
        func sanitize(_ text: String?) -> String {
            return text?.replacingOccurrences(of: ",", with: ".") ?? ""
        }
        
        if let foodItem = foodItem {
            // Update existing food item
            foodItem.name = nameTextField.text ?? ""
            if isPerPiece {
                foodItem.carbsPP = Double(sanitize(carbsTextField.text)) ?? 0.0
                foodItem.fatPP = Double(sanitize(fatTextField.text)) ?? 0.0
                foodItem.proteinPP = Double(sanitize(proteinTextField.text)) ?? 0.0
                foodItem.perPiece = true
                foodItem.carbohydrates = 0.0
                foodItem.fat = 0.0
                foodItem.protein = 0.0
            } else {
                foodItem.carbohydrates = Double(sanitize(carbsTextField.text)) ?? 0.0
                foodItem.fat = Double(sanitize(fatTextField.text)) ?? 0.0
                foodItem.protein = Double(sanitize(proteinTextField.text)) ?? 0.0
                foodItem.perPiece = false
                foodItem.carbsPP = 0.0
                foodItem.fatPP = 0.0
                foodItem.proteinPP = 0.0
            }
        } else {
            // Create new food item
            let newFoodItem = FoodItem(context: context)
            newFoodItem.id = UUID()
            newFoodItem.name = nameTextField.text ?? ""
            if isPerPiece {
                newFoodItem.carbsPP = Double(sanitize(carbsTextField.text)) ?? 0.0
                newFoodItem.fatPP = Double(sanitize(fatTextField.text)) ?? 0.0
                newFoodItem.proteinPP = Double(sanitize(proteinTextField.text)) ?? 0.0
                newFoodItem.perPiece = true
                newFoodItem.carbohydrates = 0.0
                newFoodItem.fat = 0.0
                newFoodItem.protein = 0.0
            } else {
                newFoodItem.carbohydrates = Double(sanitize(carbsTextField.text)) ?? 0.0
                newFoodItem.fat = Double(sanitize(fatTextField.text)) ?? 0.0
                newFoodItem.protein = Double(sanitize(proteinTextField.text)) ?? 0.0
                newFoodItem.perPiece = false
                newFoodItem.carbsPP = 0.0
                newFoodItem.fatPP = 0.0
                newFoodItem.proteinPP = 0.0
            }
        }
        
        do {
            try context.save()
            delegate?.didAddFoodItem()
            NotificationCenter.default.post(name: .foodItemsDidChange, object: nil, userInfo: ["foodItems": fetchAllFoodItems()])
            if let navController = navigationController {
                print("Navigation Controller exists")
                navController.popViewController(animated: true) // Dismiss the view
            } else {
                print("Navigation Controller is nil")
            }
        } catch {
            print("Failed to save food item: \(error)")
        }
    }

    private func fetchAllFoodItems() -> [FoodItem] {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return [] }
        let context = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch food items: \(error)")
            return []
        }
    }
}
