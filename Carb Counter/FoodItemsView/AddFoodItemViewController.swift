import UIKit
import CoreData

protocol AddFoodItemDelegate: AnyObject {
    func didAddFoodItem()
}

class AddFoodItemViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emojiTextField: UITextField!
    @IBOutlet weak var carbsTextField: UITextField!
    @IBOutlet weak var fatTextField: UITextField!
    @IBOutlet weak var proteinTextField: UITextField!
    @IBOutlet weak var notesTextField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var saveAndAddButton: UIButton!
    @IBOutlet weak var foodItemView: UIView!
    @IBOutlet weak var carbohydratesView: UIView!
    @IBOutlet weak var proteinView: UIView!
    @IBOutlet weak var fatView: UIView!
    @IBOutlet weak var notesView: UIView!
    @IBOutlet weak var carbsUnits: UILabel!
    @IBOutlet weak var fatUnits: UILabel!
    @IBOutlet weak var proteinUnits: UILabel!
    @IBOutlet weak var nameStack: UIStackView!
    @IBOutlet weak var carbsStack: UIStackView!
    @IBOutlet weak var fatStack: UIStackView!
    @IBOutlet weak var proteinStack: UIStackView!
    @IBOutlet weak var notesStack: UIStackView!
    
    var delegate: AddFoodItemDelegate?
    var foodItem: FoodItem?
    var isPerPiece: Bool = false // To keep track of the selected segment
    var segmentedControl: UISegmentedControl!
    
    // Variables to store initial values
    var initialName: String?
    var initialEmoji: String?
    var initialNotes: String?
    var initialCarbs: String?
    var initialFat: String?
    var initialProtein: String?
    
    var prePopulatedData: (name: String, carbohydrates: Double, fat: Double, protein: Double)?
    var isUpdateMode: Bool = false // Add this flag to indicate update mode
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupSegmentedControl()
        setupSaveButton()
        setupSaveAndAddButton()
        setupUI()
        
        foodItemView.layer.cornerRadius = 8
        foodItemView.layer.masksToBounds = true
        
        carbohydratesView.layer.cornerRadius = 8
        carbohydratesView.layer.masksToBounds = true
        
        proteinView.layer.cornerRadius = 8
        proteinView.layer.masksToBounds = true
        
        fatView.layer.cornerRadius = 8
        fatView.layer.masksToBounds = true
        
        notesView.layer.cornerRadius = 8
        notesView.layer.masksToBounds = true
        
        // Set delegates
        nameTextField.delegate = self
        emojiTextField.delegate = self
        carbsTextField.delegate = self
        fatTextField.delegate = self
        proteinTextField.delegate = self
        notesTextField.delegate = self
        
        // Disable autocorrect
        nameTextField.autocorrectionType = .no
        emojiTextField.autocorrectionType = .no
        carbsTextField.autocorrectionType = .no
        fatTextField.autocorrectionType = .no
        proteinTextField.autocorrectionType = .no
        notesTextField.autocorrectionType = .no
        
        // Add Cancel button to the navigation bar
        let cancelButton = UIBarButtonItem(title: "Avbryt", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = cancelButton
        
        // Add toolbar with "Next" and "Done" buttons
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let nextButton = UIBarButtonItem(title: "Nästa", style: .plain, target: self, action: #selector(nextButtonTapped))
        let doneButton = UIBarButtonItem(title: "Klar", style: .plain, target: self, action: #selector(doneButtonTapped))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.setItems([nextButton, flexibleSpace, doneButton], animated: false)
        
        nameTextField.inputAccessoryView = toolbar
        emojiTextField.inputAccessoryView = toolbar
        carbsTextField.inputAccessoryView = toolbar
        fatTextField.inputAccessoryView = toolbar
        proteinTextField.inputAccessoryView = toolbar
        notesTextField.inputAccessoryView = toolbar
        
        // Store initial values
        initialName = nameTextField.text
        initialEmoji = emojiTextField.text
        initialCarbs = carbsTextField.text
        initialFat = fatTextField.text
        initialProtein = proteinTextField.text
        initialNotes = notesTextField.text
        
        // Observe text field changes
        nameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        emojiTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        carbsTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        fatTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        proteinTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        notesTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        // Add tap gesture recognizers to labels
        addTapGestureRecognizers()
        
        if let data = prePopulatedData {
            nameTextField.text = data.name
            carbsTextField.text = formattedValue(data.carbohydrates)
            fatTextField.text = formattedValue(data.fat)
            proteinTextField.text = formattedValue(data.protein)
            
            // Enable buttons if prePopulatedData is not nil
            saveButton.isEnabled = true
            saveAndAddButton.isEnabled = true
            updateSaveButtonTitle()
        }
    }
    
    // Helper method to format the double values
    func formattedValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    private func addTapGestureRecognizers() {
        let nameTapGesture = UITapGestureRecognizer(target: self, action: #selector(nameStackTapped))
        nameStack.addGestureRecognizer(nameTapGesture)
        nameStack.isUserInteractionEnabled = true
        
        let carbsTapGesture = UITapGestureRecognizer(target: self, action: #selector(carbsStackTapped))
        carbsStack.addGestureRecognizer(carbsTapGesture)
        carbsStack.isUserInteractionEnabled = true
        
        let fatTapGesture = UITapGestureRecognizer(target: self, action: #selector(fatStackTapped))
        fatStack.addGestureRecognizer(fatTapGesture)
        fatStack.isUserInteractionEnabled = true
        
        let proteinTapGesture = UITapGestureRecognizer(target: self, action: #selector(proteinStackTapped))
        proteinStack.addGestureRecognizer(proteinTapGesture)
        proteinStack.isUserInteractionEnabled = true
        
        let notesTapGesture = UITapGestureRecognizer(target: self, action: #selector(notesStackTapped))
        notesStack.addGestureRecognizer(notesTapGesture)
        notesStack.isUserInteractionEnabled = true
    }
    
    @objc private func nameStackTapped() {
        nameTextField.becomeFirstResponder()
    }
    
    @objc private func carbsStackTapped() {
        carbsTextField.becomeFirstResponder()
    }
    
    @objc private func fatStackTapped() {
        fatTextField.becomeFirstResponder()
    }
    
    @objc private func proteinStackTapped() {
        proteinTextField.becomeFirstResponder()
    }
    
    @objc private func notesStackTapped() {
        notesTextField.becomeFirstResponder()
    }
    
    @objc func nextButtonTapped() {
        if nameTextField.isFirstResponder {
            emojiTextField.becomeFirstResponder()
        } else if emojiTextField.isFirstResponder {
            carbsTextField.becomeFirstResponder()
        } else if carbsTextField.isFirstResponder {
            fatTextField.becomeFirstResponder()
        } else if fatTextField.isFirstResponder {
            proteinTextField.becomeFirstResponder()
        } else if proteinTextField.isFirstResponder {
            notesTextField.becomeFirstResponder()
        } else if notesTextField.isFirstResponder {
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
        segmentedControl = UISegmentedControl(items: ["Per 100g", "Per Styck"])
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
        checkForChanges()
    }
    
    private func updateUnitsLabels() {
        if isPerPiece {
            carbsUnits.text = "g/st"
            fatUnits.text = "g/st"
            proteinUnits.text = "g/st"
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
        saveButton.addTarget(self, action: #selector(saveButtonTap), for: .touchUpInside)
        saveButton.isEnabled = false // Initially disabled
        saveButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline) // Set headline font
        updateSaveButtonTitle()
    }
    
    private func setupSaveAndAddButton() {
        saveAndAddButton.addTarget(self, action: #selector(saveAndAddTap), for: .touchUpInside)
        saveAndAddButton.isEnabled = false // Initially disabled
    }
    
    private func updateButtonTitle(_ button: UIButton, withTitle title: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .headline)
        ]
        let attributedTitle = NSAttributedString(string: title, attributes: attributes)
        button.setAttributedTitle(attributedTitle, for: .normal)
    }
    
    private func updateSaveButtonTitle() {
        if let foodItem = foodItem {
            // Edit mode
            if saveButton.isEnabled {
                updateButtonTitle(saveButton, withTitle: "Spara ändringar")
            } else {
                updateButtonTitle(saveButton, withTitle: "Inga ändringar")
            }
        } else {
            // New mode
            updateButtonTitle(saveButton, withTitle: "Spara")
        }
    }
    
    private func setupUI() {
        if let foodItem = foodItem {
            title = "Ändra livsmedel"
            nameTextField.text = foodItem.name
            notesTextField.text = foodItem.notes
            emojiTextField.text = foodItem.emoji
            if foodItem.perPiece {
                isPerPiece = true
                segmentedControl.selectedSegmentIndex = 1
                carbsTextField.text = formattedValue(foodItem.carbsPP)
                fatTextField.text = formattedValue(foodItem.fatPP)
                proteinTextField.text = formattedValue(foodItem.proteinPP)
            } else {
                isPerPiece = false
                segmentedControl.selectedSegmentIndex = 0
                carbsTextField.text = formattedValue(foodItem.carbohydrates)
                fatTextField.text = formattedValue(foodItem.fat)
                proteinTextField.text = formattedValue(foodItem.protein)
            }
            
            if isUpdateMode, let data = prePopulatedData {
                carbsTextField.text = formattedValue(data.carbohydrates)
                fatTextField.text = formattedValue(data.fat)
                proteinTextField.text = formattedValue(data.protein)
            }
        } else {
            title = "Lägg till livsmedel"
            if isUpdateMode, let data = prePopulatedData {
                nameTextField.text = data.name
                carbsTextField.text = formattedValue(data.carbohydrates)
                fatTextField.text = formattedValue(data.fat)
                proteinTextField.text = formattedValue(data.protein)
            }
        }
        updateUnitsLabels() // Ensure labels are set correctly when the view is loaded
    }
    
    @IBAction func saveButtonTap(_ sender: UIButton) {
        saveFoodItem()
        print("Save button tapped")
    }
    @IBAction func saveAndAddTap(_ sender: UIButton) {
        saveFoodItem(addToMeal: true)
        print("Save & add button tapped")
    }
    
    private func saveFoodItem(addToMeal: Bool = false) {
        let context = CoreDataStack.shared.context
        
        // Helper method to replace commas with periods
        func sanitize(_ text: String?) -> String {
            return text?.replacingOccurrences(of: ",", with: ".") ?? ""
        }
        
        if let foodItem = foodItem {
            // Update existing food item
            foodItem.name = nameTextField.text ?? ""
            foodItem.notes = notesTextField.text ?? ""
            foodItem.emoji = emojiTextField.text ?? ""
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
            print("Updated existing food item: \(foodItem.name ?? "")")
        } else {
            // Create new food item
            let newFoodItem = FoodItem(context: context)
            newFoodItem.id = UUID()
            newFoodItem.name = nameTextField.text ?? ""
            newFoodItem.notes = notesTextField.text ?? ""
            newFoodItem.emoji = emojiTextField.text ?? ""
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
            newFoodItem.count = 0
            foodItem = newFoodItem // Assign the new food item to the foodItem variable for later use
            print("Created new food item: \(newFoodItem.name ?? "")")
        }
        
        do {
            try context.save()
            print("Saved food item successfully.")
            delegate?.didAddFoodItem()
            NotificationCenter.default.post(name: .foodItemsDidChange, object: nil, userInfo: ["foodItems": fetchAllFoodItems()])
            
            if addToMeal {
                addToComposeMealViewController()
            }
        } catch {
            print("Failed to save food item: \(error)")
        }
        navigationController?.popViewController(animated: true)
    }
    
    private func addToComposeMealViewController() {
        guard let tabBarController = tabBarController else {
            print("Tab bar controller not found")
            return
        }
        
        for viewController in tabBarController.viewControllers ?? [] {
            if let navController = viewController as? UINavigationController {
                for vc in navController.viewControllers {
                    if let composeMealVC = vc as? ComposeMealViewController {
                        if let newFoodItem = foodItem {
                            print("Adding food item to ComposeMealViewController: \(newFoodItem.name ?? "")")
                            composeMealVC.addFoodItemRow(with: newFoodItem)
                        }
                        return
                    }
                }
            }
        }
        print("ComposeMealViewController not found in tab bar controller")
    }
    
    private func fetchAllFoodItems() -> [FoodItem] {
        let context = CoreDataStack.shared.context
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch food items: \(error)")
            return []
        }
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        checkForChanges()
    }
    
    private func checkForChanges() {
        let currentName = nameTextField.text
        let currentEmoji = emojiTextField.text
        let currentNotes = notesTextField.text
        let currentCarbs = carbsTextField.text
        let currentFat = fatTextField.text
        let currentProtein = proteinTextField.text
        let nameChanged = currentName != initialName
        let emojiChanged = currentEmoji != initialEmoji
        let notesChanged = currentNotes != initialNotes
        let carbsChanged = currentCarbs != initialCarbs
        let fatChanged = currentFat != initialFat
        let proteinChanged = currentProtein != initialProtein
        saveButton.isEnabled = nameChanged || emojiChanged || carbsChanged || fatChanged || proteinChanged || notesChanged
        saveAndAddButton.isEnabled = saveButton.isEnabled
        updateSaveButtonTitle()
    }
}
