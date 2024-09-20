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

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: EditRegistrationPopoverView(registeredFatSoFar: .constant(0), registeredProteinSoFar: .constant(0), registeredBolusSoFar: .constant(0), registeredCarbsSoFar: .constant(0), mealDate: .constant(nil), onDismiss: nil))
    }

    init(registeredFatSoFar: Binding<Double>, registeredProteinSoFar: Binding<Double>, registeredBolusSoFar: Binding<Double>, registeredCarbsSoFar: Binding<Double>, mealDate: Binding<Date?>, onDismiss: (() -> Void)?) {
        let view = EditRegistrationPopoverView(
            registeredFatSoFar: registeredFatSoFar,
            registeredProteinSoFar: registeredProteinSoFar,
            registeredBolusSoFar: registeredBolusSoFar,
            registeredCarbsSoFar: registeredCarbsSoFar,
            mealDate: mealDate,
            onDismiss: onDismiss
        )
        super.init(rootView: view)
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
        super.init(coder: aDecoder, rootView: InfoPopoverView(title: "", message: ""))
    }
    
    init(title: String, message: String) {
        let view = InfoPopoverView(title: title, message: message)
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
