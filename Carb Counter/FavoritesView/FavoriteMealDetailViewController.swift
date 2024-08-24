import UIKit
import CoreData

protocol FavoriteMealDetailViewControllerDelegate: AnyObject {
    func favoriteMealDetailViewControllerDidSave(_ controller: FavoriteMealDetailViewController)
}

class FavoriteMealDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    weak var delegate: FavoriteMealDetailViewControllerDelegate?
    
    var favoriteMeal: FavoriteMeals!
    var tableView: UITableView!
    var nameTextField: UITextField!
    
    var dataSharingVC: DataSharingViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Ändra favoritmåltid", comment: "Edit favorite meal")
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
        
        setupView()
        setupNavigationBar()
        tableView.reloadData()
        
        setupCloseButton()
        
        // Instantiate DataSharingViewController programmatically
        dataSharingVC = DataSharingViewController()
    }
    
    private func setupView() {
        nameTextField = UITextField()
        nameTextField.text = favoriteMeal.name
        nameTextField.font = UIFont.systemFont(ofSize: 20)
        nameTextField.borderStyle = .roundedRect
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.autocorrectionType = .no
        nameTextField.spellCheckingType = .yes
        nameTextField.backgroundColor = .systemGray6
        addDoneButtonOnKeyboard()
        view.addSubview(nameTextField)
        
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = .clear
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 20),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .clear
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        } else {
            navigationController?.navigationBar.barTintColor = .clear
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.label]
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Spara", comment: "Save"), style: .done, target: self, action: #selector(saveChanges))
    }
    
    private func setupCloseButton() {
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func saveChanges() {
        favoriteMeal.name = nameTextField.text
        
        CoreDataStack.shared.saveContext()
        
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = self.dataSharingVC else {
            dismiss(animated: true, completion: nil)
            return
        }
        
        // Call the desired function
        Task {
            print("Favorite meals export triggered")
            await dataSharingVC.exportFavoriteMealsToCSV()
        }
        
        delegate?.favoriteMealDetailViewControllerDidSave(self)
        
        dismiss(animated: true, completion: nil)
    }
    
    private func addDoneButtonOnKeyboard() {
        let doneToolbar: UIToolbar = UIToolbar()
        doneToolbar.sizeToFit()
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Done"), style: .done, target: self, action: #selector(doneButtonAction))
        
        let items = [flexSpace, done]
        doneToolbar.items = items
        doneToolbar.barStyle = .default
        
        nameTextField.inputAccessoryView = doneToolbar
    }
    
    @objc private func doneButtonAction() {
        nameTextField.resignFirstResponder()
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getItems().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as UITableViewCell
        cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        cell.backgroundColor = .clear
        
        let items = getItems()
        let item = items[indexPath.row]
        cell.textLabel?.text = item["name"] as? String
        
        if let portionServed = item["portionServed"] as? String, let portionServedDouble = Double(portionServed) {
            let formattedPortion: String
            if portionServedDouble.truncatingRemainder(dividingBy: 1) == 0 {
                formattedPortion = String(format: "%.0f", portionServedDouble)
            } else {
                formattedPortion = String(format: "%.1f", portionServedDouble)
            }
            
            if let perPiece = item["perPiece"] as? Bool, perPiece {
                cell.detailTextLabel?.text = String(format: NSLocalizedString("Mängd: %@ st", comment: "Amount: %@ pieces"), formattedPortion)
            } else {
                cell.detailTextLabel?.text = String(format: NSLocalizedString("Mängd: %@ g", comment: "Amount: %@ grams"), formattedPortion)
            }
        } else {
            if let perPiece = item["perPiece"] as? Bool, perPiece {
                cell.detailTextLabel?.text = String(format: NSLocalizedString("Mängd: %@ st", comment: "Amount: %@ pieces"), item["portionServed"] as? String ?? "")
            } else {
                cell.detailTextLabel?.text = String(format: NSLocalizedString("Mängd: %@ g", comment: "Amount: %@ grams"), item["portionServed"] as? String ?? "")
            }
        }
        // Apply custom font to detailTextLabel
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        cell.detailTextLabel?.textColor = .gray
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var items = getItems()
        let item = items[indexPath.row]
        
        let editAlert = UIAlertController(title: NSLocalizedString("Ändra mängd", comment: "Edit amount"), message: String(format: NSLocalizedString("Ange en ny mängd för %@:", comment: "Enter a new amount for %@:"), item["name"] as? String ?? ""), preferredStyle: .alert)
        editAlert.addTextField { textField in
            if let portionServed = item["portionServed"] as? String, let portionServedDouble = Double(portionServed) {
                if portionServedDouble.truncatingRemainder(dividingBy: 1) == 0 {
                    textField.text = String(format: "%.0f", portionServedDouble)
                } else {
                    textField.text = String(format: "%.1f", portionServedDouble)
                }
            } else {
                textField.text = item["portionServed"] as? String
            }
            
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            self.addDoneButtonOnKeyboard(to: textField)
        }
        let saveAction = UIAlertAction(title: NSLocalizedString("Spara", comment: "Save"), style: .default) { [weak self] _ in
            guard let self = self, let newPortion = editAlert.textFields?.first?.text else { return }
            items[indexPath.row]["portionServed"] = newPortion
            self.favoriteMeal.items = self.updateItems(items: items)
            
            CoreDataStack.shared.saveContext()
            
            // Ensure dataSharingVC is instantiated
            guard let dataSharingVC = self.dataSharingVC else { return }
            
            // Call the desired function
            Task {
                print("Favorite meals export triggered")
                await dataSharingVC.exportFavoriteMealsToCSV()
            }
            
            self.tableView.reloadData()
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel"), style: .cancel, handler: nil)
        
        editAlert.addAction(saveAction)
        editAlert.addAction(cancelAction)
        
        present(editAlert, animated: true, completion: nil)
    }
    
    private func getItems() -> [[String: Any]] {
        if let jsonString = favoriteMeal.items as? String,
           let jsonData = jsonString.data(using: .utf8),
           let items = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] {
            return items
        }
        return []
    }
    
    private func updateItems(items: [[String: Any]]) -> NSObject {
        if let jsonData = try? JSONSerialization.data(withJSONObject: items, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString as NSObject
        }
        return items as NSObject
    }
    
    private func addDoneButtonOnKeyboard(to textField: UITextField) {
        let doneToolbar: UIToolbar = UIToolbar()
        doneToolbar.sizeToFit()
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Done"), style: .done, target: self, action: #selector(doneEditingTextField))
        
        let items = [flexSpace, done]
        doneToolbar.items = items
        doneToolbar.barStyle = .default
        textField.inputAccessoryView = doneToolbar
    }
    
    @objc private func doneEditingTextField() {
        view.endEditing(true)
    }
}
