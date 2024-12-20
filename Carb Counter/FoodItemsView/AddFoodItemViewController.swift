// Daniel: 600+ lines - To be cleaned
import UIKit
import CoreData
import ISEmojiView

protocol AddFoodItemDelegate: AnyObject {
    func didAddFoodItem(foodItem: FoodItem)
    func didSaveAndClose(foodItem: FoodItem)
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
    
    var dataSharingVC: DataSharingViewController?
    
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
    var previousSegmentIndex: Int = 0
    
    var prePopulatedData: (name: String, carbohydrates: Double, fat: Double, protein: Double, emoji: String, notes: String, isPerPiece: Bool, carbsPP: Double, fatPP: Double, proteinPP: Double)?
    var isUpdateMode: Bool = false // Add this flag to indicate update mode
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Lägg till livsmedel", comment: "Add food item screen title")
        
        // Create keyboard settings with default initialization
            let keyboardSettings = KeyboardSettings(bottomType: .categories)

            // Now set the additional properties on the KeyboardSettings object
            keyboardSettings.countOfRecentsEmojis = 42 // Example: change the number of recent emojis
            keyboardSettings.needToShowAbcButton = false // Show the ABC button
            keyboardSettings.needToShowDeleteButton = true // Show the delete button
            keyboardSettings.updateRecentEmojiImmediately = true // Update recent emojis immediately

            // Initialize EmojiView with the custom settings
            let emojiView = EmojiView(keyboardSettings: keyboardSettings)
            emojiView.translatesAutoresizingMaskIntoConstraints = false
            emojiView.delegate = self
        
        let bottomView = emojiView.subviews.last?.subviews.last
        let collecitonViewToSuperViewTrailingConstraint = bottomView?.value(forKey: "collecitonViewToSuperViewTrailingConstraint") as? NSLayoutConstraint
        collecitonViewToSuperViewTrailingConstraint?.priority = .defaultLow

            // Assign the custom emoji keyboard to the emojiTextField
            emojiTextField.inputView = emojiView
        
        // Check if the app is in dark mode and set the background accordingly
        updateBackgroundForCurrentMode()

        
        setupSegmentedControl()
        setupSaveButton()
        setupSaveAndAddButton()
        setupUI()
        
        // Apply rounded font to saveButton
            if let saveButtonFontDescriptor = saveButton.titleLabel?.font.fontDescriptor.withDesign(.rounded) {
                saveButton.titleLabel?.font = UIFont(descriptor: saveButtonFontDescriptor, size: saveButton.titleLabel?.font.pointSize ?? 17)
            }

            // Apply rounded font to saveAndAddButton
            if let saveAndAddButtonFontDescriptor = saveAndAddButton.titleLabel?.font.fontDescriptor.withDesign(.rounded) {
                saveAndAddButton.titleLabel?.font = UIFont(descriptor: saveAndAddButtonFontDescriptor, size: saveAndAddButton.titleLabel?.font.pointSize ?? 17)
            }
        
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
        
        // Add toolbar with "Next" and "Done" buttons
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let nextButton = UIBarButtonItem(title: NSLocalizedString("Nästa", comment: "Button title for proceeding to the next step"), style: .plain, target: self, action: #selector(nextButtonTapped))
        let doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Button title for finishing the process"), style: .plain, target: self, action: #selector(doneButtonTapped))
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
            emojiTextField.text = data.emoji
            notesTextField.text = data.notes
            
            if data.isPerPiece {
                carbsTextField.text = formattedValue(data.carbsPP)
                fatTextField.text = formattedValue(data.fatPP)
                proteinTextField.text = formattedValue(data.proteinPP)
                segmentedControl.selectedSegmentIndex = 1 // Set to "Per Piece"
            } else {
                carbsTextField.text = formattedValue(data.carbohydrates)
                fatTextField.text = formattedValue(data.fat)
                proteinTextField.text = formattedValue(data.protein)
                segmentedControl.selectedSegmentIndex = 0 // Set to "Per 100g"
            }
            if isUpdateMode {
                saveButton.isEnabled = false
                saveAndAddButton.isEnabled = false
            } else {
                saveButton.isEnabled = true
                saveAndAddButton.isEnabled = true
            }
            updateSaveButtonTitle()
            setupUI()
        }
        
        if isPerPiece {
                segmentedControl.selectedSegmentIndex = 1
            } else {
                segmentedControl.selectedSegmentIndex = 0
            }
        
        // Instantiate DataSharingViewController programmatically
        dataSharingVC = DataSharingViewController()
        
        // Add close button only if presented modally
        if self.isModal() {
            setupCloseButton()
        }
        previousSegmentIndex = segmentedControl.selectedSegmentIndex  // Store the initial index
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
    
    private func setupCloseButton() {
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    private func isModal() -> Bool {
        if self.presentingViewController != nil {
            return true
        }
        if self.navigationController?.presentingViewController?.presentedViewController == self.navigationController {
            return true
        }
        if self.tabBarController?.presentingViewController is UITabBarController {
            return true
        }
        return false
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
        // Initialize with default labels
        let initialItems = [
            NSLocalizedString("Per 100g", comment: "Segment label for per 100 grams"),
            NSLocalizedString("Per Styck", comment: "Segment label for per piece")
        ]
        segmentedControl = UISegmentedControl(items: initialItems)
        segmentedControl.selectedSegmentIndex = isPerPiece ? 1 : 0
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func updateSegmentedControlLabels() {
        if foodItem != nil { // Check if we are in "Ändra livsmedel" mode
            if isPerPiece {
                segmentedControl.setTitle(NSLocalizedString("  Ändra till per 100g   ←", comment: "Change to per 100g"), forSegmentAt: 0)
                segmentedControl.setTitle(NSLocalizedString("Per Styck", comment: "Per piece label"), forSegmentAt: 1)
            } else {
                segmentedControl.setTitle(NSLocalizedString("Per 100g", comment: "Per 100 grams label"), forSegmentAt: 0)
                segmentedControl.setTitle(NSLocalizedString("→   Ändra till per st  ", comment: "Change to per piece"), forSegmentAt: 1)
            }
        } else {
            // Default labels for "Lägg till nytt livsmedel" mode
            segmentedControl.setTitle(NSLocalizedString("Per 100g", comment: "Per 100 grams label"), forSegmentAt: 0)
            segmentedControl.setTitle(NSLocalizedString("Per Styck", comment: "Per piece label"), forSegmentAt: 1)
        }
    }
    
    @objc func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        // Store the current segment index before any changes
        let currentIndex = sender.selectedSegmentIndex

        // Check if all the text fields are empty or contain a value of 0
        let areAllFieldsEmptyOrZero = (self.carbsTextField.text?.isEmpty ?? true || self.carbsTextField.text == "0" || self.carbsTextField.text == "0.0") &&
                                      (self.fatTextField.text?.isEmpty ?? true || self.fatTextField.text == "0" || self.fatTextField.text == "0.0") &&
                                      (self.proteinTextField.text?.isEmpty ?? true || self.proteinTextField.text == "0" || self.proteinTextField.text == "0.0")

        // If all fields are empty or zero, skip showing the alert
        if areAllFieldsEmptyOrZero {
            // Simply update the segmented control without showing the alert
            self.isPerPiece = sender.selectedSegmentIndex == 1
            self.updateUnitsLabels()
            self.checkForChanges()
            self.updateSegmentedControlLabels()
            return
        }

        // Show alert with text field if any nutritional value is present
        let alert = UIAlertController(title: NSLocalizedString("Omvandla näringsvärden", comment: "Enter weight per piece"), message: "", preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.keyboardType = .decimalPad
            textField.placeholder = NSLocalizedString("Ange vikt/styck (g)", comment: "Weight placeholder")
        }

        // Cancel action that restores the previous segment index
        alert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel button"), style: .cancel, handler: { _ in
            // Restore the previous segment index when cancelled
            sender.selectedSegmentIndex = self.previousSegmentIndex
        }))

        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK button"), style: .default, handler: { _ in
            if let textField = alert.textFields?.first, let weightText = textField.text?.replacingOccurrences(of: ",", with: "."), let weight = Double(weightText), weight > 0 {

                // Function to remove unnecessary .0
                func formatValue(_ value: Double) -> String {
                    return value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)
                }

                if self.isPerPiece {
                    // Convert current values to per 100g
                    if let carbsText = self.carbsTextField.text?.replacingOccurrences(of: ",", with: "."), let carbsValue = Double(carbsText) {
                        self.carbsTextField.text = carbsValue == 0 ? "" : formatValue(carbsValue * 100 / weight)
                    }
                    if let fatText = self.fatTextField.text?.replacingOccurrences(of: ",", with: "."), let fatValue = Double(fatText) {
                        self.fatTextField.text = fatValue == 0 ? "" : formatValue(fatValue * 100 / weight)
                    }
                    if let proteinText = self.proteinTextField.text?.replacingOccurrences(of: ",", with: "."), let proteinValue = Double(proteinText) {
                        self.proteinTextField.text = proteinValue == 0 ? "" : formatValue(proteinValue * 100 / weight)
                    }
                } else {
                    // Convert values back to per piece
                    if let carbsText = self.carbsTextField.text?.replacingOccurrences(of: ",", with: "."), let carbsValue = Double(carbsText) {
                        self.carbsTextField.text = carbsValue == 0 ? "" : formatValue(carbsValue / 100 * weight)
                    }
                    if let fatText = self.fatTextField.text?.replacingOccurrences(of: ",", with: "."), let fatValue = Double(fatText) {
                        self.fatTextField.text = fatValue == 0 ? "" : formatValue(fatValue / 100 * weight)
                    }
                    if let proteinText = self.proteinTextField.text?.replacingOccurrences(of: ",", with: "."), let proteinValue = Double(proteinText) {
                        self.proteinTextField.text = proteinValue == 0 ? "" : formatValue(proteinValue / 100 * weight)
                    }

                    // Add weightString to notesTextField
                    if self.notesTextField.text?.isEmpty ?? true {
                        let weightString = weight.truncatingRemainder(dividingBy: 1) == 0 ? String(format: NSLocalizedString("Vikt per styck: %d g", comment: "Weight info"), Int(weight)) : String(format: NSLocalizedString("Vikt per styck: %.1f g", comment: "Weight info"), weight)
                        self.notesTextField.text = weightString
                    } else {
                        let currentText = self.notesTextField.text ?? ""
                        let weightRegexPattern = "Vikt per styck: (\\d+\\.?\\d*) g"

                        if let _ = currentText.range(of: weightRegexPattern, options: .regularExpression) {
                            let weightString = weight.truncatingRemainder(dividingBy: 1) == 0 ? String(format: NSLocalizedString("Vikt per styck: %d g", comment: "Weight info"), Int(weight)) : String(format: NSLocalizedString("Vikt per styck: %.1f g", comment: "Weight info"), weight)
                            let updatedText = currentText.replacingOccurrences(of: weightRegexPattern, with: weightString, options: .regularExpression)
                            self.notesTextField.text = updatedText
                        } else {
                            let weightString = weight.truncatingRemainder(dividingBy: 1) == 0 ? String(format: NSLocalizedString("Vikt per styck: %d g", comment: "Weight info"), Int(weight)) : String(format: NSLocalizedString("Vikt per styck: %.1f g", comment: "Weight info"), weight)
                            self.notesTextField.text = currentText + " • " + weightString
                        }
                    }
                }

                // Update UI labels after calculation
                self.isPerPiece = sender.selectedSegmentIndex == 1
                self.updateUnitsLabels()
                self.checkForChanges()
                self.updateSegmentedControlLabels()

                // Store the current segment index as the new "previous" index
                self.previousSegmentIndex = currentIndex
            }
        }))

        // Show the alert
        present(alert, animated: true, completion: nil)
    }
    
    private func updateUnitsLabels() {
        if isPerPiece {
            carbsUnits.text = NSLocalizedString("g/st", comment: "Grams per piece unit")
            fatUnits.text = NSLocalizedString("g/st", comment: "Grams per piece unit")
            proteinUnits.text = NSLocalizedString("g/st", comment: "Grams per piece unit")
        } else {
            carbsUnits.text = NSLocalizedString("g/100g", comment: "Grams per 100 grams unit")
            fatUnits.text = NSLocalizedString("g/100g", comment: "Grams per 100 grams unit")
            proteinUnits.text = NSLocalizedString("g/100g", comment: "Grams per 100 grams unit")
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
        if foodItem != nil {
            // Edit mode
            if saveButton.isEnabled {
                updateButtonTitle(saveButton, withTitle: NSLocalizedString("Spara ändringar", comment: "Save changes button title"))
            } else {
                updateButtonTitle(saveButton, withTitle: NSLocalizedString("Inga ändringar", comment: "No changes button title"))
            }
        } else {
            // New mode
            updateButtonTitle(saveButton, withTitle: NSLocalizedString("Spara", comment: "Save button title"))
        }
    }

    private func setupUI() {
        if let foodItem = foodItem {
            title = NSLocalizedString("Ändra livsmedel", comment: "Edit food item screen title")
            nameTextField.text = foodItem.name
            notesTextField.text = foodItem.notes
            emojiTextField.text = foodItem.emoji
            
            // Handle per piece vs per 100g
            if foodItem.perPiece {
                isPerPiece = true
                segmentedControl.selectedSegmentIndex = 1
                //carbsTextField.text = formattedValue(foodItem.carbsPP)
                carbsTextField.text = foodItem.carbsPP == 0 ? "" : formattedValue(foodItem.carbsPP)
                //fatTextField.text = formattedValue(foodItem.fatPP)
                fatTextField.text = foodItem.fatPP == 0 ? "" : formattedValue(foodItem.fatPP)
                //proteinTextField.text = formattedValue(foodItem.proteinPP)
                proteinTextField.text = foodItem.proteinPP == 0 ? "" : formattedValue(foodItem.proteinPP)
            } else {
                isPerPiece = false
                segmentedControl.selectedSegmentIndex = 0
                //carbsTextField.text = formattedValue(foodItem.carbohydrates)
                carbsTextField.text = foodItem.carbohydrates == 0 ? "" : formattedValue(foodItem.carbohydrates)
                //fatTextField.text = formattedValue(foodItem.fat)
                fatTextField.text = foodItem.fat == 0 ? "" : formattedValue(foodItem.fat)
                //proteinTextField.text = formattedValue(foodItem.protein)
                proteinTextField.text = foodItem.protein == 0 ? "" : formattedValue(foodItem.protein)
            }
        } else if let data = prePopulatedData {
            title = NSLocalizedString("Lägg till livsmedel", comment: "Add food item screen title")
            // Handle prepopulated data case
            nameTextField.text = data.name
            emojiTextField.text = data.emoji
            notesTextField.text = data.notes
            
            if data.isPerPiece {
                isPerPiece = true
                segmentedControl.selectedSegmentIndex = 1
                //carbsTextField.text = formattedValue(data.carbsPP)
                carbsTextField.text = data.carbsPP == 0 ? "" : formattedValue(data.carbsPP)
                //fatTextField.text = formattedValue(data.fatPP)
                fatTextField.text = data.fatPP == 0 ? "" : formattedValue(data.fatPP)
                //proteinTextField.text = formattedValue(data.proteinPP)
                proteinTextField.text = data.proteinPP == 0 ? "" : formattedValue(data.proteinPP)
            } else {
                isPerPiece = false
                segmentedControl.selectedSegmentIndex = 0
                //carbsTextField.text = formattedValue(data.carbohydrates)
                carbsTextField.text = data.carbohydrates == 0 ? "" : formattedValue(data.carbohydrates)
                //fatTextField.text = formattedValue(data.fat)
                fatTextField.text = data.fat == 0 ? "" : formattedValue(data.fat)
                //proteinTextField.text = formattedValue(data.protein)
                proteinTextField.text = data.protein == 0 ? "" : formattedValue(data.protein)
            }
        }

        updateUnitsLabels()  // Ensure units are correctly set based on the segment
        updateSegmentedControlLabels() // Update segment labels based on the selected item
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

        // Check if we are updating an existing food item or creating a new one
        if let foodItem = foodItem {
            // Update existing food item
            updateFoodItem(foodItem)
            print("Updated existing food item: \(foodItem.name ?? "")")
        } else {
            // Create new food item
            let newFoodItem = FoodItem(context: context)
            newFoodItem.id = UUID()
            newFoodItem.delete = false // Set the delete flag to false by default
            updateFoodItem(newFoodItem)
            foodItem = newFoodItem
            print("Created new food item: \(newFoodItem.name ?? "ospecifierat")")
        }

        // Save the context and handle errors
        do {
            try context.save()
            print("Saved food item successfully.")
            
            // Notify delegate
            if let savedFoodItem = foodItem {
                delegate?.didSaveAndClose(foodItem: savedFoodItem) // Notify about save and close
            }

            // Notify other listeners via NotificationCenter
            NotificationCenter.default.post(name: .foodItemsDidChange, object: nil, userInfo: ["foodItems": fetchAllFoodItems()])

            if addToMeal {
                addToComposeMealViewController()

                // Show SuccessView when adding to meal
                let successView = SuccessView()
                if let window = self.view.window {
                    successView.showInView(window)
                }

                // Wait for the success view animation to finish before dismissing or popping
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if let navigationController = self.navigationController, navigationController.viewControllers.count > 1 {
                        navigationController.popViewController(animated: true)
                    } else {
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            } else {
                // Just dismiss or pop immediately
                if let navigationController = self.navigationController, navigationController.viewControllers.count > 1 {
                    navigationController.popViewController(animated: true)
                } else {
                    self.dismiss(animated: true, completion: nil)
                }
            }

            // Trigger CSV export if enabled
            guard let dataSharingVC = dataSharingVC else { return }
            if UserDefaultsRepository.allowCSVSync {
                Task {
                    print("Food items export triggered")
                    await dataSharingVC.exportFoodItemsToCSV()
                }
            } else {
                print("CSV export is disabled in settings.")
            }

        } catch {
            print("Failed to save food item: \(error)")
        }
    }

    // Helper function to append or remove " ①" based on isPerPiece
    private func adjustFoodItemName(_ name: String, isPerPiece: Bool) -> String {
        var adjustedName = name
        
        if isPerPiece {
            // Append " ①" if not already present
            if !adjustedName.hasSuffix(" ①") {
                adjustedName += " ①"
            }
        } else {
            // Remove " ①" if present
            if adjustedName.hasSuffix(" ①") {
                adjustedName = String(adjustedName.dropLast(2)) // Removes the last two characters (" ①")
            }
        }
        
        return adjustedName
    }

    // Helper function to update food item properties
    private func updateFoodItem(_ foodItem: FoodItem) {
        // Sanitize and replace prefixes in the name
        let sanitizedBaseName = (nameTextField.text ?? "")
            .replacingOccurrences(of: NSLocalizedString("S: ", comment: "Prefix for school meals"), with: "Ⓢ ")
            .replacingOccurrences(of: NSLocalizedString("Skolmat: ", comment: "Prefix for school meals"), with: "Ⓢ ")
            .replacingOccurrences(of: NSLocalizedString("Skola: ", comment: "Prefix for school"), with: "Ⓢ ")
            .replacingOccurrences(of: NSLocalizedString("Skola ", comment: "Prefix for school"), with: "Ⓢ ")
            .replacingOccurrences(of: NSLocalizedString("Skolmat ", comment: "Prefix for school meals"), with: "Ⓢ ")
            .replacingOccurrences(of: NSLocalizedString("skolmat: ", comment: "Lowercase prefix for school meals"), with: "Ⓢ ")
            .replacingOccurrences(of: NSLocalizedString("skola: ", comment: "Lowercase prefix for school"), with: "Ⓢ ")
            .replacingOccurrences(of: NSLocalizedString("skola ", comment: "Lowercase prefix for school"), with: "Ⓢ ")
            .replacingOccurrences(of: NSLocalizedString("skolmat ", comment: "Lowercase prefix for school meals"), with: "Ⓢ ")
        
        // Adjust the name based on isPerPiece
        let adjustedName = adjustFoodItemName(sanitizedBaseName, isPerPiece: isPerPiece)
        foodItem.name = adjustedName
        
        // Assign other properties
        foodItem.notes = notesTextField.text ?? ""
        foodItem.emoji = emojiTextField.text ?? ""
        
        // Update per-piece or overall values
        if isPerPiece {
            foodItem.carbsPP = sanitizedDouble(from: carbsTextField.text)
            foodItem.fatPP = sanitizedDouble(from: fatTextField.text)
            foodItem.proteinPP = sanitizedDouble(from: proteinTextField.text)
            foodItem.perPiece = true
            foodItem.carbohydrates = 0.0
            foodItem.fat = 0.0
            foodItem.protein = 0.0
        } else {
            foodItem.carbohydrates = sanitizedDouble(from: carbsTextField.text)
            foodItem.fat = sanitizedDouble(from: fatTextField.text)
            foodItem.protein = sanitizedDouble(from: proteinTextField.text)
            foodItem.perPiece = false
            foodItem.carbsPP = 0.0
            foodItem.fatPP = 0.0
            foodItem.proteinPP = 0.0
        }

        foodItem.lastEdited = Date()
        /*
        // Print all properties for debugging
        print("Saving FoodItem:")
        print("ID: \(foodItem.id?.uuidString ?? "nil")")
        print("Name: \(foodItem.name ?? "nil")")
        print("Carbohydrates: \(foodItem.carbohydrates)")
        print("CarbsPP: \(foodItem.carbsPP)")
        print("Fat: \(foodItem.fat)")
        print("FatPP: \(foodItem.fatPP)")
        print("Protein: \(foodItem.protein)")
        print("ProteinPP: \(foodItem.proteinPP)")
        print("PerPiece: \(foodItem.perPiece)")
        print("Count: \(foodItem.count)")
        print("Notes: \(foodItem.notes ?? "nil")")
        print("Emoji: \(foodItem.emoji ?? "nil")")
*/
        if let lastEdited = foodItem.lastEdited {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let formattedDate = isoFormatter.string(from: lastEdited)
            print("Last Edited (CSV Format): \(formattedDate)")
        } else {
            print("Last Edited: nil")
        }
    }

    // Helper method to sanitize and convert text to Double
    private func sanitizedDouble(from text: String?) -> Double {
        return Double(text?.replacingOccurrences(of: ",", with: ".") ?? "") ?? 0.0
    }
    private func addToComposeMealViewController() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("No window found")
            return
        }

        guard let rootViewController = window.rootViewController else {
            print("No root view controller found")
            return
        }

        var tabBarController: UITabBarController? = nil

        // Traverse the view controller hierarchy to find the tab bar controller
        func findTabBarController(from viewController: UIViewController) -> UITabBarController? {
            if let tabController = viewController as? UITabBarController {
                return tabController
            }
            if let navController = viewController as? UINavigationController, let visibleController = navController.visibleViewController {
                return findTabBarController(from: visibleController)
            }
            if let presentedController = viewController.presentedViewController {
                return findTabBarController(from: presentedController)
            }
            return nil
        }

        tabBarController = findTabBarController(from: rootViewController)

        guard let tabBarVC = tabBarController else {
            print("Tab bar controller not found")
            return
        }

        for viewController in tabBarVC.viewControllers ?? [] {
            if let navController = viewController as? UINavigationController {
                for vc in navController.viewControllers {
                    if let composeMealVC = vc as? ComposeMealViewController {
                        if let newFoodItem = foodItem {
                            print("Adding food item to ComposeMealViewController: \(newFoodItem.name ?? "")")
                            composeMealVC.addFoodItemRow(with: newFoodItem)
                            composeMealVC.updateTotalNutrients() // Ensure UI update
                            composeMealVC.updateClearAllButtonState() // Ensure button state update
                            composeMealVC.updateSaveFavoriteButtonState() // Ensure button state update
                            composeMealVC.updateHeadlineVisibility() // Ensure headline visibility
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

// MARK: Extension (AddFoodItemDelegate)
extension ComposeMealViewController: AddFoodItemDelegate {
    func didSaveAndClose(foodItem: FoodItem) {}
    
    func didAddFoodItem(foodItem: FoodItem) {
        fetchFoodItems()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
}

extension AddFoodItemViewController: EmojiViewDelegate {
    func emojiViewDidSelectEmoji(_ emoji: String, emojiView: EmojiView) {
        emojiTextField.insertText(emoji)
    }

    func emojiViewDidPressChangeKeyboardButton(_ emojiView: EmojiView) {
        emojiTextField.inputView = nil
        emojiTextField.keyboardType = .default
        emojiTextField.reloadInputViews()
    }

    func emojiViewDidPressDeleteBackwardButton(_ emojiView: EmojiView) {
        emojiTextField.deleteBackward()
    }

    func emojiViewDidPressDismissKeyboardButton(_ emojiView: EmojiView) {
        emojiTextField.resignFirstResponder()
    }
}

extension AddFoodItemDelegate {
    // Default implementation for types that don’t use foodItem
    func didAddFoodItem(foodItem: FoodItem) {
        didAddFoodItem() // Calls the original method if needed
    }

    // Preserve the original method for backward compatibility
    func didAddFoodItem() {}
}
