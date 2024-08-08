import UIKit

class SettingsViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .clear // Make sure the table view itself is clear
                
                // Create the solid background view
                let solidBackgroundView = UIView()
                solidBackgroundView.backgroundColor = .systemBackground
                solidBackgroundView.translatesAutoresizingMaskIntoConstraints = false
                
                // Create the gradient view
                let colors: [CGColor] = [
                    UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
                    UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
                    UIColor.systemBlue.withAlphaComponent(0.15).cgColor
                ]
                let gradientView = GradientView(colors: colors)
                gradientView.translatesAutoresizingMaskIntoConstraints = false
                
                // Add the solid background view and gradient view as the table view's background view
                let backgroundContainerView = UIView()
                backgroundContainerView.addSubview(solidBackgroundView)
                backgroundContainerView.addSubview(gradientView)
                tableView.backgroundView = backgroundContainerView
                
                // Set up constraints for the solid background view
                NSLayoutConstraint.activate([
                    solidBackgroundView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
                    solidBackgroundView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
                    solidBackgroundView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
                    solidBackgroundView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
                ])
                
                // Set up constraints for the gradient view
                NSLayoutConstraint.activate([
                    gradientView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
                    gradientView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
                    gradientView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
                    gradientView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
                ])
        title = "Inställningar"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "switchCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "valueCell")


        
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeView))
        navigationItem.leftBarButtonItem = closeButton
    }
    
    @objc private func closeView() {
        dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set the back button title for the next view controller
        let backButton = UIBarButtonItem()
        backButton.title = "Tillbaka"
        navigationItem.backBarButtonItem = backButton
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func useStartDosePercentageSegmentChanged(_ sender: UISegmentedControl) {
        let isOn = sender.selectedSegmentIndex == 1
        UserDefaultsRepository.useStartDosePercentage = isOn
        // Add any additional handling needed when the value changes
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 4
        case 1:
            return 12 // Increased to accommodate the new rows
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.accessoryType = .disclosureIndicator
            cell.backgroundColor = .clear
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Carb Ratio schema"
            case 1:
                cell.textLabel?.text = "Startdoser schema"
            case 2:
                cell.textLabel?.text = "Dela data"
            case 3:
                cell.textLabel?.text = "Fjärrstyrning"
            default:
                break
            }
            return cell
        } else {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "valueCell")
            switch indexPath.row {
            case 0:
                let toggleSwitch = UISwitch()
                cell.textLabel?.text = "Tillåt fjärrstyrning"
                toggleSwitch.isOn = UserDefaultsRepository.allowShortcuts
                toggleSwitch.addTarget(self, action: #selector(shortcutsSwitchChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggleSwitch
                cell.backgroundColor = .clear
            case 1:
                let toggleSwitch = UISwitch()
                cell.textLabel?.text = "Tillåt datarensning"
                toggleSwitch.isOn = UserDefaultsRepository.allowDataClearing
                toggleSwitch.addTarget(self, action: #selector(dataClearingSwitchChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggleSwitch
                cell.backgroundColor = .clear
            case 2:
                // Define the segmented control and set its properties
                let segmentedControl = UISegmentedControl(items: ["Schema", "Fraktion"])
                segmentedControl.selectedSegmentIndex = UserDefaultsRepository.useStartDosePercentage ? 1 : 0
                segmentedControl.addTarget(self, action: #selector(useStartDosePercentageSegmentChanged(_:)), for: .valueChanged)

                // Configure the cell
                cell.textLabel?.text = "Startdoser"
                cell.accessoryView = segmentedControl
                cell.backgroundColor = .clear

            case 3:
                cell.textLabel?.text = "Startdos Fraktion"
                cell.detailTextLabel?.text = formatValue(UserDefaultsRepository.startDoseFactor)
                cell.backgroundColor = .clear
            case 4:
                cell.textLabel?.text = "Maxgräns Kolhydrater"
                cell.detailTextLabel?.text = "\(formatValue(UserDefaultsRepository.maxCarbs)) g"
                cell.backgroundColor = .clear
            case 5:
                cell.textLabel?.text = "Maxgräns Bolus"
                cell.detailTextLabel?.text = "\(formatValue(UserDefaultsRepository.maxBolus)) E"
                cell.backgroundColor = .clear
            case 6:
                cell.textLabel?.text = "Override-faktor"
                cell.detailTextLabel?.text = formatValue(UserDefaultsRepository.lateBreakfastFactor)
                cell.backgroundColor = .clear
            case 7:
                cell.textLabel?.text = "Override"
                cell.detailTextLabel?.text = UserDefaultsRepository.lateBreakfastOverrideName
                cell.backgroundColor = .clear
            case 8:
                cell.textLabel?.text = "Nightscout URL"
                cell.detailTextLabel?.text = UserDefaultsRepository.nightscoutURL
                cell.backgroundColor = .clear
            case 9:
                cell.textLabel?.text = "Nightscout Token"
                cell.detailTextLabel?.text = maskText(UserDefaultsRepository.nightscoutToken)
                cell.backgroundColor = .clear
            case 10:
                cell.textLabel?.text = "Dabas API Secret"
                cell.detailTextLabel?.text = maskText(UserDefaultsRepository.dabasAPISecret)
                cell.backgroundColor = .clear
            case 11:
                cell.textLabel?.text = "Skolmaten URL"
                cell.detailTextLabel?.text = UserDefaultsRepository.schoolFoodURL
                cell.backgroundColor = .clear
            default:
                break
            }
            return cell
        }
    }

    private func maskText(_ text: String?) -> String {
        return text?.isEmpty == false ? String(repeating: "*", count: 20) : "" //text!.count) : ""
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let viewController: UIViewController
            switch indexPath.row {
            case 0:
                viewController = CarbRatioViewController()
            case 1:
                viewController = StartDoseViewController()
            case 2:
                viewController = DataSharingViewController()
            case 3:
                viewController = RemoteSettingsViewController()
            default:
                return
            }
            navigationController?.pushViewController(viewController, animated: true)
        } else if indexPath.section == 1, indexPath.row >= 2 {
            var title = ""
            var message = ""
            var value: Double = 0.0
            var userDefaultSetter: ((Double) -> Void)?
            
            switch indexPath.row {
            case 3:
                title = "Startdos Fraktion"
                message = "Ange den fraktion av den totala mängden kolhydrater i måltiden som ska användas som startdos när Startdos 'Fraktion' är vald.\n\nExempel: Om måltiden innehåller 58 g kolhydrater och startdos fraktionen är inställd på 0.5, kommer startdosen att beräknas utifrån 29 g kolhydrater."
                value = UserDefaultsRepository.startDoseFactor
                userDefaultSetter = { UserDefaultsRepository.startDoseFactor = $0 }
            case 4:
                title = "Maxgräns Kolhydrater (g)"
                message = "Ange maxgränsen för hur mkt kolhydrater som kan registreras vid ett och samma tillfälle. \n\nOm du försöker registrera en större mängd kolhydrater, kommer det värdet automatiskt att justeras ner till denna angivna maxinställning:"
                value = UserDefaultsRepository.maxCarbs
                userDefaultSetter = { UserDefaultsRepository.maxCarbs = $0 }
            case 5:
                title = "Maxgräns Bolus (E)"
                message = "Ange maxgränsen för hur mkt bolus som kan ges vid ett och samma tillfälle. \n\nOm du försöker ge en större bolus, kommer det värdet automatiskt att justeras ner till denna angivna maxinställning:"
                value = UserDefaultsRepository.maxBolus
                userDefaultSetter = { UserDefaultsRepository.maxBolus = $0 }
            case 6:
                title = "Override-faktor"
                message = "När exvis frukost äts senare än normalt, efter att de schemalagda insulinkvoterna växlat över från frukostkvoter till dagskvoter, så behöver kvoterna tillfälligt göras starkare. \n\nDenna inställning anger hur mycket den aktuella insulinkvoten ska justeras när knappen 'Override' aktiveras i måltidsvyn:"
                value = UserDefaultsRepository.lateBreakfastFactor
                userDefaultSetter = { UserDefaultsRepository.lateBreakfastFactor = $0 }
            case 7:
                title = "Override namn"
                message = "Ange exakt namn på den override du vill aktivera i iAPS/Trio"
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.lateBreakfastOverrideName ?? "") { newValue in
                    UserDefaultsRepository.lateBreakfastOverrideName = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 8:
                title = "Nightscout URL"
                message = "Ange din Nightscout URL:"
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.nightscoutURL ?? "") { newValue in
                    UserDefaultsRepository.nightscoutURL = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 9:
                title = "Nightscout Token"
                message = "Ange din Nightscout Token:"
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.nightscoutToken ?? "") { newValue in
                    UserDefaultsRepository.nightscoutToken = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 10:
                title = "Dabas API Secret"
                message = "Om du vill använda den svenska livsmedelsdatabasen Dabas, ange din API Secret.\n\nOm du inte anger ngn API secret används OpenFoodFacts som default för EAN-scanning och livsmedelssökningar online"
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.dabasAPISecret) { newValue in
                    UserDefaultsRepository.dabasAPISecret = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 11:
                title = "Skolmaten URL"
                message = "Ange URL till Skolmaten.se RSS-flöde som du vill använda:"
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.schoolFoodURL ?? "") { newValue in
                    UserDefaultsRepository.schoolFoodURL = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            default:
                return
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.keyboardType = .decimalPad
                textField.text = self.formatValue(value)
            }
            
            let saveAction = UIAlertAction(title: "Spara", style: .default) { _ in
                if let text = alert.textFields?.first?.text?.replacingOccurrences(of: ",", with: "."),
                   let newValue = Double(text) {
                    userDefaultSetter?(newValue)
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
            }
            let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
            
            alert.addAction(saveAction)
            alert.addAction(cancelAction)
            
            present(alert, animated: true, completion: nil)
        }
    }

    private func showEditAlert(title: String, message: String, currentValue: String, completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = currentValue
        }
        let saveAction = UIAlertAction(title: "Spara", style: .default) { _ in
            if let text = alert.textFields?.first?.text {
                completion(text)
            }
        }
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func shortcutsSwitchChanged(_ sender: UISwitch) {
        UserDefaultsRepository.allowShortcuts = sender.isOn
        NotificationCenter.default.post(name: Notification.Name("AllowShortcutsChanged"), object: nil)
    }
    
    @objc private func dataClearingSwitchChanged(_ sender: UISwitch) {
        UserDefaultsRepository.allowDataClearing = sender.isOn
        NotificationCenter.default.post(name: Notification.Name("AllowDataClearingChanged"), object: nil)
    }
    
    private func formatValue(_ value: Double) -> String {
        return value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.2f", value)
    }
}
                        
