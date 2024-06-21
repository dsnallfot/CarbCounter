import UIKit
import CoreData

class FavoriteMealDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var favoriteMeal: FavoriteMeals!
    var tableView: UITableView!
    var nameTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Edit Favorite Meal"
        
        setupView()
        setupNavigationBar()
    }
    
    private func setupView() {
        // Add text field for editing meal name
        nameTextField = UITextField()
        nameTextField.text = favoriteMeal.name
        nameTextField.font = UIFont.systemFont(ofSize: 20)
        nameTextField.borderStyle = .roundedRect
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.autocorrectionType = .no
        nameTextField.spellCheckingType = .no
        addDoneButtonOnKeyboard()
        view.addSubview(nameTextField)
        
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveChanges))
    }
    
    @objc private func saveChanges() {
        favoriteMeal.name = nameTextField.text
        
        // Save the context
        CoreDataStack.shared.saveContext()
        
        navigationController?.popViewController(animated: true)
    }
    
    private func addDoneButtonOnKeyboard() {
        let doneToolbar: UIToolbar = UIToolbar()
        doneToolbar.sizeToFit()
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonAction))
        
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
        return (favoriteMeal.items as? [[String: Any]])?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        if let items = favoriteMeal.items as? [[String: Any]] {
            let item = items[indexPath.row]
            cell.textLabel?.text = item["name"] as? String
            cell.detailTextLabel?.text = "Portion: \(item["portionServed"] as? String ?? "")"
        }
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let items = favoriteMeal.items as? [[String: Any]] else { return }
        let item = items[indexPath.row]
        
        let editAlert = UIAlertController(title: "Edit Portion", message: "Enter a new portion for \(item["name"] as? String ?? ""):", preferredStyle: .alert)
        editAlert.addTextField { textField in
            textField.text = item["portionServed"] as? String
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            self.addDoneButtonOnKeyboard(to: textField)
        }
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self, let newPortion = editAlert.textFields?.first?.text else { return }
            self.favoriteMeal.items = self.updatePortion(for: item["name"] as? String ?? "", with: newPortion)
            
            // Save the context
            CoreDataStack.shared.saveContext()
            self.tableView.reloadData()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        editAlert.addAction(saveAction)
        editAlert.addAction(cancelAction)
        
        present(editAlert, animated: true, completion: nil)
    }
    
    private func updatePortion(for itemName: String, with newPortion: String) -> NSObject {
        guard var items = favoriteMeal.items as? [[String: Any]] else { return (favoriteMeal.items ?? "" as NSObject) as NSObject }
        for i in 0..<items.count {
            if items[i]["name"] as? String == itemName {
                items[i]["portionServed"] = newPortion
                break
            }
        }
        return items as NSObject
    }

    private func addDoneButtonOnKeyboard(to textField: UITextField) {
        let doneToolbar: UIToolbar = UIToolbar()
        doneToolbar.sizeToFit()
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneEditingTextField))
        
        let items = [flexSpace, done]
        doneToolbar.items = items
        doneToolbar.barStyle = .default
        
        textField.inputAccessoryView = doneToolbar
    }
    
    @objc private func doneEditingTextField() {
        view.endEditing(true)
    }
}
