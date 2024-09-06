import UIKit

class SettingsViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateToggleStates), name: .didImportUserDefaults, object: nil)
        
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeView))
        navigationItem.leftBarButtonItem = closeButton
    }
    
    private func setupView() {
        tableView.backgroundColor = .clear
        let solidBackgroundView = UIView()
        solidBackgroundView.backgroundColor = .systemBackground
        solidBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        let colors: [CGColor] = [
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        ]
        let gradientView = GradientView(colors: colors)
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        
        let backgroundContainerView = UIView()
        backgroundContainerView.addSubview(solidBackgroundView)
        backgroundContainerView.addSubview(gradientView)
        tableView.backgroundView = backgroundContainerView
        
        NSLayoutConstraint.activate([
            solidBackgroundView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
            solidBackgroundView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
            solidBackgroundView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
            solidBackgroundView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
        ])
        
        NSLayoutConstraint.activate([
            gradientView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
        ])
        
        title = NSLocalizedString("Inställningar", comment: "Title for Settings screen")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "switchCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "valueCell")
    }
    
    @objc private func updateToggleStates() {
        for subview in view.subviews {
            subview.removeFromSuperview()
        }
        setupView()
        tableView.reloadData()
    }
    
    @objc private func closeView() {
        dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let backButton = UIBarButtonItem()
        backButton.title = NSLocalizedString("Tillbaka", comment: "Back button title")
        navigationItem.backBarButtonItem = backButton
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .didImportUserDefaults, object: nil)
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func useStartDosePercentageSegmentChanged(_ sender: UISegmentedControl) {
        let isOn = sender.selectedSegmentIndex == 1
        UserDefaultsRepository.useStartDosePercentage = isOn
    }
    
    @objc private func unitsSegmentChanged(_ sender: UISegmentedControl) {
        let isOn = sender.selectedSegmentIndex == 1
        UserDefaultsRepository.useMmol = isOn
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 4
        case 1:
            return 15
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
                cell.textLabel?.text = NSLocalizedString("Carb Ratio schema", comment: "Carb ratio schema label")
            case 1:
                cell.textLabel?.text = NSLocalizedString("Startdoser schema", comment: "Start doses schema label")
            case 2:
                cell.textLabel?.text = NSLocalizedString("Dela data", comment: "Share data label")
            case 3:
                cell.textLabel?.text = NSLocalizedString("Fjärrstyrning", comment: "Remote control label")
            default:
                break
            }
            return cell
        } else {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "valueCell")
            cell.backgroundColor = .clear
            
            switch indexPath.row {
            case 0:
                let toggleSwitch = UISwitch()
                cell.textLabel?.text = NSLocalizedString("Tillåt fjärrstyrning", comment: "Allow remote control label")
                toggleSwitch.isOn = UserDefaultsRepository.allowShortcuts
                toggleSwitch.addTarget(self, action: #selector(shortcutsSwitchChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggleSwitch
                
                // Add gesture recognizer for the label
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(remoteControlLabelTapped))
                cell.textLabel?.isUserInteractionEnabled = true
                cell.textLabel?.addGestureRecognizer(tapGesture)
                
            case 1:
                let toggleSwitch = UISwitch()
                cell.textLabel?.text = NSLocalizedString("Tillåt datarensning", comment: "Allow data clearing label")
                toggleSwitch.isOn = UserDefaultsRepository.allowDataClearing
                toggleSwitch.addTarget(self, action: #selector(dataClearingSwitchChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggleSwitch
                
                // Add gesture recognizer for the label
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dataClearingLabelTapped))
                cell.textLabel?.isUserInteractionEnabled = true
                cell.textLabel?.addGestureRecognizer(tapGesture)
                
            case 2:
                let segmentedControl = UISegmentedControl(items: [NSLocalizedString("Schema", comment: "Schedule label"), NSLocalizedString("Fraktion", comment: "Fraction label")])
                segmentedControl.selectedSegmentIndex = UserDefaultsRepository.useStartDosePercentage ? 1 : 0
                segmentedControl.addTarget(self, action: #selector(useStartDosePercentageSegmentChanged(_:)), for: .valueChanged)
                cell.textLabel?.text = NSLocalizedString("Startdoser", comment: "Start doses label")
                cell.accessoryView = segmentedControl
            case 3:
                cell.textLabel?.text = NSLocalizedString("Startdos Fraktion", comment: "Start dose fraction label")
                cell.detailTextLabel?.text = formatValue(UserDefaultsRepository.startDoseFactor)
            case 4:
                cell.textLabel?.text = NSLocalizedString("Maxgräns Kolhydrater", comment: "Max carbs limit label")
                cell.detailTextLabel?.text = "\(formatValue(UserDefaultsRepository.maxCarbs)) g"
            case 5:
                cell.textLabel?.text = NSLocalizedString("Maxgräns Bolus", comment: "Max bolus limit label")
                cell.detailTextLabel?.text = "\(formatValue(UserDefaultsRepository.maxBolus)) E"
            case 6:
                cell.textLabel?.text = NSLocalizedString("Override-faktor", comment: "Override factor label")
                cell.detailTextLabel?.text = formatValue(UserDefaultsRepository.lateBreakfastFactor)
            case 7:
                cell.textLabel?.text = NSLocalizedString("Override", comment: "Override label")
                cell.detailTextLabel?.text = UserDefaultsRepository.lateBreakfastOverrideName
            case 8:
                let segmentedControl = UISegmentedControl(items: [NSLocalizedString("mg/dl", comment: "mg/dl"), NSLocalizedString("mmol", comment: "mmol")])
                segmentedControl.selectedSegmentIndex = UserDefaultsRepository.useMmol ? 1 : 0
                segmentedControl.addTarget(self, action: #selector(unitsSegmentChanged(_:)), for: .valueChanged)
                cell.textLabel?.text = NSLocalizedString("Blodsocker enhet", comment: "Blodsocker enhet")
                cell.accessoryView = segmentedControl
            case 9:
                cell.textLabel?.text = NSLocalizedString("Nightscout URL", comment: "Nightscout URL label")
                cell.detailTextLabel?.text = UserDefaultsRepository.nightscoutURL
            case 10:
                cell.textLabel?.text = NSLocalizedString("Nightscout Token", comment: "Nightscout Token label")
                cell.detailTextLabel?.text = maskText(UserDefaultsRepository.nightscoutToken)
            case 11:
                cell.textLabel?.text = NSLocalizedString("Dabas API Secret", comment: "Dabas API Secret label")
                cell.detailTextLabel?.text = maskText(UserDefaultsRepository.dabasAPISecret)
            case 12:
                cell.textLabel?.text = NSLocalizedString("Skolmaten URL", comment: "School food URL label")
                cell.detailTextLabel?.text = UserDefaultsRepository.schoolFoodURL
            case 13:
                cell.textLabel?.text = NSLocalizedString("Exkludera sökord", comment: "Exkludera sökord")
                cell.detailTextLabel?.text = UserDefaultsRepository.excludeWords
            case 14:
                cell.textLabel?.text = NSLocalizedString("Lägg till top-ups", comment: "Lägg till top-ups")
                cell.detailTextLabel?.text = UserDefaultsRepository.topUps
            default:
                break
            }
            return cell
        }
    }
    
    @objc private func remoteControlLabelTapped() {
        let title = NSLocalizedString("Tillåt fjärrstyrning", comment: "Allow remote control title")
        let message = NSLocalizedString("Välj att tillåta fjärrstyrning om du vill kunna skicka måltidskommandon via iOS genvägar eller Twilio SMS direkt från Carb Counter till iAPS/Trio på din egen eller en annan iPhone.\n\nOm 'Tillåt fjärrstyrning' är av, så måste du manuellt registrera kolhydrater, fett, protein och insulin i iAPS/Trio.", comment: "Remote control tooltip message")
        
        showTooltipAlert(title: title, message: message)
    }

    @objc private func dataClearingLabelTapped() {
        let title = NSLocalizedString("Tillåt datarensning", comment: "Allow data clearing title")
        let message = NSLocalizedString("Aktivera denna inställning om/när du vill kunna radera all data avseende livsmedel, carb ratios och startdoser.\n\nNär inställningen är aktiverad dyker 'Rensa'-knappar upp i navigationsfältet i respektive vy", comment: "Data clearing tooltip message")
        
        showTooltipAlert(title: title, message: message)
    }
    
    private func showTooltipAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK button title"), style: .default, handler: nil)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    private func maskText(_ text: String?) -> String {
        return text?.isEmpty == false ? String(repeating: "*", count: 20) : ""
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
                title = NSLocalizedString("Startdoser", comment: "Start doses label")
                message = NSLocalizedString("Välj om du vill vill använda schemalagda startdoser (Ställs in under 'Startdoser schema' ovan) eller om du vill använda 'Startdos Fraktion' (enligt inställningen nedan).", comment: "Startdos text")
                showSimpleAlert(title: title, message: message)
                return
            case 3:
                title = NSLocalizedString("Startdos Fraktion", comment: "Start dose fraction title")
                message = NSLocalizedString("Ange den fraktion av den totala mängden kolhydrater i måltiden som ska användas som startdos när Startdos 'Fraktion' är vald.\n\nExempel: Om måltiden innehåller 58 g kolhydrater och startdos fraktionen är inställd på 0.5, kommer startdosen att beräknas utifrån 29 g kolhydrater.", comment: "Start dose fraction message")
                value = UserDefaultsRepository.startDoseFactor
                userDefaultSetter = { UserDefaultsRepository.startDoseFactor = $0 }
            case 4:
                title = NSLocalizedString("Maxgräns Kolhydrater (g)", comment: "Max carbs limit title")
                message = NSLocalizedString("Ange maxgränsen för hur mkt kolhydrater som kan registreras vid ett och samma tillfälle. \n\nOm du försöker registrera en större mängd kolhydrater, kommer det värdet automatiskt att justeras ner till denna angivna maxinställning:", comment: "Max carbs limit message")
                value = UserDefaultsRepository.maxCarbs
                userDefaultSetter = { UserDefaultsRepository.maxCarbs = $0 }
            case 5:
                title = NSLocalizedString("Maxgräns Bolus (E)", comment: "Max bolus limit title")
                message = NSLocalizedString("Ange maxgränsen för hur mkt bolus som kan ges vid ett och samma tillfälle. \n\nOm du försöker ge en större bolus, kommer det värdet automatiskt att justeras ner till denna angivna maxinställning:", comment: "Max bolus limit message")
                value = UserDefaultsRepository.maxBolus
                userDefaultSetter = { UserDefaultsRepository.maxBolus = $0 }
            case 6:
                title = NSLocalizedString("Override-faktor", comment: "Override factor title")
                message = NSLocalizedString("När exvis frukost äts senare än normalt, efter att de schemalagda insulinkvoterna växlat över från frukostkvoter till dagskvoter, så behöver kvoterna tillfälligt göras starkare. \n\nDenna inställning anger hur mycket den aktuella insulinkvoten ska justeras när knappen 'Override' aktiveras i måltidsvyn:", comment: "Override factor message")
                value = UserDefaultsRepository.lateBreakfastFactor
                userDefaultSetter = { UserDefaultsRepository.lateBreakfastFactor = $0 }
            case 7:
                title = NSLocalizedString("Override namn", comment: "Override name title")
                message = NSLocalizedString("Ange exakt namn på den override du vill aktivera i iAPS/Trio", comment: "Override name message")
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.lateBreakfastOverrideName ?? "") { newValue in
                    UserDefaultsRepository.lateBreakfastOverrideName = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 8:
                title = NSLocalizedString("Blodsocker enhet", comment: "Blodsocker enhet")
                message = NSLocalizedString("Välj om du vill vill använda mmol eller mg/dl som enhet för blodsockervärden i appen", comment: "Blodsocker enhet text")
                showSimpleAlert(title: title, message: message)
                return
            case 9:
                title = NSLocalizedString("Nightscout URL", comment: "Nightscout URL title")
                message = NSLocalizedString("Ange din Nightscout URL:", comment: "Nightscout URL message")
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.nightscoutURL ?? "") { newValue in
                    UserDefaultsRepository.nightscoutURL = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 10:
                title = NSLocalizedString("Nightscout Token", comment: "Nightscout Token title")
                message = NSLocalizedString("Ange din Nightscout Token:", comment: "Nightscout Token message")
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.nightscoutToken ?? "") { newValue in
                    UserDefaultsRepository.nightscoutToken = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 11:
                title = NSLocalizedString("Dabas API Secret", comment: "Dabas API Secret title")
                message = NSLocalizedString("Om du vill använda den svenska livsmedelsdatabasen Dabas, ange din API Secret.\n\nOm du inte anger ngn API secret används OpenFoodFacts som default för EAN-scanning och livsmedelssökningar online", comment: "Dabas API Secret message")
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.dabasAPISecret) { newValue in
                    UserDefaultsRepository.dabasAPISecret = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 12:
                title = NSLocalizedString("Skolmaten URL", comment: "School food URL title")
                message = NSLocalizedString("Ange URL till Skolmaten.se RSS-flöde som du vill använda:", comment: "School food URL message")
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.schoolFoodURL ?? "") { newValue in
                    UserDefaultsRepository.schoolFoodURL = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 13:
                title = NSLocalizedString("Exkludera sökord", comment: "Exkludera sökord")
                message = NSLocalizedString("För att förbättra matchningen mellan lunchmenyerna i skolmaten.se och appens livsmedelsdatabas, så kan du välja att exkludera vissa sökord. Ange sökorden separerade med kommatecken", comment: "Exkludera sökord-text")
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.excludeWords ?? "") { newValue in
                    UserDefaultsRepository.excludeWords = newValue
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            case 14:
                title = NSLocalizedString("Lägg till top-ups", comment: "Lägg till top-ups")
                message = NSLocalizedString("Lägg till livsmedel som ofta används för att toppa up med kolhydrater när det ätits färre kolhydrater än vad insulin doserats för. Separera livsmedlen med kommatecken", comment: "Lägg till top-ups-text")
                showEditAlert(title: title, message: message, currentValue: UserDefaultsRepository.topUps ?? "") { newValue in
                    UserDefaultsRepository.topUps = newValue
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
            
            let saveAction = UIAlertAction(title: NSLocalizedString("Spara", comment: "Save button title"), style: .default) { _ in
                if let text = alert.textFields?.first?.text?.replacingOccurrences(of: ",", with: "."),
                   let newValue = Double(text) {
                    userDefaultSetter?(newValue)
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
            }
            let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel button title"), style: .cancel, handler: nil)
            
            alert.addAction(saveAction)
            alert.addAction(cancelAction)
            
            present(alert, animated: true, completion: nil)
        }
    }
    
    private func showSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK button title"), style: .default, handler: nil)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    private func showEditAlert(title: String, message: String, currentValue: String, completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = currentValue
        }
        let saveAction = UIAlertAction(title: NSLocalizedString("Spara", comment: "Save button title"), style: .default) { _ in
            if let text = alert.textFields?.first?.text {
                completion(text)
            }
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel button title"), style: .cancel, handler: nil)
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
