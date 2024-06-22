//
//  SettingsViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-21.
//

import UIKit

class SettingsViewController: UITableViewController {
    
    private var allowShortcuts: Bool {
        get {
            if UserDefaults.standard.object(forKey: "allowShortcuts") == nil {
                UserDefaults.standard.set(false, forKey: "allowShortcuts")
            }
            return UserDefaults.standard.bool(forKey: "allowShortcuts")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "allowShortcuts")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inställningar"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "switchCell")
        
        // Add cancel button to the navigation bar
        let cancelButton = UIBarButtonItem(title: "Stäng", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = cancelButton
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 2 : 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            if indexPath.row == 0 {
                cell.textLabel?.text = "Carb Ratio Schema"
            } else {
                cell.textLabel?.text = "Startdoser Schema"
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath)
            cell.textLabel?.text = "Carb Counter används på en Loop-telefon"
            let toggleSwitch = UISwitch()
            toggleSwitch.isOn = allowShortcuts
            toggleSwitch.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
            cell.accessoryView = toggleSwitch
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else { return }
        let viewController: UIViewController
        if indexPath.row == 0 {
            viewController = CarbRatioViewController()
        } else {
            viewController = StartDoseViewController()
        }
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    @objc private func switchChanged(_ sender: UISwitch) {
        allowShortcuts = sender.isOn
        NotificationCenter.default.post(name: Notification.Name("AllowShortcutsChanged"), object: nil)
    }
}
