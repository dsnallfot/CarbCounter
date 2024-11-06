//
//  ConnectionsViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-05.
//

import UIKit

class ConnectionsViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Anslutningar", comment: "Title for Connections screen")
        setupView()
        
        // Register cell with .value1 style to enable trailing-aligned detailTextLabel
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "valueCell")
    }
    
    private func setupView() {
        tableView.backgroundColor = .clear
        let solidBackgroundView = UIView()
        solidBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        if traitCollection.userInterfaceStyle == .dark {
            solidBackgroundView.backgroundColor = .systemBackground
        } else {
            solidBackgroundView.backgroundColor = .systemGray6
        }

        let colors: [CGColor] = [
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        ]
        let gradientView = GradientView(colors: colors)
        gradientView.translatesAutoresizingMaskIntoConstraints = false

        let backgroundContainerView = UIView()
        backgroundContainerView.addSubview(solidBackgroundView)
        
        if traitCollection.userInterfaceStyle == .dark {
            backgroundContainerView.addSubview(gradientView)
        }

        tableView.backgroundView = backgroundContainerView

        NSLayoutConstraint.activate([
            solidBackgroundView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
            solidBackgroundView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
            solidBackgroundView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
            solidBackgroundView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
        ])

        if traitCollection.userInterfaceStyle == .dark {
            NSLayoutConstraint.activate([
                gradientView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
                gradientView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
                gradientView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
                gradientView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
            ])
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 6 // For cases 9 to 14
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Create a cell with .value1 style
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "valueCell")
        cell.backgroundColor = .clear
        cell.accessoryType = .none

        switch indexPath.row {
        case 0:
            cell.textLabel?.text = NSLocalizedString("Nightscout URL", comment: "Nightscout URL label")
            cell.detailTextLabel?.text = UserDefaultsRepository.nightscoutURL
        case 1:
            cell.textLabel?.text = NSLocalizedString("Nightscout Token", comment: "Nightscout Token label")
            cell.detailTextLabel?.text = maskText(UserDefaultsRepository.nightscoutToken)
        case 2:
            cell.textLabel?.text = NSLocalizedString("Dabas API Secret", comment: "Dabas API Secret label")
            cell.detailTextLabel?.text = maskText(UserDefaultsRepository.dabasAPISecret)
        case 3:
            cell.textLabel?.text = NSLocalizedString("Skolmaten URL", comment: "School food URL label")
            cell.detailTextLabel?.text = UserDefaultsRepository.schoolFoodURL
        case 4:
            cell.textLabel?.text = NSLocalizedString("Exkludera sökord", comment: "Exclude keywords")
            cell.detailTextLabel?.text = UserDefaultsRepository.excludeWords
        case 5:
            cell.textLabel?.text = NSLocalizedString("Lägg till top-ups", comment: "Add top-ups")
            cell.detailTextLabel?.text = UserDefaultsRepository.topUps
        default:
            break
        }
        
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        var title = ""
        var message = ""
        var currentValue = ""
        var saveAction: ((String) -> Void)?

        switch indexPath.row {
        case 0:
            title = NSLocalizedString("Nightscout URL", comment: "Nightscout URL title")
            message = NSLocalizedString("Ange din Nightscout URL:", comment: "Nightscout URL message")
            currentValue = UserDefaultsRepository.nightscoutURL ?? ""
            saveAction = { newValue in UserDefaultsRepository.nightscoutURL = newValue }
            
        case 1:
            title = NSLocalizedString("Nightscout Token", comment: "Nightscout Token title")
            message = NSLocalizedString("Ange din Nightscout Token:", comment: "Nightscout Token message")
            currentValue = UserDefaultsRepository.nightscoutToken ?? ""
            saveAction = { newValue in UserDefaultsRepository.nightscoutToken = newValue }
            
        case 2:
            title = NSLocalizedString("Dabas API Secret", comment: "Dabas API Secret title")
            message = NSLocalizedString("Ange din Dabas API Secret:", comment: "Dabas API Secret message")
            currentValue = UserDefaultsRepository.dabasAPISecret ?? ""
            saveAction = { newValue in UserDefaultsRepository.dabasAPISecret = newValue }
            
        case 3:
            title = NSLocalizedString("Skolmaten URL", comment: "School food URL title")
            message = NSLocalizedString("Ange URL till Skolmaten.se RSS-flöde:", comment: "School food URL message")
            currentValue = UserDefaultsRepository.schoolFoodURL ?? ""
            saveAction = { newValue in UserDefaultsRepository.schoolFoodURL = newValue }
            
        case 4:
            title = NSLocalizedString("Exkludera sökord", comment: "Exclude keywords title")
            message = NSLocalizedString("Ange sökord att exkludera, separerade med komma:", comment: "Exclude keywords message")
            currentValue = UserDefaultsRepository.excludeWords ?? ""
            saveAction = { newValue in UserDefaultsRepository.excludeWords = newValue }
            
        case 5:
            title = NSLocalizedString("Lägg till top-ups", comment: "Add top-ups title")
            message = NSLocalizedString("Ange top-ups, separerade med komma:", comment: "Add top-ups message")
            currentValue = UserDefaultsRepository.topUps ?? ""
            saveAction = { newValue in UserDefaultsRepository.topUps = newValue }
            
        default:
            return
        }

        showEditAlert(title: title, message: message, currentValue: currentValue, saveAction: saveAction ?? { _ in })
    }

    private func showEditAlert(title: String, message: String, currentValue: String, saveAction: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = currentValue
        }
        let saveAction = UIAlertAction(title: NSLocalizedString("Spara", comment: "Save button title"), style: .default) { _ in
            if let text = alert.textFields?.first?.text {
                saveAction(text)
                self.tableView.reloadData()
            }
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel button title"), style: .cancel, handler: nil)
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    private func maskText(_ text: String?) -> String {
        return text?.isEmpty == false ? String(repeating: "*", count: 20) : ""
    }
}