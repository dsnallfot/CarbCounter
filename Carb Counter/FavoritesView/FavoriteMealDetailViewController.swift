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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ändra favoritmåltid"
        
        view.backgroundColor = .systemBackground
        
        setupView()
        setupNavigationBar()
        tableView.reloadData()
    }
    
    private func setupView() {
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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = .systemBackground
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
            appearance.backgroundColor = .systemBackground
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        } else {
            navigationController?.navigationBar.barTintColor = .systemBackground
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.label]
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Spara", style: .done, target: self, action: #selector(saveChanges))
    }
    
    @objc private func saveChanges() {
        favoriteMeal.name = nameTextField.text
        
        CoreDataStack.shared.saveContext()
        
        delegate?.favoriteMealDetailViewControllerDidSave(self)
        
        navigationController?.popViewController(animated: true)
    }
    
    private func addDoneButtonOnKeyboard() {
        let doneToolbar: UIToolbar = UIToolbar()
        doneToolbar.sizeToFit()
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonAction))
        
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
                cell.detailTextLabel?.text = "Mängd: \(formattedPortion) st"
            } else {
                cell.detailTextLabel?.text = "Mängd: \(formattedPortion) g"
            }
        } else {
            if let perPiece = item["perPiece"] as? Bool, perPiece {
                cell.detailTextLabel?.text = "Mängd: \(item["portionServed"] as? String ?? "") st"
            } else {
                cell.detailTextLabel?.text = "Mängd: \(item["portionServed"] as? String ?? "") g"
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
        
        let editAlert = UIAlertController(title: "Ändra mängd", message: "Ange en ny mängd för \(item["name"] as? String ?? ""):", preferredStyle: .alert)
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
        let saveAction = UIAlertAction(title: "Spara", style: .default) { [weak self] _ in
            guard let self = self, let newPortion = editAlert.textFields?.first?.text else { return }
            items[indexPath.row]["portionServed"] = newPortion
            self.favoriteMeal.items = self.updateItems(items: items)
            
            CoreDataStack.shared.saveContext()
            self.tableView.reloadData()
        }
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        
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
        let done: UIBarButtonItem = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneEditingTextField))
        
        let items = [flexSpace, done]
        doneToolbar.items = items
        doneToolbar.barStyle = .default
        textField.inputAccessoryView = doneToolbar
    }
    
    @objc private func doneEditingTextField() {
        view.endEditing(true)
    }
}
