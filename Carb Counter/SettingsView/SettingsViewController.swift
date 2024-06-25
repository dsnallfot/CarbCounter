//
//  SettingsViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-21.
//

import UIKit

class SettingsViewController: UITableViewController, UITextFieldDelegate {
    private var shareURLTextField: UITextField!

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
            return 2
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath)
            let toggleSwitch = UISwitch()
            if indexPath.row == 0 {
                cell.textLabel?.text = "Tillåt automatiseringar"
                toggleSwitch.isOn = UserDefaultsRepository.allowShortcuts
                toggleSwitch.addTarget(self, action: #selector(shortcutsSwitchChanged(_:)), for: .valueChanged)
            } else {
                cell.textLabel?.text = "Tillåt datarensning"
                toggleSwitch.isOn = UserDefaultsRepository.allowDataClearing
                toggleSwitch.addTarget(self, action: #selector(dataClearingSwitchChanged(_:)), for: .valueChanged)
            }
            cell.accessoryView = toggleSwitch
            return cell
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

    @objc private func shortcutsSwitchChanged(_ sender: UISwitch) {
        UserDefaultsRepository.allowShortcuts = sender.isOn
        NotificationCenter.default.post(name: Notification.Name("AllowShortcutsChanged"), object: nil)
    }

    @objc private func dataClearingSwitchChanged(_ sender: UISwitch) {
        UserDefaultsRepository.allowDataClearing = sender.isOn
        NotificationCenter.default.post(name: Notification.Name("AllowDataClearingChanged"), object: nil)
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
}
