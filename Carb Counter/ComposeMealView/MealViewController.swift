//
//  MealViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-08-09.
//

import UIKit
import LocalAuthentication
import AudioToolbox

class MealViewController: UIViewController, UITextFieldDelegate, TwilioRequestable  {
    weak var delegate: MealViewControllerDelegate?
    
    @IBOutlet weak var carbsEntryField: UITextField!
    @IBOutlet weak var fatEntryField: UITextField!
    @IBOutlet weak var proteinEntryField: UITextField!
    @IBOutlet weak var notesEntryField: UITextField!
    @IBOutlet weak var bolusEntryField: UITextField!
    @IBOutlet weak var bolusRow: UIView!
    @IBOutlet weak var bolusCalcStack: UIStackView!
    @IBOutlet weak var bolusCalculated: UITextField!
    @IBOutlet weak var sendMealButton: UIButton!
    @IBOutlet weak var carbLabel: UILabel!
    @IBOutlet weak var carbGrams: UITextField!
    @IBOutlet weak var fatLabel: UILabel!
    @IBOutlet weak var fatGrams: UITextField!
    @IBOutlet weak var proteinLabel: UILabel!
    @IBOutlet weak var proteinGrams: UITextField!
    @IBOutlet weak var mealNotesLabel: UILabel!
    @IBOutlet weak var mealNotes: UITextField!
    @IBOutlet weak var mealDateTime: UIDatePicker!
    @IBOutlet weak var bolusLabel: UILabel!
    @IBOutlet weak var bolusUnits: UITextField!
    //@IBOutlet weak var CRValue: UITextField!
    //@IBOutlet weak var minPredBGValue: UITextField!
    //@IBOutlet weak var minBGStack: UIStackView!
    @IBOutlet weak var bolusStack: UIStackView!
    @IBOutlet weak var plusSign: UIImageView!
    //@IBOutlet weak var infoStack: UIStackView!
    
    var startDose: Bool = false
    
    var CR: Decimal = 0.0
    var minGuardBG: Decimal = 0.0
    var lowThreshold: Decimal = 0.0
    
    let maxCarbs = UserDefaultsRepository.maxCarbs as Double?
    let maxFatProtein = UserDefaultsRepository.maxCarbs as Double?
    let maxBolus = UserDefaultsRepository.maxBolus as Double?
    
    var isAlertShowing = false // Property to track if alerts are currently showing
    var isButtonDisabled = false // Property to track if the button is currently disabled
    var isBolusEntryFieldPopulated = false
    
    var popupView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        // Set the navigation bar title
            self.title = "Registrera Måltid"
            
            // Create the cancel button
            let cancelButton = UIBarButtonItem(title: "Avbryt", style: .plain, target: self, action: #selector(cancelButtonTapped))
            
            // Set the cancel button as the right bar button item
            self.navigationItem.rightBarButtonItem = cancelButton
        
        carbsEntryField.delegate = self
        fatEntryField.delegate = self
        proteinEntryField.delegate = self
        notesEntryField.delegate = self
        bolusEntryField.delegate = self

        setupInputAccessoryView()
        setupDatePickerLimits()
        self.focusCarbsEntryField()
        
        // Disable autocomplete and spell checking
        notesEntryField.autocorrectionType = .no
        notesEntryField.spellCheckingType = .no
        
        // Add tap gesture recognizers to labels
        addGestureRecognizers()
        
        // Add a tap gesture recognizer to bolusStack
            let bolusStackTap = UITapGestureRecognizer(target: self, action: #selector(bolusStackTapped))
            bolusStack.addGestureRecognizer(bolusStackTap)
            bolusStack.isUserInteractionEnabled = true
        
        /*
        // Add tap gesture recognizer to minBGStack
                let minBGStackTap = UITapGestureRecognizer(target: self, action: #selector(minBGStackTapped))
                minBGStack.addGestureRecognizer(minBGStackTap)
        
        // Add tap gesture recognizer to infoStack
                let infoStackTap = UITapGestureRecognizer(target: self, action: #selector(minBGStackTapped))
                infoStack.addGestureRecognizer(infoStackTap)
        */
    //Bolus calculation preperations
        
        //Carb ratio
        /*if let sharedCRDouble = Double(sharedCRValue) {
            CR = Decimal(sharedCRDouble)
        } else {
            print("CR could not be fetched")
        }*/
        
        // Create a NumberFormatter instance
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 1

    }
    
    
    func setupDatePickerLimits() {
            let now = Date()
            let oneDayInterval: TimeInterval = 23 * 60 * 60 + 59 * 60
            
            mealDateTime.minimumDate = now.addingTimeInterval(-oneDayInterval)
            mealDateTime.maximumDate = now.addingTimeInterval(oneDayInterval)
        }
    
    func setupInputAccessoryView() {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            
            let nextButton = UIBarButtonItem(title: "Nästa", style: .plain, target: self, action: #selector(nextTapped))
            let doneButton = UIBarButtonItem(title: "Klar", style: .plain, target: self, action: #selector(doneTapped))
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            
            //toolbar.setItems([flexSpace, nextButton, doneButton], animated: false)
            toolbar.setItems([nextButton, flexSpace, doneButton], animated: false)
            
            carbsEntryField.inputAccessoryView = toolbar
            fatEntryField.inputAccessoryView = toolbar
            proteinEntryField.inputAccessoryView = toolbar
            notesEntryField.inputAccessoryView = toolbar
            bolusEntryField.inputAccessoryView = toolbar
        }
        
        @objc func nextTapped() {
            if carbsEntryField.isFirstResponder {
                fatEntryField.becomeFirstResponder()
            } else if fatEntryField.isFirstResponder {
                proteinEntryField.becomeFirstResponder()
            } else if proteinEntryField.isFirstResponder {
                notesEntryField.becomeFirstResponder()
            } else if notesEntryField.isFirstResponder {
                bolusEntryField.becomeFirstResponder()
            } else if bolusEntryField.isFirstResponder {
                carbsEntryField.becomeFirstResponder()
            }
        }
        
        @objc func doneTapped() {
            view.endEditing(true)
        }
    
    @objc func cancelButtonTapped() {
        // Dismiss the view controller when the cancel button is tapped
        self.dismiss(animated: true, completion: nil)
    }

    
    // Add tap gesture recognizers to labels
        func addGestureRecognizers() {
            let carbLabelTap = UITapGestureRecognizer(target: self, action: #selector(focusCarbsEntryField))
            carbLabel.addGestureRecognizer(carbLabelTap)
            carbLabel.isUserInteractionEnabled = true
            
            let fatLabelTap = UITapGestureRecognizer(target: self, action: #selector(focusFatEntryField))
            fatLabel.addGestureRecognizer(fatLabelTap)
            fatLabel.isUserInteractionEnabled = true
            
            let proteinLabelTap = UITapGestureRecognizer(target: self, action: #selector(focusProteinEntryField))
            proteinLabel.addGestureRecognizer(proteinLabelTap)
            proteinLabel.isUserInteractionEnabled = true
            
            let mealNotesLabelTap = UITapGestureRecognizer(target: self, action: #selector(focusNotesEntryField))
            mealNotesLabel.addGestureRecognizer(mealNotesLabelTap)
            mealNotesLabel.isUserInteractionEnabled = true
            
            let bolusLabelTap = UITapGestureRecognizer(target: self, action: #selector(focusBolusEntryField))
            bolusLabel.addGestureRecognizer(bolusLabelTap)
            bolusLabel.isUserInteractionEnabled = true
        }
        
        @objc func focusCarbsEntryField() {
            self.carbsEntryField.becomeFirstResponder()
        }
        
        @objc func focusFatEntryField() {
            self.fatEntryField.becomeFirstResponder()
        }
        
        @objc func focusProteinEntryField() {
            self.proteinEntryField.becomeFirstResponder()
        }
        
        @objc func focusNotesEntryField() {
            self.notesEntryField.becomeFirstResponder()
        }
        
        @objc func focusBolusEntryField() {
            self.bolusEntryField.becomeFirstResponder()
        }
    
    // Function to calculate the suggested bolus value based on CR and check for maxCarbs
    func calculateBolus() {
        guard let carbsText = carbsEntryField.text,
              let carbsValue = Decimal(string: carbsText) else {
            // If no valid input, clear bolusCalculated
            bolusCalculated.text = ""
            return
        }

        
        var bolusValue = carbsValue / CR
        // Round down to the nearest 0.05
        bolusValue = roundDown(toNearest: Decimal(0.05), value: bolusValue)
        
        // Format the bolus value based on the locale's decimal separator
        let formattedBolus = formatDecimal(bolusValue)
        
        bolusCalculated.text = "\(formattedBolus)"
    }
    
    // UITextFieldDelegate method to handle text changes in carbsEntryField
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Ensure that the textField being changed is the carbsEntryField
        
        // Calculate the new text after the replacement
        let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string
        if !newText.isEmpty {
            // Update the text in the carbsEntryField
            textField.text = newText
            
            // Calculate bolus whenever the carbs text field changes
            calculateBolus()
        } else {
            // If the new text is empty, clear bolusCalculated and update button state
            bolusCalculated.text = ""
            updateButtonState()
            return true
        }
        
        // Check if the new text is a valid number
        guard let newValue = Decimal(string: newText), newValue >= 0 else {
            // Update button state
            updateButtonState()
            return false
        }
        
        sendMealorMealandBolus()
            
        // Update button state
        updateButtonState()
        
        return false // Return false to prevent the text field from updating its text again
    }
    
    
    // Function to round a Decimal number down to the nearest specified increment
    func roundDown(toNearest increment: Decimal, value: Decimal) -> Decimal {
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        let roundedDouble = (doubleValue * 20).rounded(.down) / 20
        
        return Decimal(roundedDouble)
    }
    
    // Function to format a Decimal number based on the locale's decimal separator
    func formatDecimal(_ value: Decimal) -> String {
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.decimalSeparator = Locale.current.decimalSeparator
        
        guard let formattedString = numberFormatter.string(from: NSNumber(value: doubleValue)) else {
            fatalError("Failed to format the number.")
        }
        
        return formattedString
    }
    
    //func focusCarbsEntryField() {
    //    self.carbsEntryField.becomeFirstResponder()
    //}
    
    public func populateMealViewController(khValue: String, fatValue: String, proteinValue: String, bolusValue: String, emojis: String, bolusSoFar: String, bolusTotal: String, carbsSoFar: String, carbsTotal: String, fatSoFar: String, fatTotal: String, proteinSoFar: String, proteinTotal: String,  method: String, startDose: Bool) {
        // Log the values to the console (optional)
        print("KH Value: \(khValue)")
        print("Fat Value: \(fatValue)")
        print("Protein Value: \(proteinValue)")
        print("Bolus Value: \(bolusValue)")
        print("Emojis: \(emojis)")
        print("Method: \(method)")
        print("Startdose: \(startDose)")
        print("bolusSoFar: \(bolusSoFar)")
        print("bolusTotal: \(bolusTotal)")
        print("carbsSoFar: \(carbsSoFar)")
        print("carbsTotal: \(carbsTotal)")
        print("fatSoFar: \(fatSoFar)")
        print("fatTotal: \(fatTotal)")
        print("proteinSoFar: \(proteinSoFar)")
        print("proteinTotal: \(proteinTotal)")

        // Populate the UI elements with the passed values
        self.carbsEntryField.text = khValue
        self.fatEntryField.text = fatValue
        self.proteinEntryField.text = proteinValue
        self.bolusCalculated.text = bolusValue

        // Optionally populate the notes entry field with the emojis or any default text
        self.notesEntryField.text = emojis
        
        // Set the startDose property
        self.startDose = startDose
        
        // Simulate a tap on the bolusStack to transfer bolusCalculated.text to bolusEntryField.text
        //bolusStackTapped()
    }
    
    func sendMealorMealandBolus() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "HelveticaNeue-Medium", size: 20.0)!,
        ]
        
        let carbsValue = Decimal(string: carbsEntryField.text ?? "0") ?? 0
        let fatValue = Decimal(string: fatEntryField.text ?? "0") ?? 0
        let proteinValue = Decimal(string: proteinEntryField.text ?? "0") ?? 0
      
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 0
        
        // Check if the carbs value exceeds maxCarbs
        if carbsValue > Decimal(maxCarbs ?? 100) {
            // Disable button
            isButtonDisabled = true
            sendMealButton.isEnabled = false
          
            // Format maxCarbs with zero decimals
            let formattedMaxCarbs = numberFormatter.string(from: NSNumber(value: maxCarbs ?? 100)) ?? ""
          
            // Update button title
            sendMealButton.setAttributedTitle(NSAttributedString(string: "⛔️ Maxgräns kolhydrater \(formattedMaxCarbs) g", attributes: attributes), for: .normal)
        } else if fatValue > Decimal(maxFatProtein ?? 100) || proteinValue > Decimal(maxFatProtein ?? 100) {
            // Disable button
            isButtonDisabled = true
            sendMealButton.isEnabled = false
          
            // Format maxFatProtein with zero decimals
            let formattedMaxFatProtein = numberFormatter.string(from: NSNumber(value: maxFatProtein ?? 100)) ?? ""
          
            // Update button title
            sendMealButton.setAttributedTitle(NSAttributedString(string: "⛔️ Maxgräns fett/protein \(formattedMaxFatProtein) g", attributes: attributes), for: .normal)
        }
 else if let bolusText = bolusUnits.text?.replacingOccurrences(of: ",", with: "."),

           let bolusValue = Decimal(string: bolusText),
         bolusValue > Decimal(maxBolus ?? 100) + 0.01 { //add 0.01 to allow entry of = maxBolus due to rounding issues with double and decimals otherwise disable it when bolusValue=maxBolus
            
            // Disable button
            isButtonDisabled = true
            sendMealButton.isEnabled = false
            
            // Format maxBolus with two decimal places
            let formattedMaxBolus = String(format: "%.2f", UserDefaultsRepository.maxBolus)
            
            // Update button title if bolus exceeds maxBolus
            sendMealButton.setAttributedTitle(NSAttributedString(string: "⛔️ Maxgräns bolus \(formattedMaxBolus) E", attributes: attributes), for: .normal)
        } else {
            // Enable button
            sendMealButton.isEnabled = true
            isButtonDisabled = false
           // Check if bolusText is not "0" and not empty
            if let bolusText = bolusUnits.text, bolusText != "0" && !bolusText.isEmpty {
                // Update button title with bolus
                sendMealButton.setAttributedTitle(NSAttributedString(string: "Skicka Måltid och Bolus", attributes: attributes), for: .normal)
            } else {
                // Update button title without bolus
                sendMealButton.setAttributedTitle(NSAttributedString(string: "Skicka Måltid", attributes: attributes), for: .normal)
            }
        }
    }
    
    // Action method to handle tap on bolusStack
    @objc func bolusStackTapped() {
            if isBolusEntryFieldPopulated {
                // If bolusEntryField is already populated, make it empty
                bolusEntryField.text = ""
                isBolusEntryFieldPopulated = false
            } else {
                // If bolusEntryField is empty, populate it with the value from bolusCalculated
                bolusEntryField.text = bolusCalculated.text
                isBolusEntryFieldPopulated = true
            }
            sendMealorMealandBolus() // Update the state after the tap action
        }
    
    @IBAction func sendRemoteMealPressed(_ sender: Any) {
        // Disable the button to prevent multiple taps
        if !isButtonDisabled {
            isButtonDisabled = true
            sendMealButton.isEnabled = false
        } else {
            return // If button is already disabled, return to prevent double registration
        }
        
        // Retrieve the maximum carbs value from UserDefaultsRepository
        //let maxCarbs = UserDefaultsRepository.maxCarbs.value
        //let maxBolus = UserDefaultsRepository.maxBolus.value
        
        // BOLUS ENTRIES
        //Process bolus entries
        guard var bolusText = bolusUnits.text else {
            print("Note: Bolus amount not entered")
            return
        }
        
        // Replace all occurrences of ',' with '.
        
        bolusText = bolusText.replacingOccurrences(of: ",", with: ".")
        
        let bolusValue: Double
        if bolusText.isEmpty {
            bolusValue = 0
        } else {
            guard let bolusDouble = Double(bolusText) else {
                print("Error: Bolus amount conversion failed")
                // Play failure sound
                AudioServicesPlaySystemSound(SystemSoundID(1053))
                // Display an alert
                let alertController = UIAlertController(title: "Fel", message: "Bolus är inmatad i fel format", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ändra", style: .default, handler: nil))
                present(alertController, animated: true, completion: nil)
                self.handleAlertDismissal() // Enable send button after handling failure to be able to try again
                return
            }
            bolusValue = bolusDouble
        }
        //Let code remain for now - to be cleaned
        if bolusValue > ((maxBolus ?? 2) + 0.05) {
            // Play failure sound
            AudioServicesPlaySystemSound(SystemSoundID(1053))
            // Format maxBolus to display only one decimal place
            let formattedMaxBolus = String(format: "%.1f", maxBolus ?? 2)
            
            let alertControllerBolus = UIAlertController(title: "Max setting exceeded", message: "The maximum allowed bolus of \(formattedMaxBolus) U is exceeded! Please try again with a smaller amount.", preferredStyle: .alert)
            alertControllerBolus.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alertControllerBolus, animated: true, completion: nil)
            self.handleAlertDismissal() // Enable send button after handling failure to be able to try again
            return
        }
        
        // CARBS & FPU ENTRIES
        
        guard var carbText = carbGrams.text else {
            print("Note: Carb amount not entered")
            return
        }
        
        carbText = carbText.replacingOccurrences(of: ",", with: ".")
        
        let carbsValue: Double
        if carbText.isEmpty {
            carbsValue = 0
        } else {
            guard let carbsDouble = Double(carbText) else {
                print("Error: Carb input value conversion failed")
                // Play failure sound
                AudioServicesPlaySystemSound(SystemSoundID(1053))
                // Display an alert
                let alertController = UIAlertController(title: "Fel", message: "Kolhydrater är inmatade i fel format", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ändra", style: .default, handler: nil))
                present(alertController, animated: true, completion: nil)
                self.handleAlertDismissal() // Enable send button after handling failure to be able to try again
                return
            }
            carbsValue = carbsDouble
        }
        
        guard var fatText = fatGrams.text else {
            print("Note: Fat amount not entered")
            return
        }
        
        fatText = fatText.replacingOccurrences(of: ",", with: ".")
        
        let fatsValue: Double
        if fatText.isEmpty {
            fatsValue = 0
        } else {
            guard let fatsDouble = Double(fatText) else {
                print("Error: Fat input value conversion failed")
                // Play failure sound
                AudioServicesPlaySystemSound(SystemSoundID(1053))
                // Display an alert
                let alertController = UIAlertController(title: "Fel", message: "Fett är inmatat i fel format", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ändra", style: .default, handler: nil))
                present(alertController, animated: true, completion: nil)
                self.handleAlertDismissal() // Enable send button after handling failure to be able to try again
                return
            }
            fatsValue = fatsDouble
        }
        
        guard var proteinText = proteinGrams.text else {
            print("Note: Protein amount not entered")
            return
        }
        
        proteinText = proteinText.replacingOccurrences(of: ",", with: ".")
        
        let proteinsValue: Double
        if proteinText.isEmpty {
            proteinsValue = 0
        } else {
            guard let proteinsDouble = Double(proteinText) else {
                print("Error: Protein input value conversion failed")
                // Play failure sound
                AudioServicesPlaySystemSound(SystemSoundID(1053))
                // Display an alert
                let alertController = UIAlertController(title: "Fel", message: "Protein är inmatat i fel format", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ändra", style: .default, handler: nil))
                present(alertController, animated: true, completion: nil)
                self.handleAlertDismissal() // Enable send button after handling failure to be able to try again
                return
            }
            proteinsValue = proteinsDouble
        }
        
        if carbsValue > maxCarbs ?? 100 || fatsValue > maxCarbs ?? 100 || proteinsValue > maxCarbs ?? 100 {
            // Play failure sound
            AudioServicesPlaySystemSound(SystemSoundID(1053))
            let alertController = UIAlertController(title: "Max setting exceeded", message: "The maximum allowed amount of \(maxCarbs)g is exceeded for one or more of the entries! Please try again with a smaller amount.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alertController, animated: true, completion: nil)
            self.handleAlertDismissal() // Enable send button after handling failure to be able to try again
            return // Exit the function if any value exceeds maxCarbs
        }
        
        // Call createCombinedString to get the combined string
        //let combinedString = createCombinedString(carbs: carbs, fats: fats, proteins: proteins)
        let combinedString = createCombinedString(carbs: carbsValue, fats: fatsValue, proteins: proteinsValue)
        
        // Show confirmation alert
        if bolusValue != 0 {
            showMealBolusConfirmationAlert(combinedString: combinedString)
        } else {
            showMealConfirmationAlert(combinedString: combinedString)
        }

        // Function to format date to ISO 8601 without seconds and milliseconds
            func formatDateToISO8601(_ date: Date) -> String {
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
                return dateFormatter.string(from: date)
            }

            // Function to create combined string with selected date
            func createCombinedString(carbs: Double, fats: Double, proteins: Double) -> String {
                let mealNotesValue = mealNotes.text ?? ""
                let cleanedMealNotes = mealNotesValue
                let name = UserDefaultsRepository.caregiverName
                let secret = UserDefaultsRepository.remoteSecretCode
                // Convert bolusValue to string and trim any leading or trailing whitespace
                let trimmedBolusValue = "\(bolusValue)".trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Get selected date from mealDateTime and format to ISO 8601
                let selectedDate = mealDateTime.date
                let formattedDate = formatDateToISO8601(selectedDate)

                    // Construct and return the combinedString with bolus
                    return "Remote Måltid\nKolhydrater: \(carbs)g\nFett: \(fats)g\nProtein: \(proteins)g\nNotering: \(cleanedMealNotes)\nDatum: \(formattedDate)\nInsulin: \(trimmedBolusValue)E\nInlagt av: \(name)\nHemlig kod: \(secret)"

            }
        
        //Alert for meal without bolus
        func showMealConfirmationAlert(combinedString: String) {
            // Set isAlertShowing to true before showing the alert
            isAlertShowing = true
            // Confirmation alert before sending the request
            let confirmationAlert = UIAlertController(title: "Bekräfta måltid", message: "Vill du registrera denna måltid?", preferredStyle: .alert)
            
            confirmationAlert.addAction(UIAlertAction(title: "Ja", style: .default, handler: { (action: UIAlertAction!) in
                // Proceed with sending the request
                self.sendMealRequest(combinedString: combinedString)
            }))
            
            confirmationAlert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { (action: UIAlertAction!) in
                // Handle dismissal when "Cancel" is selected
                self.handleAlertDismissal()
            }))
            
            present(confirmationAlert, animated: true, completion: nil)
        }
        
        //Alert for meal WITH bolus
        func showMealBolusConfirmationAlert(combinedString: String) {
            // Set isAlertShowing to true before showing the alert
            isAlertShowing = true
            // Confirmation alert before sending the request
            let confirmationAlert = UIAlertController(title: "Bekräfta måltid och bolus", message: "Vill du registrera denna måltid och ge \(bolusValue) E bolus?", preferredStyle: .alert)
            
            confirmationAlert.addAction(UIAlertAction(title: "Ja", style: .default, handler: { (action: UIAlertAction!) in
                // Authenticate with Face ID
                self.authenticateWithBiometrics {
                    // Proceed with the request after successful authentication
                    self.sendMealRequest(combinedString: combinedString)
                }
            }))
            
            confirmationAlert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { (action: UIAlertAction!) in
                // Handle dismissal when "Cancel" is selected
                self.handleAlertDismissal()
            }))
            
            present(confirmationAlert, animated: true, completion: nil)
        }
    }
    
    func authenticateWithBiometrics(completion: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate with biometrics to proceed"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        // Authentication successful
                        completion()
                    } else {
                        // Check for passcode authentication
                        if let error = authenticationError as NSError?,
                           error.code == LAError.biometryNotAvailable.rawValue || error.code == LAError.biometryNotEnrolled.rawValue {
                            // Biometry (Face ID or Touch ID) is not available or not enrolled, use passcode
                            self.authenticateWithPasscode(completion: completion)
                        } else {
                            // Authentication failed
                            if let error = authenticationError {
                                print("Authentication failed: \(error.localizedDescription)")
                            }
                            // Handle dismissal when authentication fails
                            self.handleAlertDismissal()
                        }
                    }
                }
            }
        } else {
            // Biometry (Face ID or Touch ID) is not available, use passcode
            self.authenticateWithPasscode(completion: completion)
        }
    }
    
    func authenticateWithPasscode(completion: @escaping () -> Void) {
        let context = LAContext()
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authenticate with passcode to proceed") { success, error in
            DispatchQueue.main.async {
                if success {
                    // Authentication successful
                    completion()
                } else {
                    // Authentication failed
                    if let error = error {
                        print("Authentication failed: \(error.localizedDescription)")
                    }
                    // Handle dismissal when authentication fails
                    self.handleAlertDismissal()
                }
            }
        }
    }
    
    // Function to handle alert dismissal
    func handleAlertDismissal() {
        // Enable the button when alerts are dismissed
        isAlertShowing = false
        sendMealButton.isEnabled = true
        isButtonDisabled = false // Reset button disable status
    }
    
    func sendMealRequest(combinedString: String) {
        print("Sendmealrequest function ran")
        let method = UserDefaultsRepository.method

        // Extract values from the combinedString
        let carbs = extractValue(from: combinedString, prefix: "Kolhydrater: ", suffix: "g")
        let fats = extractValue(from: combinedString, prefix: "Fett: ", suffix: "g")
        let proteins = extractValue(from: combinedString, prefix: "Protein: ", suffix: "g")
        let bolus = extractValue(from: combinedString, prefix: "Insulin: ", suffix: "E")

        if method == "iOS Shortcuts" {
            // Call the delegate method immediately for iOS Shortcuts
            delegate?.didUpdateMealValues(khValue: carbs, fatValue: fats, proteinValue: proteins, bolusValue: bolus, startDose: self.startDose)
            handleShortcutsRequest(combinedString: combinedString, carbs: carbs, fats: fats, proteins: proteins, bolus: bolus, startDose: self.startDose)
        } else {
            handleTwilioRequest(combinedString: combinedString, carbs: carbs, fats: fats, proteins: proteins, bolus: bolus, startDose: self.startDose)
        }
    }

    // Handle the iOS Shortcuts case
    private func handleShortcutsRequest(combinedString: String, carbs: String, fats: String, proteins: String, bolus: String, startDose: Bool) {
        guard let encodedString = combinedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("Failed to encode URL string")
            return
        }
        let urlString = "shortcuts://run-shortcut?name=Slutdos&input=text&text=\(encodedString)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        print("Dismissing MealViewController")
        self.dismiss(animated: true, completion: nil)
    }

    // Handle the Twilio SMS request case
    private func handleTwilioRequest(combinedString: String, carbs: String, fats: String, proteins: String, bolus: String, startDose: Bool) {
        twilioRequest(combinedString: combinedString) { result in
            switch result {
            case .success:
                AudioServicesPlaySystemSound(SystemSoundID(1322))
                let alertController = UIAlertController(title: "Lyckades!", message: "Meddelandet levererades", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    // Call updateRegisteredAmount after successful SMS API call
                    if let composeMealVC = self.findComposeMealViewController() {
                                        composeMealVC.updateRegisteredAmount(khValue: carbs, fatValue: fats, proteinValue: proteins, bolusValue: bolus, startDose: startDose)
                                    } else {
                                        print("ComposeMealViewController not found")
                                    }
                                    print("Dismissing MealViewController after successful SMS API call")
                                    self.dismiss(animated: true, completion: nil)
                                }))
                self.present(alertController, animated: true, completion: nil)
            case .failure(let error):
                AudioServicesPlaySystemSound(SystemSoundID(1053))
                let alertController = UIAlertController(title: "Fel", message: error.localizedDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }

    
    // Function to find ComposeMealViewController in the navigation stack
    private func findComposeMealViewController() -> ComposeMealViewController? {
        if let navController = self.presentingViewController as? UINavigationController {
            for vc in navController.viewControllers {
                if let composeMealVC = vc as? ComposeMealViewController {
                    return composeMealVC
                }
            }
        }
        return nil
    }

    // Helper function to extract values from combinedString
    func extractValue(from text: String, prefix: String, suffix: String) -> String {
        if let startRange = text.range(of: prefix)?.upperBound,
           let endRange = text.range(of: suffix, range: startRange..<text.endIndex)?.lowerBound {
            return String(text[startRange..<endRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    
    @IBAction func editingChanged(_ sender: Any) {
        print("Value changed in bolus amount")
                
        sendMealorMealandBolus()
        
    }
    
    // Function to update button state
    func updateButtonState() {
        // Disable or enable button based on isButtonDisabled
        sendMealButton.isEnabled = !isButtonDisabled
    }

    // Function to hide both the bolusRow and bolusCalcStack
    func hideBolusRow() {
        bolusRow.isHidden = true
        bolusCalcStack.isHidden = true
    }
    
    // Function to show the bolusRow
    func showBolusRow() {
        bolusRow.isHidden = false
    }
    
    // Function to hide the bolusCalcStack
    func hideBolusCalcRow() {
        bolusCalcStack.isHidden = true
    }
    
    // Function to show the bolusCalcStack
    func showBolusCalcRow() {
        bolusCalcStack.isHidden = false
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

protocol MealViewControllerDelegate: AnyObject {
    func didUpdateMealValues(khValue: String, fatValue: String, proteinValue: String, bolusValue: String, startDose: Bool)
}
