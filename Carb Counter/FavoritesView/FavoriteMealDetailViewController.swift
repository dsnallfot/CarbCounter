import UIKit
import CoreData

protocol FavoriteMealDetailViewControllerDelegate: AnyObject {
    func favoriteMealDetailViewControllerDidSave(_ controller: FavoriteMealDetailViewController)
}

class FavoriteMealDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    weak var delegate: FavoriteMealDetailViewControllerDelegate?
    
    var favoriteMeal: NewFavoriteMeals!
    var tableView: UITableView!
    var nameTextField: UITextField!
    
    var dataSharingVC: DataSharingViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Ändra favoritmåltid", comment: "Edit favorite meal")
        view.backgroundColor = .systemBackground
        updateBackgroundForCurrentMode()
        
        setupView()
        setupNavigationBar()
        setupCloseButton()
        
        dataSharingVC = DataSharingViewController()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackgroundForCurrentMode()
        }
    }

    private func updateBackgroundForCurrentMode() {
        view.subviews.filter { $0 is GradientView }.forEach { $0.removeFromSuperview() }
        
        if traitCollection.userInterfaceStyle == .dark {
            let colors: [CGColor] = [
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor
            ]
            let gradientView = GradientView(colors: colors)
            gradientView.translatesAutoresizingMaskIntoConstraints = false

            view.addSubview(gradientView)
            view.sendSubviewToBack(gradientView)

            NSLayoutConstraint.activate([
                gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                gradientView.topAnchor.constraint(equalTo: view.topAnchor),
                gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        } else {
            view.backgroundColor = .systemGray6
        }
    }
    
    private func setupView() {
        nameTextField = UITextField()
        nameTextField.text = favoriteMeal.name
        nameTextField.font = UIFont.systemFont(ofSize: 20)
        nameTextField.borderStyle = .roundedRect
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.autocorrectionType = .no
        nameTextField.spellCheckingType = .no
        nameTextField.backgroundColor = .systemGray2.withAlphaComponent(0.2)
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
        favoriteMeal.lastEdited = Date()
        CoreDataStack.shared.saveContext()
        
        guard let dataSharingVC = self.dataSharingVC else {
            dismiss(animated: true, completion: nil)
            return
        }
        
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
        let done = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Done"), style: .done, target: self, action: #selector(doneButtonAction))
        
        doneToolbar.items = [flexSpace, done]
        doneToolbar.barStyle = .default
        
        nameTextField.inputAccessoryView = doneToolbar
    }
    
    @objc private func doneButtonAction() {
        nameTextField.resignFirstResponder()
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return favoriteMeal.favoriteEntries?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        cell.backgroundColor = .clear
        
        if let itemsSet = favoriteMeal.favoriteEntries as? Set<FoodItemFavorite> {
            let items = Array(itemsSet).sorted { $0.name ?? "" < $1.name ?? "" }
            let item = items[indexPath.row]
            
            cell.textLabel?.text = item.name
            
            let portionServed = item.portionServed
            let perPiece = item.perPiece

            let formattedPortion: String
            if portionServed.truncatingRemainder(dividingBy: 1) == 0 {
                formattedPortion = String(format: "%.0f", portionServed)
            } else {
                formattedPortion = String(format: "%.1f", portionServed)
            }
            
            if perPiece {
                cell.detailTextLabel?.text = String(format: NSLocalizedString("Mängd: %@ st", comment: "Amount: %@ pieces"), formattedPortion)
            } else {
                cell.detailTextLabel?.text = String(format: NSLocalizedString("Mängd: %@ g", comment: "Amount: %@ grams"), formattedPortion)
            }

            cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            cell.detailTextLabel?.textColor = .gray

            let customSelectionColor = UIView()
            customSelectionColor.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            cell.selectedBackgroundView = customSelectionColor
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let itemsSet = favoriteMeal.favoriteEntries as? Set<FoodItemFavorite> else { return }
        let items = Array(itemsSet).sorted { $0.name ?? "" < $1.name ?? "" }
        let item = items[indexPath.row]
        
        let editAlert = UIAlertController(title: NSLocalizedString("Ändra mängd", comment: "Edit amount"), message: String(format: NSLocalizedString("Ange en ny mängd för %@:", comment: "Enter a new amount for %@:"), item.name ?? ""), preferredStyle: .alert)
        editAlert.addTextField { textField in
            let portionServed = item.portionServed
            if portionServed.truncatingRemainder(dividingBy: 1) == 0 {
                textField.text = String(format: "%.0f", portionServed)
            } else {
                textField.text = String(format: "%.1f", portionServed)
            }
            
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            self.addDoneButtonOnKeyboard(to: textField)
        }
        let saveAction = UIAlertAction(title: NSLocalizedString("Spara", comment: "Save"), style: .default) { [weak self] _ in
            guard let self = self,
                  let newPortionText = editAlert.textFields?.first?.text,
                  let newPortion = Double(newPortionText) else { return }
            
            item.portionServed = newPortion
            self.favoriteMeal.lastEdited = Date()
            CoreDataStack.shared.saveContext()
            
            guard let dataSharingVC = self.dataSharingVC else { return }
            
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
    
    private func addDoneButtonOnKeyboard(to textField: UITextField) {
        let doneToolbar: UIToolbar = UIToolbar()
        doneToolbar.sizeToFit()
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Done"), style: .done, target: self, action: #selector(doneEditingTextField))
        
        doneToolbar.items = [flexSpace, done]
        doneToolbar.barStyle = .default
        textField.inputAccessoryView = doneToolbar
    }
    
    @objc private func doneEditingTextField() {
        view.endEditing(true)
    }
}
