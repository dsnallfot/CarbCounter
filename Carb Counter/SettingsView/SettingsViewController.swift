import UIKit

class SettingsViewController: UITableViewController, UITextFieldDelegate {
    
    private var shareURLTextField: UITextField!
    private var maxCarbsTextField: UITextField!
    private var maxBolusTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inställningar"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "switchCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "buttonCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "textFieldCell")
        
        let cancelButton = UIBarButtonItem(title: "Stäng", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = cancelButton
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 4
        case 1:
            return 4 // Changed from 2 to 4 to include maxCarbs and maxBolus
        case 2:
            return 2
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Carb Ratio Schema"
            case 1:
                cell.textLabel?.text = "Startdoser Schema"
            case 2:
                cell.textLabel?.text = "CSV Import/Export"
            case 3:
                cell.textLabel?.text = "Remote Settings"
            default:
                break
            }
            return cell
        } else if indexPath.section == 1 {
            if indexPath.row < 2 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath)
                let toggleSwitch = UISwitch()
                // In the cellForRowAt indexPath method for the switch
                if indexPath.row == 0 {
                    cell.textLabel?.text = "Manuellt läge"
                    toggleSwitch.isOn = !UserDefaultsRepository.allowShortcuts // Set the switch to the inverse of allowShortcuts
                    toggleSwitch.addTarget(self, action: #selector(shortcutsSwitchChanged(_:)), for: .valueChanged)
                } else {
                    cell.textLabel?.text = "Tillåt datarensning"
                    toggleSwitch.isOn = UserDefaultsRepository.allowDataClearing
                    toggleSwitch.addTarget(self, action: #selector(dataClearingSwitchChanged(_:)), for: .valueChanged)
                }
                cell.accessoryView = toggleSwitch
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "textFieldCell", for: indexPath)
                
                let label = UILabel(frame: .zero)
                label.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(label)
                
                let textField = UITextField(frame: .zero)
                textField.keyboardType = .decimalPad
                textField.delegate = self
                textField.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(textField)
                
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 15),
                    label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    
                    textField.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -15),
                    textField.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    textField.widthAnchor.constraint(equalToConstant: 50),
                    label.trailingAnchor.constraint(lessThanOrEqualTo: textField.leadingAnchor, constant: -8)
                ])
                
                if indexPath.row == 2 {
                    label.text = "Max Kolhydrater"
                    maxCarbsTextField = textField
                    maxCarbsTextField.text = formatValue(UserDefaultsRepository.maxCarbs)
                } else {
                    label.text = "Max Bolus"
                    maxBolusTextField = textField
                    maxBolusTextField.text = formatValue(UserDefaultsRepository.maxBolus)
                }
                
                return cell
            }
        } else {
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "textFieldCell", for: indexPath)
                shareURLTextField = UITextField(frame: cell.contentView.bounds.insetBy(dx: 15, dy: 0))
                shareURLTextField.placeholder = "Ange URL för datadelning"
                shareURLTextField.autocapitalizationType = .none
                shareURLTextField.keyboardType = .URL
                shareURLTextField.delegate = self
                cell.contentView.addSubview(shareURLTextField)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell", for: indexPath)
                cell.textLabel?.text = "Acceptera datadelning"
                cell.textLabel?.textAlignment = .center
                return cell
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else {
            if indexPath.section == 2 && indexPath.row == 1 {
                acceptSharedData()
            }
            return
        }
        let viewController: UIViewController
        switch indexPath.row {
        case 0:
            viewController = CarbRatioViewController()
        case 1:
            viewController = StartDoseViewController()
        case 2:
            viewController = CSVImportExportViewController()
        case 3:
            viewController = RemoteSettingsViewController()
        default:
            return
        }
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    @objc private func shortcutsSwitchChanged(_ sender: UISwitch) {
        UserDefaultsRepository.allowShortcuts = !sender.isOn
        NotificationCenter.default.post(name: Notification.Name("AllowShortcutsChanged"), object: nil)
    }
    
    @objc private func dataClearingSwitchChanged(_ sender: UISwitch) {
        UserDefaultsRepository.allowDataClearing = sender.isOn
        NotificationCenter.default.post(name: Notification.Name("AllowDataClearingChanged"), object: nil)
    }
    
    private func acceptSharedData() {
        guard let shareURLString = shareURLTextField.text, !shareURLString.isEmpty, let shareURL = URL(string: shareURLString) else {
            showAlert(title: "Felaktig URL", message: "Vänligen ange en giltig delnings-URL.")
            return
        }
        CloudKitShareController.shared.acceptShare(from: shareURL) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showAlert(title: "Misslyckades att acceptera delning", message: "Error: \(error.localizedDescription)")
                } else {
                    self.showAlert(title: "Lyckades", message: "Delning av data accepterades.")
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    // Update UserDefaults when text fields end editing
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == maxCarbsTextField, let text = textField.text, let value = Double(text) {
            UserDefaultsRepository.maxCarbs = value
        } else if textField == maxBolusTextField, let text = textField.text, let value = Double(text) {
            UserDefaultsRepository.maxBolus = value
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        return value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}
