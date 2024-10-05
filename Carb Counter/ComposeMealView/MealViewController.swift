// Daniel: 1200+ lines - To be cleaned
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
    @IBOutlet weak var bolusCalcText: UITextField!
    @IBOutlet weak var bolusCalculated: UITextField!
    @IBOutlet weak var bolusCalcUnitText: UITextField!
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
    @IBOutlet weak var bolusStack: UIStackView!
    @IBOutlet weak var method: UITextField!
    @IBOutlet weak var plusSign: UIImageView!
    
    var startDose: Bool = false
    
    var CR: Decimal = 0.0
    
    var bolusSoFar = ""
    var bolusTotal = ""
    var carbsSoFar = ""
    var carbsTotal = ""
    var fatSoFar = ""
    var fatTotal = ""
    var proteinSoFar = ""
    var proteinTotal = ""
    
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

            self.title = NSLocalizedString("Registrera Måltid", comment: "Registrera Måltid")
        
        setupCloseButton()
        setupInfoButton()
        
        updateSendMealButtonText(NSLocalizedString("Skicka Måltid", comment: "Skicka Måltid"))
        
        carbsEntryField.delegate = self
        fatEntryField.delegate = self
        proteinEntryField.delegate = self
        notesEntryField.delegate = self
        bolusEntryField.delegate = self

        setupInputAccessoryView()
        setupDatePickerLimits()
        self.focusCarbsEntryField()
        
        // Observe minBGWarning changes
            NightscoutManager.shared.minBGWarningDidChange = { [weak self] newMinBGWarning in
                DispatchQueue.main.async {
                    self?.updateNavigationBarButton()
                }
            }
        // Observe evBGWarning changes
            NightscoutManager.shared.evBGWarningDidChange = { [weak self] newEvBGWarning in
                DispatchQueue.main.async {
                    self?.updateNavigationBarButton()
                }
            }
        
        // Register observers for shortcut callback notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleShortcutSuccess), name: NSNotification.Name("ShortcutSuccess"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleShortcutError), name: NSNotification.Name("ShortcutError"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleShortcutCancel), name: NSNotification.Name("ShortcutCancel"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleShortcutPasscode), name: NSNotification.Name("ShortcutPasscode"), object: nil)

        
        // Disable autocomplete and spell checking
        carbsEntryField.autocorrectionType = .no
        carbsEntryField.spellCheckingType = .no
        fatEntryField.autocorrectionType = .no
        fatEntryField.spellCheckingType = .no
        proteinEntryField.autocorrectionType = .no
        proteinEntryField.spellCheckingType = .no
        notesEntryField.autocorrectionType = .no
        notesEntryField.spellCheckingType = .no
        bolusEntryField.autocorrectionType = .no
        bolusEntryField.spellCheckingType = .no
        
        // Add tap gesture recognizers to labels
        addGestureRecognizers()
        
        // Add a tap gesture recognizer to bolusStack
            let bolusStackTap = UITapGestureRecognizer(target: self, action: #selector(bolusStackTapped))
            bolusStack.addGestureRecognizer(bolusStackTap)
            bolusStack.isUserInteractionEnabled = true
        
        // Create a NumberFormatter instance
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 1

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Check and update the warning status
        NightscoutManager.shared.checkMinBGWarning()
        NightscoutManager.shared.checkEvBGWarning()
            
            // Update the navigation bar button based on bgWarning
            updateNavigationBarButton()
        
        // Update the method UITextField based on the stored value in UserDefaults
        if UserDefaultsRepository.method == "iOS Shortcuts" {
            method.text = NSLocalizedString("ⓘ  iOS Genväg", comment: "ⓘ  iOS Genväg")
        } else {
            method.text = NSLocalizedString("ⓘ  Twilio SMS", comment: "ⓘ  Twilio SMS")
        }

        updateSendMealButtonText(sendMealButton.currentTitle ?? NSLocalizedString("Skicka Måltid", comment: "Skicka Måltid"))
    }
    
    private func setupCloseButton() {
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    private func setupInfoButton() {
        let infoButton = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(infoButtonTapped)
        )
        navigationItem.rightBarButtonItem = infoButton
    }
    
    private func updateNavigationBarButton() {
        let buttonImage: UIImage?
        let buttonTintColor: UIColor
        let plusSignColor: UIColor
        
        if NightscoutManager.shared.evBGWarning {
            buttonImage = UIImage(systemName: "exclamationmark.triangle.fill")
            buttonTintColor = UIColor.red
            plusSignColor = UIColor.red
        } else if NightscoutManager.shared.minBGWarning {
            buttonImage = UIImage(systemName: "exclamationmark.triangle.fill")
            buttonTintColor = UIColor.orange
            plusSignColor = UIColor.orange
        } else {
            buttonImage = UIImage(systemName: "info.circle.fill")
            buttonTintColor = UIColor.label
            plusSignColor = UIColor.label
        }
        
        let infoButton = UIBarButtonItem(
            image: buttonImage,
            style: .plain,
            target: self,
            action: #selector(infoButtonTapped)
        )
        
        infoButton.tintColor = buttonTintColor
        navigationItem.rightBarButtonItem = infoButton
        plusSign.tintColor = plusSignColor
        bolusCalcText.textColor = plusSignColor
        bolusCalculated.textColor = plusSignColor
        bolusCalcUnitText.textColor = plusSignColor

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
            
            let nextButton = UIBarButtonItem(title: NSLocalizedString("Nästa", comment: "Nästa"), style: .plain, target: self, action: #selector(nextTapped))
            let doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Klar"), style: .plain, target: self, action: #selector(doneTapped))
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
    
    // Function that gets called when the info button is tapped
    @objc func infoButtonTapped() {
        togglePopupView()
    }
    
    func togglePopupView() {
        // Calculate time ago in minutes
        let timeAgo = calculateTimeAgo()
        
        if timeAgo > 5 {
            // Re-fetch the device status if timeAgo is greater than 5 minutes
            NightscoutManager.shared.fetchDeviceStatus {
                DispatchQueue.main.async {
                    // Once the fetch is complete, toggle the popup view
                    if self.popupView == nil {
                        self.showPopupView()
                    } else {
                        self.dismissPopupView()
                    }
                }
            }
        } else {
            // If no need to fetch, just toggle the popup view
            if popupView == nil {
                showPopupView()
            } else {
                dismissPopupView()
            }
        }
    }
    
    private func calculateTimeAgo() -> Int {
        let utcFormatter = ISO8601DateFormatter()
        utcFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Convert the latestTimestamp string back to a Date object
        if let latestDate = utcFormatter.date(from: NightscoutManager.shared.latestTimestamp) {
            // Get the current date and time
            let now = Date()
            
            // Calculate the difference in seconds between now and latestDate
            let timeInterval = now.timeIntervalSince(latestDate)
            
            // Convert the time interval to minutes
            let minutesAgo = Int(timeInterval / 60)
            return minutesAgo
        }
        
        return 0 // Return 0 if the conversion fails
    }
    
    func showPopupView() {
        if popupView == nil {
            // Create a new UIView for the popup
            let popupView = UIView()

            popupView.backgroundColor = UIColor.white
            popupView.layer.cornerRadius = 10
            popupView.translatesAutoresizingMaskIntoConstraints = false
            
            // Add the popup view to the main view
            view.addSubview(popupView)
            
            // Set up initial constraints for the popup view
            let initialTopConstraint = popupView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -270)
            NSLayoutConstraint.activate([
                popupView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
                popupView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
                initialTopConstraint,
                popupView.heightAnchor.constraint(equalToConstant: 270)
            ])
            
            // Add content to the popup view
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.alignment = .fill
            stackView.distribution = .equalSpacing
            stackView.spacing = 2
            stackView.translatesAutoresizingMaskIntoConstraints = false
            popupView.addSubview(stackView)
            
            // Add stack view constraints
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: popupView.leadingAnchor, constant: 20),
                stackView.trailingAnchor.constraint(equalTo: popupView.trailingAnchor, constant: -20),
                stackView.topAnchor.constraint(equalTo: popupView.topAnchor, constant: 20),
                stackView.bottomAnchor.constraint(equalTo: popupView.bottomAnchor, constant: -20)
            ])
            
            // Calculate time ago in minutes
            let timeAgo = calculateTimeAgo()
            let timeAgoString = timeAgo == 0 ? "< 1" : "\(timeAgo)"
            
            let bgunits: String
            if UserDefaultsRepository.useMmol {
                bgunits = ""//mmol/L"
            } else {
                bgunits = ""//mg/dl"
            }
            
            let plusSign: String
            if NightscoutManager.shared.latestDelta >= 0 {
                plusSign = "+"
            } else {
                plusSign = ""
            }
            
            // Add metrics to the popup
            let metrics = [
                NSLocalizedString("Blodsocker", comment: "Blodsocker"),
                "IOB",
                "COB",
                NSLocalizedString("Min / Max BG", comment: "Min / Max BG"),
                NSLocalizedString("Prognos BG", comment: "Prognos BG"),
                NSLocalizedString("Uppdaterades", comment: "Uppdaterades")
            ]
            let values = [
                "\(NightscoutManager.shared.latestBGString) (\(plusSign)\(NightscoutManager.shared.latestDeltaString)) \(bgunits)",
                String(format: NSLocalizedString("%@ E", comment: "%@ E"), String(NightscoutManager.shared.latestIOB)),
                "\(NightscoutManager.shared.latestCOBString) g",
                "\(NightscoutManager.shared.latestLowestBGString) / \(NightscoutManager.shared.latestMaxBGString) \(bgunits)",
                "\(NightscoutManager.shared.latestEventualBGString) \(bgunits)",
                //"\(NightscoutManager.shared.latestLocalTimestamp) (\(timeAgo) min sedan)",
                String(format: NSLocalizedString("%@  (%@ min sedan)", comment: "%@  (%@ min sedan)"), String(NightscoutManager.shared.latestLocalTimestamp), timeAgoString)
            ] as [Any]
            
            for (index, metric) in metrics.enumerated() {
                let rowStackView = UIStackView()
                rowStackView.axis = .horizontal
                rowStackView.alignment = .center
                rowStackView.distribution = .fill
                rowStackView.spacing = 2
                
                // SF Symbol ImageView
                let imageView = UIImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
                imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
                
                let label = UILabel()
                label.text = metric
                label.textAlignment = .left
                label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                label.textColor = UIColor.darkGray
                
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.widthAnchor.constraint(equalToConstant: 20).isActive = true
                
                let valueLabel = UILabel()
                valueLabel.text = values[index] as? String
                valueLabel.textAlignment = .right
                valueLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                valueLabel.textColor = UIColor.darkGray
                
                // Change text color and add exclamation mark symbol based on conditions
                if NightscoutManager.shared.evBGWarning && (metric == "Min / Max BG" || metric == "Prognos BG") {
                    label.textColor = UIColor.red
                    label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
                    valueLabel.textColor = UIColor.red
                    valueLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
                    imageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
                    imageView.tintColor = UIColor.red
                } else if NightscoutManager.shared.minBGWarning && metric == "Min / Max BG" {
                    label.textColor = UIColor.orange
                    label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
                    valueLabel.textColor = UIColor.orange
                    valueLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
                    imageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
                    imageView.tintColor = UIColor.orange
                }

                if metric == NSLocalizedString("Blodsocker", comment: "Blodsocker") && NightscoutManager.shared.latestBG < NightscoutManager.shared.latestThreshold {
                    label.textColor = UIColor.red
                    label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
                    valueLabel.textColor = UIColor.red
                    valueLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
                    imageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
                    imageView.tintColor = UIColor.red
                }
                
                if metric == NSLocalizedString("Uppdaterades", comment: "Uppdaterades") {
                    if timeAgo > 10 {
                        label.textColor = UIColor.red
                        label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
                        valueLabel.textColor = UIColor.red
                        valueLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
                        imageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
                        imageView.tintColor = UIColor.red
                    } else if timeAgo > 5 {
                        label.textColor = UIColor.orange
                        label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
                        valueLabel.textColor = UIColor.orange
                        valueLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
                        imageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
                        imageView.tintColor = UIColor.orange
                    } else {
                        // Reset to default appearance if timeAgo <= 5
                        label.textColor = UIColor.darkGray
                        label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                        valueLabel.textColor = UIColor.darkGray
                        valueLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                        imageView.image = nil // No warning image
                    }
                }
                
                // Add the imageView to the rowStackView if there is a warning
                if imageView.image != nil {
                    rowStackView.addArrangedSubview(imageView)
                }
                rowStackView.addArrangedSubview(label)
                rowStackView.addArrangedSubview(spacer)
                rowStackView.addArrangedSubview(valueLabel)
                
                stackView.addArrangedSubview(rowStackView)
                
                // Add a divider line between rows
                if index < metrics.count {
                    let divider = UIView()
                    divider.backgroundColor = UIColor.lightGray
                    divider.translatesAutoresizingMaskIntoConstraints = false
                    stackView.addArrangedSubview(divider)
                    
                    NSLayoutConstraint.activate([
                        divider.heightAnchor.constraint(equalToConstant: 1)
                    ])
                }
            }

            // Store the popup view
            self.popupView = popupView
            
            // Animate the popup view
            view.layoutIfNeeded()
            UIView.animate(withDuration: 0.3, animations: {
                initialTopConstraint.constant = 10
                self.view.layoutIfNeeded()
            })

            // Add tap gesture recognizer to dismiss the popup view
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissPopupView))
            view.addGestureRecognizer(tapGesture)
        }
    }
        
    @objc func dismissPopupView() {
           if let popupView = self.popupView {
               // Animate the popup view to move up
               UIView.animate(withDuration: 0.2, animations: {
                   popupView.frame.origin.y = -270
                   self.view.layoutIfNeeded()
               }) { _ in
                   // Remove the popup view from the superview
                   popupView.removeFromSuperview()
                   self.popupView = nil
               }
           }
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
    
    public func populateMealViewController(khValue: String, fatValue: String, proteinValue: String, bolusValue: String, emojis: String, bolusSoFar: String, bolusTotal: String, carbsSoFar: String, carbsTotal: String, fatSoFar: String, fatTotal: String, proteinSoFar: String, proteinTotal: String, method: String, startDose: Bool, remainDose: Bool, cr: String) {
        
        // Convert values to Double and replace negative values with 0
        let khValueSafe = max(Double(khValue) ?? 0, 0)
        let fatValueSafe = max(Double(fatValue) ?? 0, 0)
        let proteinValueSafe = max(Double(proteinValue) ?? 0, 0)
        let bolusValueSafe = max(Double(bolusValue) ?? 0, 0)
        
        // Format carbs, fat and protein values to remove .0 if present
        let khValueString = formatNumber(khValueSafe)
        let fatValueString = formatNumber(fatValueSafe)
        let proteinValueString = formatNumber(proteinValueSafe)
        let bolusValueString = String(bolusValueSafe)

        // Populate the UI elements with the formatted values
        self.carbsEntryField.text = khValueString
        self.fatEntryField.text = fatValueString
        self.proteinEntryField.text = proteinValueString
        self.bolusCalculated.text = bolusValueString

        // Optionally populate the notes entry field with the emojis or any default text
        self.notesEntryField.text = emojis
        
        // Set the startDose property
        self.startDose = startDose
        
        self.bolusSoFar = bolusSoFar
        self.bolusTotal = bolusTotal
        self.carbsSoFar = carbsSoFar
        self.carbsTotal = carbsTotal
        self.fatSoFar = fatSoFar
        self.fatTotal = fatTotal
        self.proteinSoFar = proteinSoFar
        self.proteinTotal = proteinTotal
        
        // Convert the cr string to a Decimal and set the CR property
        if let crDecimal = Decimal(string: cr) {
            self.CR = crDecimal
        } else {
            print("Failed to convert CR to Decimal")
            // Handle the error as needed, e.g., show an alert to the user or set a default value
        }

        // Set the title based on the remainDose value and always populate bolus field for startdose
        if remainDose {
            self.title = NSLocalizedString("Registrera hela måltiden", comment: "Registrera hela måltiden")
        } else {
            self.title = NSLocalizedString("Registrera startdos", comment: "Registrera startdos")
            if NightscoutManager.shared.evBGWarning || NightscoutManager.shared.minBGWarning {
                print("BG warning - bolus not pre-populated")
            } else {
                bolusStackTapped()
            }
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            // If the value is a whole number (X.0), show it without decimals
            return String(format: "%.0f", value)
        } else {
            // Otherwise, show it with one decimal place
            return String(format: "%.1f", value)
        }
    }
    
    func updateSendMealButtonText(_ text: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "HelveticaNeue-Medium", size: 20.0)!
        ]
        sendMealButton.setAttributedTitle(NSAttributedString(string: text, attributes: attributes), for: .normal)
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
            sendMealButton.setAttributedTitle(NSAttributedString(string: String(format: NSLocalizedString("⛔️ Maxgräns kolhydrater %@ g", comment: "⛔️ Maxgräns kolhydrater %@ g"), formattedMaxCarbs), attributes: attributes), for: .normal)
        } else if fatValue > Decimal(maxFatProtein ?? 100) || proteinValue > Decimal(maxFatProtein ?? 100) {
            // Disable button
            isButtonDisabled = true
            sendMealButton.isEnabled = false
          
            // Format maxFatProtein with zero decimals
            let formattedMaxFatProtein = numberFormatter.string(from: NSNumber(value: maxFatProtein ?? 100)) ?? ""
          
            // Update button title
            sendMealButton.setAttributedTitle(NSAttributedString(string: String(format: NSLocalizedString("⛔️ Maxgräns fett/protein %@ g", comment: "⛔️ Maxgräns fett/protein %@ g"), formattedMaxFatProtein), attributes: attributes), for: .normal)
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
            sendMealButton.setAttributedTitle(NSAttributedString(string: String(format: NSLocalizedString("⛔️ Maxgräns bolus %@ E", comment: "⛔️ Maxgräns bolus %@ E"), formattedMaxBolus), attributes: attributes), for: .normal)
        } else {
            // Enable button
            sendMealButton.isEnabled = true
            isButtonDisabled = false
           // Check if bolusText is not "0" and not empty
            if let bolusText = bolusUnits.text, bolusText != "0" && !bolusText.isEmpty {
                // Update button title with bolus
                sendMealButton.setAttributedTitle(NSAttributedString(string: NSLocalizedString("Skicka Måltid och Bolus", comment: "Skicka Måltid och Bolus"), attributes: attributes), for: .normal)
            } else {
                // Update button title without bolus
                sendMealButton.setAttributedTitle(NSAttributedString(string: NSLocalizedString("Skicka Måltid", comment: "Skicka Måltid"), attributes: attributes), for: .normal)
            }
        }
    }
    
    // Action method to handle tap on bolusStack
    @objc func bolusStackTapped() {
        if NightscoutManager.shared.evBGWarning && bolusEntryField.text == "" {
            // Show a warning alert specific to evBGWarning
            let alert = UIAlertController(
                title: NSLocalizedString("Blodsockervarning!", comment: "Blodsockervarning!"),
                message: NSLocalizedString("Den senaste prognosen visar att blodsockret är eller förväntas bli lågt inom kort.\n\nDet är troligtvis bäst att börja äta och avvakta en liten stund innan du ger en bolus till måltiden.\n\nVill du trots detta ge en bolus till måltiden redan nu?", comment: "Den senaste prognosen visar att blodsockret är eller förväntas bli lågt inom kort.\n\nDet är troligtvis bäst att börja äta och avvakta en liten stund innan du ger en bolus till måltiden.\n\nVill du trots detta ge en bolus till måltiden redan nu?"),
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Ja", style: .destructive, handler: { _ in
                self.toggleBolusEntryField()
            }))
            
            alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: nil))
            
            self.present(alert, animated: true, completion: nil)
        } else if NightscoutManager.shared.minBGWarning && bolusEntryField.text == "" {
            // Show a different warning alert specific to minBGWarning
            let alert = UIAlertController(
                title: NSLocalizedString("Blodsockervarning", comment: "Blodsockervarning"),
                message: NSLocalizedString("Den senaste prognosen visar att blodsockret väntas landa inom målområdet längre fram, men kan bli lågt innan det vänder upp igen.\n\nÄr du säker på att du vill ge en bolus till måltiden?", comment: "Den senaste prognosen visar att blodsockret väntas landa inom målområdet längre fram, men kan bli lågt innan det vänder upp igen.\n\nÄr du säker på att du vill ge en bolus till måltiden?"),
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Ja", style: .destructive, handler: { _ in
                self.toggleBolusEntryField()
            }))
            
            alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: nil))
            
            self.present(alert, animated: true, completion: nil)
        } else {
            // No warnings, proceed as usual
            toggleBolusEntryField()
        }
    }

    private func toggleBolusEntryField() {
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
        
        // BOLUS ENTRIES
        //Process bolus entries
        guard var bolusText = bolusUnits.text else {
            print("Note: Bolus amount not entered")
            return
        }
        
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
                let alertController = UIAlertController(title: NSLocalizedString("Fel", comment: "Fel"), message: NSLocalizedString("Bolus är inmatad i fel format", comment: "Bolus är inmatad i fel format"), preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Ändra", comment: "Ändra"), style: .default, handler: nil))
                present(alertController, animated: true, completion: nil)
                self.handleAlertDismissal() // Enable send button after handling failure to be able to try again
                return
            }
            bolusValue = bolusDouble
        }
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
                let alertController = UIAlertController(title: NSLocalizedString("Fel", comment: "Fel"), message: NSLocalizedString("Kolhydrater är inmatade i fel format", comment: "Kolhydrater är inmatade i fel format"), preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Ändra", comment: "Ändra"), style: .default, handler: nil))
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
                let alertController = UIAlertController(title: NSLocalizedString("Fel", comment: "Fel"), message: NSLocalizedString("Fett är inmatat i fel format", comment: "Fett är inmatat i fel format"), preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Ändra", comment: "Ändra"), style: .default, handler: nil))
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
                let alertController = UIAlertController(title: NSLocalizedString("Fel", comment: "Fel"), message: NSLocalizedString("Protein är inmatat i fel format", comment: "Protein är inmatat i fel format"), preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Ändra", comment: "Ändra"), style: .default, handler: nil))
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
            
            // Determine the appropriate format for bolusValue based on the fractional part
            let bolusDecimalPart = bolusValue.truncatingRemainder(dividingBy: 1)
            let bolusFormat = bolusDecimalPart == 0 ? "%.1f" : "%.2f"
            let trimmedBolusValue = String(format: bolusFormat, bolusValue).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Ensure that carbs, fats, and proteins are non-negative and format them
            let adjustedCarbs = String(format: "%.1f", max(carbs, 0))
            let adjustedFats = String(format: "%.1f", max(fats, 0))
            let adjustedProteins = String(format: "%.1f", max(proteins, 0))
            
            // Get selected date from mealDateTime and format to ISO 8601
            let selectedDate = mealDateTime.date
            let formattedDate = formatDateToISO8601(selectedDate)

            // Construct and return the combined string with localized formatting
            return String(format: NSLocalizedString("Remote Måltid\nKolhydrater: %@g\nFett: %@g\nProtein: %@g\nNotering: %@\nDatum: %@\nInsulin: %@E\nInlagt av: %@\nHemlig kod: %@", comment: "Remote meal details with carbs, fat, protein, note, date, insulin, entered by, and secret code"), adjustedCarbs, adjustedFats, adjustedProteins, cleanedMealNotes, formattedDate, trimmedBolusValue, name, secret)
        }
        //Alert for meal without bolus
        func showMealConfirmationAlert(combinedString: String) {
            // Set isAlertShowing to true before showing the alert
            isAlertShowing = true
            // Confirmation alert before sending the request
            let confirmationAlert = UIAlertController(title: NSLocalizedString("Bekräfta måltid", comment: "Bekräfta måltid"), message: NSLocalizedString("Vill du registrera denna måltid?", comment: "Vill du registrera denna måltid?"), preferredStyle: .alert)
            
            confirmationAlert.addAction(UIAlertAction(title: NSLocalizedString("Ja", comment: "Ja"), style: .default, handler: { (action: UIAlertAction!) in
                // Proceed with sending the request
                self.sendMealRequest(combinedString: combinedString)
            }))
            
            confirmationAlert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel, handler: { (action: UIAlertAction!) in
                // Handle dismissal when "Cancel" is selected
                self.handleAlertDismissal()
            }))
            
            present(confirmationAlert, animated: true, completion: nil)
        }
                
        func showMealBolusConfirmationAlert(combinedString: String) {
            let method = UserDefaultsRepository.method
            isAlertShowing = true
            
            let confirmationAlert = UIAlertController(title: NSLocalizedString("Bekräfta måltid och bolus", comment: "Bekräfta måltid och bolus"), message: String(format: NSLocalizedString("Vill du registrera denna måltid och ge %.2f E bolus?", comment: "Vill du registrera denna måltid och ge %.2f E bolus?"), bolusValue), preferredStyle: .alert)
            
            let confirmAction: UIAlertAction
            
            // Authenticate with biometrics if using Twilio, otherwise just authenticate with passcode within iOS shortcut
            if method == "iOS Shortcuts" {
                confirmAction = UIAlertAction(title: NSLocalizedString("Ja", comment: "Ja"), style: .default) { _ in
                    self.sendMealRequest(combinedString: combinedString)
                }
            } else {
                confirmAction = UIAlertAction(title: NSLocalizedString("Ja", comment: "Ja"), style: .default) { _ in
                    self.authenticateWithBiometrics {
                        self.sendMealRequest(combinedString: combinedString)
                    }
                }
            }
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel) { _ in
                self.handleAlertDismissal()
            }
            
            confirmationAlert.addAction(confirmAction)
            confirmationAlert.addAction(cancelAction)
            
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
        let carbs = extractValue(from: combinedString, prefix: NSLocalizedString("Kolhydrater: ", comment: "Kolhydrater: "), suffix: NSLocalizedString("g", comment: "g"))
        let fats = extractValue(from: combinedString, prefix: NSLocalizedString("Fett: ", comment: "Fett: "), suffix: NSLocalizedString("g", comment: "g"))
        let proteins = extractValue(from: combinedString, prefix: NSLocalizedString("Protein: ", comment: "Protein: "), suffix: NSLocalizedString("g", comment: "g"))
        let bolus = extractValue(from: combinedString, prefix: NSLocalizedString("Insulin: ", comment: "Insulin: "), suffix: NSLocalizedString("E", comment: "E"))

        if method == "iOS Shortcuts" {
            // Don't call the delegate here; wait until the success callback is triggered
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
        
        // Define your custom callback URLs
        let successCallback = "carbcounter://completed" // Add completed for future use when the shortcut has run, but for instance the passcode was wrong. NOTE: not to mixed up with carbcounter://success that should be returned by the carbcounter shortcut to proceed with the meal registration)
        let errorCallback = "carbcounter://error"
        let cancelCallback = "carbcounter://cancel"
        
        // Encode the callback URLs
        guard let successEncoded = successCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let errorEncoded = errorCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let cancelEncoded = cancelCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("Failed to encode callback URLs")
            return
        }
        
        // Construct the final URL with x-callback-url
        let urlString = "shortcuts://x-callback-url/run-shortcut?name=CarbCounter&input=text&text=\(encodedString)&x-success=\(successEncoded)&x-error=\(errorEncoded)&x-cancel=\(cancelEncoded)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        
        print("Waiting for shortcut completion...")
    }
    
    @objc private func handleShortcutSuccess() {
        print("Shortcut succeeded, updating meal values...")
        
        // Play a success sound
        AudioServicesPlaySystemSound(SystemSoundID(1322))
        
        // Only now call the delegate method after successful completion
        delegate?.didUpdateMealValues(
            khValue: carbsEntryField.text ?? "",
            fatValue: fatEntryField.text ?? "",
            proteinValue: proteinEntryField.text ?? "",
            bolusValue: bolusEntryField.text ?? "",
            startDose: self.startDose
        )
        
        // Display the success view instead of an alert
        let successView = SuccessView()
        if let window = self.view.window {
            successView.showInView(window) // Show the success view in the window
        }

        // Dismiss the view controller after showing the success view
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { // Wait for the success view animation to complete
            self.dismiss(animated: true, completion: nil)
        }
    }

    @objc private func handleShortcutError() {
        print("Shortcut failed, showing error alert...")
        
        // Play a error sound
        AudioServicesPlaySystemSound(SystemSoundID(1053))
        
        showAlert(title: NSLocalizedString("Misslyckades", comment: "Misslyckades"), message: NSLocalizedString("Ett fel uppstod när genvägen skulle köras. Du kan försöka igen.", comment: "Ett fel uppstod när genvägen skulle köras. Du kan försöka igen."), completion: {
            self.handleAlertDismissal()  // Re-enable the send button after error handling
        })
    }

    @objc private func handleShortcutCancel() {
        print("Shortcut was cancelled, showing cancellation alert...")
        
        // Play a error sound
        AudioServicesPlaySystemSound(SystemSoundID(1053))
        
        showAlert(title: NSLocalizedString("Avbröts", comment: "Avbröts"), message: NSLocalizedString("Genvägen avbröts innan den körts färdigt. Du kan försöka igen.", comment: "Genvägen avbröts innan den körts färdigt. Du kan försöka igen.") , completion: {
            self.handleAlertDismissal()  // Re-enable the send button after cancellation
        })
    }
    
    @objc private func handleShortcutPasscode() {
        print("Shortcut was cancelled due to wrong passcode, showing passcode alert...")
        
        // Play a error sound
        AudioServicesPlaySystemSound(SystemSoundID(1053))
        
        showAlert(title: NSLocalizedString("Fel lösenkod", comment: "Fel lösenkod"), message: NSLocalizedString("Genvägen avbröts pga fel lösenkod. Du kan försöka igen.", comment: "Genvägen avbröts pga fel lösenkod. Du kan försöka igen.") , completion: {
            self.handleAlertDismissal()  // Re-enable the send button after cancellation
        })
    }

    private func showAlert(title: String, message: String, completion: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            completion()  // Call the completion handler after dismissing the alert
        }))
        present(alert, animated: true, completion: nil)
    }

    // Handle the Twilio SMS request case
    private func handleTwilioRequest(combinedString: String, carbs: String, fats: String, proteins: String, bolus: String, startDose: Bool) {
        twilioRequest(combinedString: combinedString) { result in
            switch result {
            case .success:
                // Play success sound
                AudioServicesPlaySystemSound(SystemSoundID(1322))
                
                // Show SuccessView
                let successView = SuccessView()
                if let window = self.view.window {
                    successView.showInView(window) // Show the success view in the window
                }

                // Wait for the success view animation to finish before dismissing the view controller
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.delegate?.didUpdateMealValues(
                        khValue: carbs,
                        fatValue: fats,
                        proteinValue: proteins,
                        bolusValue: bolus,
                        startDose: self.startDose
                    )
                    print("Dismissing MealViewController after successful SMS API call")
                    self.dismiss(animated: true, completion: nil)
                }
                
            case .failure(let error):
                // Play failure sound
                AudioServicesPlaySystemSound(SystemSoundID(1053))
                
                // Show failure alert
                let alertController = UIAlertController(
                    title: NSLocalizedString("Fel", comment: "Error"),
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        }
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
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

protocol MealViewControllerDelegate: AnyObject {
    func didUpdateMealValues(khValue: String, fatValue: String, proteinValue: String, bolusValue: String, startDose: Bool)
}
