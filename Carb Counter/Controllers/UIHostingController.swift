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
        preferredContentSize = CGSize(width: 340, height: 370)
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
