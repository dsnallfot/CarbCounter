//
//  UIHostingController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-09-18.
//

import UIKit
import SwiftUI

class EditRegistrationPopoverHostingController: UIHostingController<EditRegistrationPopoverView> {
    var onDismiss: (() -> Void)?
    var composeMealViewController: ComposeMealViewController?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: EditRegistrationPopoverView(registeredFatSoFar: .constant(0), registeredProteinSoFar: .constant(0), registeredBolusSoFar: .constant(0), registeredCarbsSoFar: .constant(0), mealDate: .constant(nil), composeMealViewController: nil, onDismiss: nil))
    }

    init(registeredFatSoFar: Binding<Double>, registeredProteinSoFar: Binding<Double>, registeredBolusSoFar: Binding<Double>, registeredCarbsSoFar: Binding<Double>, mealDate: Binding<Date?>, composeMealViewController: ComposeMealViewController?, onDismiss: (() -> Void)?) {
        let view = EditRegistrationPopoverView(
            registeredFatSoFar: registeredFatSoFar,
            registeredProteinSoFar: registeredProteinSoFar,
            registeredBolusSoFar: registeredBolusSoFar,
            registeredCarbsSoFar: registeredCarbsSoFar,
            mealDate: mealDate,
            composeMealViewController: composeMealViewController,
            onDismiss: onDismiss
        )
        super.init(rootView: view)
        self.composeMealViewController = composeMealViewController
        modalPresentationStyle = .popover
        popoverPresentationController?.delegate = self

        // Set preferredContentSize to accommodate the form
        preferredContentSize = CGSize(width: 340, height: 380)
    }
}

extension EditRegistrationPopoverHostingController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        dismiss(animated: true, completion: nil)
        onDismiss?()
    }

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

class InfoPopoverHostingController: UIHostingController<InfoPopoverView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: InfoPopoverView(title: "", message: "", statusTitle: "", statusMessage: "", progress: 0.0, progressBarColor: Color.clear, showProgressBar: false))
    }
    
    init(title: String, message: String, statusTitle: String, statusMessage: String, progress: CGFloat, progressBarColor: Color, showProgressBar: Bool) {
        let view = InfoPopoverView(
            title: title,
            message: message,
            statusTitle: statusTitle,
            statusMessage: statusMessage,
            progress: progress,
            progressBarColor: progressBarColor,  // Pass the progress bar color
            showProgressBar: showProgressBar  // Pass the boolean to show/hide progress bar
        )
        super.init(rootView: view)
        modalPresentationStyle = .popover
        popoverPresentationController?.delegate = self
        
        // Dynamically calculate preferredContentSize
        let width: CGFloat = 300
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.layoutIfNeeded()
        let size = hostingController.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        preferredContentSize = CGSize(width: width, height: size.height)
    }
}

extension InfoPopoverHostingController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        dismiss(animated: true, completion: nil)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

extension ComposeMealViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

class CustomAlertViewController: UIViewController {
    var datePicker: UIDatePicker!
    var mealDate: Date?
    var onSave: ((Date) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the background color and style
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        // Create the container view for the alert
        let containerView = UIView()
        containerView.backgroundColor = .systemGray6
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Add title label
        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("Ändra tid för måltiden", comment: "Title for editing meal time")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // Configure date picker
        datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.locale = Locale(identifier: "sv_SE")
        datePicker.date = mealDate ?? Date()
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(datePicker)

        // Add Save button
        let saveButton = UIButton(type: .system)
        saveButton.setTitle(NSLocalizedString("Spara", comment: "Save button title"), for: .normal)
        
        // Apply custom styling to the button to match the SwiftUI example
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 10
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 19, weight: .semibold) // Font styling to match SwiftUI
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add padding using constraints
        saveButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        
        // Add action for the button
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        containerView.addSubview(saveButton)

        // Set up constraints for the container view and its contents
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 250),
            containerView.heightAnchor.constraint(equalToConstant: 170),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),

            datePicker.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            datePicker.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            //datePicker.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.9), // Slight padding on sides

            saveButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            saveButton.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 20),
            saveButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            saveButton.heightAnchor.constraint(equalToConstant: 40) // Fixed height for the button
        ])
    }

    @objc private func saveButtonTapped() {
        onSave?(datePicker.date)
        dismiss(animated: true, completion: nil)
    }
}

extension ComposeMealViewController {
    
    public func presentPopover(title: String, message: String, statusTitle: String, statusMessage: String, progress: CGFloat, progressBarColor: Color, showProgressBar: Bool, sourceView: UIView) {
        let popoverController = InfoPopoverHostingController(
            title: title,
            message: message,
            statusTitle: statusTitle,
            statusMessage: statusMessage,
            progress: progress,
            progressBarColor: progressBarColor,
            showProgressBar: showProgressBar
        )
        popoverController.modalPresentationStyle = .popover
        popoverController.popoverPresentationController?.sourceView = sourceView
        popoverController.popoverPresentationController?.sourceRect = sourceView.bounds
        popoverController.popoverPresentationController?.permittedArrowDirections = .any
        popoverController.popoverPresentationController?.delegate = self
        present(popoverController, animated: true, completion: nil)
    }
    
    @objc public func showBolusInfo() {
        let bolusRemains = totalRemainsBolusLabel.text?.isEmpty == true ? "0 E" : String(totalRemainsBolusLabel.text?.replacingOccurrences(of: " ", with: NSLocalizedString("0E", comment: "0E")).replacingOccurrences(of: "E", with: " E").replacingOccurrences(of: "U", with: " U") ?? "0 E")
        
        let formattedRegisteredBolus: String
        if registeredBolusSoFar.truncatingRemainder(dividingBy: 1) == 0 {
            formattedRegisteredBolus = String(format: "%.0f", registeredBolusSoFar)
        } else if registeredBolusSoFar * 10 == floor(registeredBolusSoFar * 10) {
            formattedRegisteredBolus = String(format: "%.1f", registeredBolusSoFar)
        } else {
            formattedRegisteredBolus = String(format: "%.2f", registeredBolusSoFar)
        }
        
        // Calculate progress value
        let totalBolusValue = Double(totalBolusAmountLabel.text?.replacingOccurrences(of: " E", with: "") ?? "0") ?? 0.0
        let progress: CGFloat = totalBolusValue > 0 ? CGFloat(registeredBolusSoFar / totalBolusValue) : 0.0
        
        presentPopover(
            title: NSLocalizedString("Bolus Total", comment: "Bolus Total"),
            message: NSLocalizedString("Den beräknade mängden insulin som krävs för att täcka kolhydraterna i måltiden.", comment: "Den beräknade mängden insulin som krävs för att täcka kolhydraterna i måltiden."),
            statusTitle: NSLocalizedString("Status för denna måltid:", comment: "Status för denna måltid:"),
            statusMessage: String(format: NSLocalizedString("• Totalt beräknat behov: %@\n• Hittills registerat: %@ E\n• Kvar att registrera: %@", comment: "• Totalt beräknat behov: %@\n• Hittills registerat: %@ E\n• Kvar att registrera: %@"), totalBolusAmountLabel.text ?? "0 E", formattedRegisteredBolus, bolusRemains),
            progress: progress,
            progressBarColor: Color.indigo,
            showProgressBar: true,
            sourceView: totalBolusAmountLabel
        )
    }
    
    @objc public func showCarbsInfo() {
        let carbsRemains = String(totalRemainsLabel.text ?? NSLocalizedString("0 g", comment: "0 g"))
            .replacingOccurrences(of: "g", with: " g")
            .replacingOccurrences(of: " KLAR", with: "0 g")
            .replacingOccurrences(of: " DONE", with: "0 g")
            .replacingOccurrences(of: " PÅ INPUT", with: "0 g")
            .replacingOccurrences(of: " FOR INPUT", with: "0 g")
        let carbsRegistered = (totalRegisteredCarbsLabel.text ?? "0 g").replacingOccurrences(of: "--", with: "0 g")
        
        // Calculate progress value
        let totalCarbsValue = Double(totalNetCarbsLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0") ?? 0.0
        let registeredCarbs = Double(carbsRegistered.replacingOccurrences(of: " g", with: "")) ?? 0.0
        let progress: CGFloat = totalCarbsValue > 0 ? CGFloat(registeredCarbs / totalCarbsValue) : 0.0
        
        presentPopover(
            title: NSLocalizedString("Kolhydrater Totalt", comment: "Kolhydrater Totalt"),
            message: NSLocalizedString("Den beräknade summan av alla kolhydrater i måltiden.", comment: "Den beräknade summan av alla kolhydrater i måltiden."),
            statusTitle: NSLocalizedString("Status för denna måltid:", comment: "Status för denna måltid:"),
            statusMessage: String(format: NSLocalizedString("• Total mängd kolhydrater: %@\n• Hittills registerat: %@\n• Kvar att registrera: %@", comment: "• Total mängd kolhydrater: %@\n• Hittills registerat: %@\n• Kvar att registrera: %@"), totalNetCarbsLabel.text ?? "0 g", carbsRegistered, carbsRemains),
            progress: progress,
            progressBarColor: Color.orange,
            showProgressBar: true,
            sourceView: totalNetCarbsLabel
        )
    }
    
    @objc public func showFatInfo() {
        let fatTotalValue = Double(totalNetFatLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0") ?? 0.0
        let fatRemaining = String(format: "%.0f", fatTotalValue - registeredFatSoFar)
        
        // Calculate progress value
        let progress: CGFloat = fatTotalValue > 0 ? CGFloat(registeredFatSoFar / fatTotalValue) : 0.0
        
        presentPopover(
            title: NSLocalizedString("Fett Totalt", comment: "Fett Totalt"),
            message: NSLocalizedString("Den beräknade summan av all fett i måltiden. \n\nFett kräver också insulin, men med några timmars fördröjning.", comment: "Den beräknade summan av all fett i måltiden. \n\nFett kräver också insulin, men med några timmars fördröjning."),
            statusTitle: NSLocalizedString("Status för denna måltid:", comment: "Status för denna måltid:"),
            statusMessage: String(format: NSLocalizedString("• Total mängd fett: %@\n• Hittills registerat: %.0f g\n• Kvar att registrera: %@ g", comment: "• Total mängd fett: %@\n• Hittills registerat: %.0f g\n• Kvar att registrera: %@ g"), totalNetFatLabel.text ?? "0 g", registeredFatSoFar, fatRemaining),
            progress: progress,
            progressBarColor: Color.brown,
            showProgressBar: true,
            sourceView: totalNetFatLabel
        )
    }
    
    @objc public func showProteinInfo() {
        let proteinTotalValue = Double(totalNetProteinLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0") ?? 0.0
        let proteinRemaining = String(format: "%.0f", proteinTotalValue - registeredProteinSoFar)
        
        // Calculate progress value
        let progress: CGFloat = proteinTotalValue > 0 ? CGFloat(registeredProteinSoFar / proteinTotalValue) : 0.0
        
        presentPopover(
            title: NSLocalizedString("Protein Totalt", comment: "Protein Totalt"),
            message: NSLocalizedString("Den beräknade summan av all protein i måltiden. \n\nProtein kräver också insulin, men med några timmars fördröjning.", comment: "Den beräknade summan av all protein i måltiden. \n\nProtein kräver också insulin, men med några timmars fördröjning."),
            statusTitle: NSLocalizedString("Status för denna måltid:", comment: "Status för denna måltid:"),
            statusMessage: String(format: NSLocalizedString("• Total mängd protein: %@\n• Hittills registerat: %.0f g\n• Kvar att registrera: %@ g", comment: "• Total mängd protein: %@\n• Hittills registerat: %.0f g\n• Kvar att registrera: %@ g"), totalNetProteinLabel.text ?? "0 g", registeredProteinSoFar, proteinRemaining),
            progress: progress,
            progressBarColor: Color.brown,
            showProgressBar: true,
            sourceView: totalNetProteinLabel
        )
    }
    
    @objc public func showCRInfo() {
        let CR = UserDefaultsRepository.scheduledCarbRatio
        let amount = CR * 2
        
        func formatValue(_ value: Double) -> String {
            return value == floor(value) ? String(format: "%.0f", value) : String(format: "%.1f", value)
        }
        
        let formattedCR = formatValue(CR)
        let formattedAmount = formatValue(amount)
        
        let message = String(
            format: NSLocalizedString("Även kallad Carb Ratio (CR)\n\nVärdet motsvarar hur stor mängd kolhydrater som 1 E insulin täcker.", comment: "Även kallad Carb Ratio (CR)\n\nVärdet motsvarar hur stor mängd kolhydrater som 1 E insulin täcker."), formattedCR, formattedAmount)
        let statusMessage = String(
            format: NSLocalizedString("CR %@ innebär att det behövs 2 E insulin till %@ g kolhydrater.", comment: "CR %@ innebär att det behövs 2 E insulin till %@ g kolhydrater."), formattedCR, formattedAmount)
        
        presentPopover(
            title: NSLocalizedString("Insulinkvot", comment: "Insulinkvot"),
            message: message,
            statusTitle: NSLocalizedString("Exempel:", comment: "Exempel:"),
            statusMessage: statusMessage,
            progress: 0,
            progressBarColor: Color.clear,
            showProgressBar: false,
            sourceView: nowCRLabel
        )
    }
    
    @objc public func overrideLabelTapped() {
        if UserDefaultsRepository.method == "Trio APNS" {
            WebLoadNSTreatments {
                var overrideView = OverrideView()
                overrideView.delegate = self // Pass the current instance of ComposeMealViewController as the delegate
                let overrideVC = UIHostingController(rootView: overrideView)
                overrideVC.modalPresentationStyle = .formSheet
                self.present(overrideVC, animated: true, completion: nil)
                
                // Reset the flag to allow UI updates after handling override
                self.needsUIUpdate = true
            }
            return
        }

        if let startTime = UserDefaultsRepository.overrideStartTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            let formattedDate = formatter.string(from: startTime)
            let latestFactorUsed = UserDefaultsRepository.overrideFactorUsed
            presentPopover(
                title: String(format: NSLocalizedString("Senaste override • %@", comment: "Senaste override • %@"), latestFactorUsed),
                message: String(format: NSLocalizedString("Aktiverades %@", comment: "Aktiverades %@"), formattedDate),
                statusTitle: "",
                statusMessage: "",
                progress: 0,
                progressBarColor: Color.clear,
                showProgressBar: false,
                sourceView: addButtonRowView.overrideLabel
            )
        } else {
            presentPopover(
                title: NSLocalizedString("Senaste override", comment: "Senaste override"),
                message: NSLocalizedString("Ingen tidigare aktivering hittades.", comment: "Ingen tidigare aktivering hittades."),
                statusTitle: "",
                statusMessage: "",
                progress: 0,
                progressBarColor: Color.clear,
                showProgressBar: false,
                sourceView: addButtonRowView.overrideLabel
            )
        }

        // Reset the flag in case no treatments were loaded
        needsUIUpdate = true
    }
    
    @objc public func editCurrentRegistration() {
        let popoverController = EditRegistrationPopoverHostingController(
            registeredFatSoFar: Binding(get: { [weak self] in
                self?.registeredFatSoFar ?? 0.0
            }, set: { [weak self] newValue in
                self?.registeredFatSoFar = newValue
            }),
            registeredProteinSoFar: Binding(get: { [weak self] in
                self?.registeredProteinSoFar ?? 0.0
            }, set: { [weak self] newValue in
                self?.registeredProteinSoFar = newValue
            }),
            registeredBolusSoFar: Binding(get: { [weak self] in
                self?.registeredBolusSoFar ?? 0.0
            }, set: { [weak self] newValue in
                self?.registeredBolusSoFar = newValue
            }),
            registeredCarbsSoFar: Binding(get: { [weak self] in
                if let text = self?.totalRegisteredCarbsLabel.text?.replacingOccurrences(of: " g", with: ""),
                   let value = Double(text) {
                    return value
                }
                return 0.0
            }, set: { [weak self] newValue in
                self?.totalRegisteredCarbsLabel.text = String(format: "%.0f g", newValue)
                self?.registeredCarbsSoFar = newValue
            }),
            mealDate: Binding(get: { [weak self] in
                self?.mealDate
            }, set: { [weak self] newValue in
                self?.mealDate = newValue
            }),
            composeMealViewController: self,
            onDismiss: { [weak self] in
                guard let self = self else { return }
                self.totalRegisteredCarbsLabelDidChange(self.totalRegisteredCarbsLabel)
                self.updateTotalNutrients()
                self.updateRemainsBolus()
                self.updateHeadlineVisibility()
                self.updateClearAllButtonState()
                self.saveToCoreData()
                self.saveValuesToUserDefaults()
            }
        )
        popoverController.modalPresentationStyle = .popover
        popoverController.popoverPresentationController?.sourceView = totalRegisteredCarbsLabel
        popoverController.popoverPresentationController?.permittedArrowDirections = .any
        popoverController.popoverPresentationController?.delegate = self
        present(popoverController, animated: true, completion: nil)
    }
}


