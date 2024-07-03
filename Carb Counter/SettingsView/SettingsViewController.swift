import UIKit

class SettingsViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inställningar"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "switchCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "valueCell")
        
        let cancelButton = UIBarButtonItem(title: "Stäng", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = cancelButton
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
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 4
        case 1:
            return 8 // Increased to accommodate the new rows
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.accessoryType = .disclosureIndicator
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Carb Ratio schema"
            case 1:
                cell.textLabel?.text = "Startdoser schema"
            case 2:
                cell.textLabel?.text = "Dela data"
            case 3:
                cell.textLabel?.text = "Remote inställningar"
            default:
                break
            }
            return cell
        } else {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "valueCell")
            switch indexPath.row {
            case 0:
                let toggleSwitch = UISwitch()
                cell.textLabel?.text = "Manuellt läge"
                toggleSwitch.isOn = !UserDefaultsRepository.allowShortcuts
                toggleSwitch.addTarget(self, action: #selector(shortcutsSwitchChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggleSwitch
            case 1:
                let toggleSwitch = UISwitch()
                cell.textLabel?.text = "Tillåt datarensning"
                toggleSwitch.isOn = UserDefaultsRepository.allowDataClearing
                toggleSwitch.addTarget(self, action: #selector(dataClearingSwitchChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggleSwitch
            case 2:
                cell.textLabel?.text = "Maxgräns Kolhydrater"
                cell.detailTextLabel?.text = "\(formatValue(UserDefaultsRepository.maxCarbs)) g"
            case 3:
                cell.textLabel?.text = "Maxgräns Bolus"
                cell.detailTextLabel?.text = "\(formatValue(UserDefaultsRepository.maxBolus)) E"
            case 4:
                cell.textLabel?.text = "Sen Frukost-faktor"
                cell.detailTextLabel?.text = formatValue(UserDefaultsRepository.lateBreakfastFactor)
            case 5:
                cell.textLabel?.text = "Nightscout URL"
                cell.detailTextLabel?.text = UserDefaultsRepository.nightscoutURL
            case 6:
                cell.textLabel?.text = "Nightscout Token"
                cell.detailTextLabel?.text = maskText(UserDefaultsRepository.nightscoutToken)
            case 7:
                cell.textLabel?.text = "Dabas API Secret"
                cell.detailTextLabel?.text = maskText(UserDefaultsRepository.dabasAPISecret)
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
            case 2:
                title = "Maxgräns Kolhydrater (g)"
                message = "Ange maxgränsen för hur mkt kolhydrater som kan registreras vid ett och samma tillfälle. \n\nOm du försöker registrera en större mängd kolhydrater, kommer det värdet automatiskt att justeras ner till denna angivna maxinställning:"
                value = UserDefaultsRepository.maxCarbs
                userDefaultSetter = { UserDefaultsRepository.maxCarbs = $0 }
            case 3:
                title = "Maxgräns Bolus (E)"
                message = "Ange maxgränsen för hur mkt bolus som kan ges vid ett och samma tillfälle. \n\nOm du försöker ge en större bolus, kommer det värdet automatiskt att justeras ner till denna angivna maxinställning:"
                value = UserDefaultsRepository.maxBolus
                userDefaultSetter = { UserDefaultsRepository.maxBolus = $0 }
            case 4:
                title = "Sen Frukost-faktor"
                message = "När frukost äts senare än normalt, efter att de schemalagda insulinkvoterna växlat över från frukostkvoter till dagskvoter, så behöver kvoterna tillfälligt göras starkare. \n\nDenna inställning anger hur mycket den aktuella insulinkvoten ska justeras när knappen 'Sen frukost' aktiveras i måltidsvyn:"
                value = UserDefaultsRepository.lateBreakfastFactor
                userDefaultSetter = { UserDefaultsRepository.lateBreakfastFactor = $0 }
            case 5:
                title = "Nightscout URL"
                message = "Ange din Nightscout URL:"
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.nightscoutURL ?? "") { newValue in
                    UserDefaultsRepository.nightscoutURL = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 6:
                title = "Nightscout Token"
                message = "Ange din Nightscout Token:"
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.nightscoutToken ?? "") { newValue in
                    UserDefaultsRepository.nightscoutToken = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 7:
                title = "Dabas API Secret"
                message = "Ange din Dabas API Secret:"
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.dabasAPISecret) { newValue in
                    UserDefaultsRepository.dabasAPISecret = newValue
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
        UserDefaultsRepository.allowShortcuts = !sender.isOn
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
                        
