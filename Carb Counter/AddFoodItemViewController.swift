//
//  AddFoodItemViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-18.
//
// AddFoodItemViewController.swift

import UIKit
import CoreData

protocol AddFoodItemDelegate: AnyObject {
    func didAddFoodItem()
}

class AddFoodItemViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var carbsTextField: UITextField!
    @IBOutlet weak var fatTextField: UITextField!
    @IBOutlet weak var proteinTextField: UITextField!
    @IBOutlet weak var saveButton: UIButton!

    weak var delegate: AddFoodItemDelegate?
    var foodItem: FoodItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupSaveButton()
        setupUI()
    }

    private func setupSaveButton() {
        saveButton.setTitle("Save", for: .normal)
        saveButton.addTarget(self, action: #selector(saveButtonTap), for: .touchUpInside)
    }

    private func setupUI() {
        if let foodItem = foodItem {
            title = "Edit Food Item"
            nameTextField.text = foodItem.name
            carbsTextField.text = String(foodItem.carbohydrates)
            fatTextField.text = String(foodItem.fat)
            proteinTextField.text = String(foodItem.protein)
        } else {
            title = "Add Food Item"
        }
    }

    @IBAction func saveButtonTap(_ sender: UIButton) {
        saveFoodItem()
        print("Save button tapped")
    }

    private func saveFoodItem() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext

        if let foodItem = foodItem {
            // Update existing food item
            foodItem.name = nameTextField.text ?? ""
            foodItem.carbohydrates = Double(carbsTextField.text ?? "") ?? 0.0
            foodItem.fat = Double(fatTextField.text ?? "") ?? 0.0
            foodItem.protein = Double(proteinTextField.text ?? "") ?? 0.0
        } else {
            // Create new food item
            let newFoodItem = FoodItem(context: context)
            newFoodItem.id = UUID()
            newFoodItem.name = nameTextField.text ?? ""
            newFoodItem.carbohydrates = Double(carbsTextField.text ?? "") ?? 0.0
            newFoodItem.fat = Double(fatTextField.text ?? "") ?? 0.0
            newFoodItem.protein = Double(proteinTextField.text ?? "") ?? 0.0
        }

        do {
            try context.save()
            delegate?.didAddFoodItem()
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
}
