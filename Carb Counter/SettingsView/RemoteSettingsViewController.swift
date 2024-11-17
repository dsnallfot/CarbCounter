import UIKit

class RemoteSettingsViewController: UITableViewController {
    let sectionHeaders = [
        NSLocalizedString("SELECT REMOTE COMMANDS METHOD", comment: "SELECT REMOTE COMMANDS METHOD"),
        NSLocalizedString("REMOTE CONFIGURATION", comment: "REMOTE CONFIGURATION"),
        NSLocalizedString("TWILIO SETTINGS", comment: "TWILIO SETTINGS"),
        NSLocalizedString("APNS SETTINGS", comment: "APNS SETTINGS")
    ]
    let twilioSettings = [
        "Twilio SID", "Twilio Secret",
        NSLocalizedString("Twilio From #", comment: "Twilio From #"),
        NSLocalizedString("Twilio To #", comment: "Twilio To #")
    ]
    let remoteConfig = [
        NSLocalizedString("Entered By", comment: "Entered By"),
        NSLocalizedString("Secret Code", comment: "Secret Code")
    ]
    let apnsSettings = [
        NSLocalizedString("Shared Secret", comment: "Shared Secret"),
        NSLocalizedString("APNS Key ID", comment: "APNS Key ID"),
        NSLocalizedString("APNS Key", comment: "APNS Key")
    ]

    private var method: String {
        get {
            return UserDefaultsRepository.method
        }
        set {
            UserDefaultsRepository.method = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        //print("RemoteSettingsViewController - viewDidLoad")
        //print("Current sharedSecret value: \(Storage.shared.sharedSecret.value)")
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //print("RemoteSettingsViewController - viewWillAppear")
        //print("Current sharedSecret value before refresh: \(Storage.shared.sharedSecret.value)")
        refreshData()
        //print("Current sharedSecret value after refresh: \(Storage.shared.sharedSecret.value)")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UserDefaults.standard.synchronize()
        }
    
    private func refreshData() {
        let sharedSecret = Storage.shared.sharedSecret.value
        let apnsKey = Storage.shared.apnsKey.value
        let apnsKeyId = Storage.shared.keyId.value

        //print("Loaded Shared Secret from Storage.shared: \(sharedSecret)")
        //print("Loaded APNS Key: \(apnsKey)")
        //print("Loaded APNS Key ID: \(apnsKeyId)")

        tableView.reloadData()
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        let solidBackgroundView = UIView()
        solidBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        solidBackgroundView.backgroundColor = traitCollection.userInterfaceStyle == .dark ? .systemBackground : .systemGray6

        let gradientView = GradientView(colors: [
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        ])
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

        title = NSLocalizedString("Fjärrstyrning", comment: "Fjärrstyrning")
        tableView.register(CustomTableViewCell.self, forCellReuseIdentifier: "CustomCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SegmentedControlCell")
        tableView.tableFooterView = UIView()

        if !UserDefaultsRepository.allowShortcuts {
            method = "iOS Shortcuts"
        } else if method.isEmpty {
            method = "iOS Shortcuts"
        }

        let doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Klar"), style: .done, target: self, action: #selector(doneButtonTapped))
        navigationItem.rightBarButtonItem = doneButton
    }

    @objc private func doneButtonTapped() {
        navigationController?.popViewController(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionHeaders.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1 // Segmented control
        case 1:
            return remoteConfig.count
        case 2:
            return method == "SMS API" ? twilioSettings.count : 0
        case 3:
            return method == "Trio APNS" ? apnsSettings.count : 0
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 || (section == 2 && method != "SMS API") || (section == 3 && method != "Trio APNS") {
            return nil
        }
        return sectionHeaders[section]
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentedControlCell", for: indexPath)
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            
            // Remove separator lines for this cell
            cell.separatorInset = UIEdgeInsets(top: 0, left: UIScreen.main.bounds.width, bottom: 0, right: 0)
            
            let segmentedControl = UISegmentedControl(items: [
                NSLocalizedString("Välj genvägar", comment: "Använd genvägar"),
                NSLocalizedString("Välj Twilio", comment: "Använd Twilio SMS API"),
                NSLocalizedString("Välj APNS", comment: "Använd Trio APNS")
            ])
            segmentedControl.selectedSegmentIndex = (UserDefaultsRepository.allowShortcuts && method == "SMS API") ? 1 : (method == "Trio APNS") ? 2 : 0
            segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            
            cell.contentView.addSubview(segmentedControl)
            
            NSLayoutConstraint.activate([
                segmentedControl.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 15),
                segmentedControl.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -15),
                segmentedControl.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 5),
                segmentedControl.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -5),
            ])
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CustomCell", for: indexPath) as! CustomTableViewCell
            cell.selectionStyle = .none

            var settingName: String
            switch indexPath.section {
            case 1:
                settingName = remoteConfig[indexPath.row]
            case 2:
                settingName = twilioSettings[indexPath.row]
            case 3:
                settingName = apnsSettings[indexPath.row]
            default:
                settingName = ""
            }

            cell.label.text = settingName
            cell.textField.placeholder = "Enter \(settingName)"
            cell.textField.isSecureTextEntry = (settingName.contains("Twilio Secret") || settingName.contains("SID"))// || settingName.contains("Key"))
            cell.textField.keyboardType = settingName.contains("#") ? .phonePad : .default
            cell.backgroundColor = .clear

            // Set the stored values based on the setting name
            switch settingName {
            case NSLocalizedString("APNS Key", comment: "APNS Key"):
                cell.configureForMultiline(isMultiline: true, isAPNSKey: true)
                cell.textView.text = Storage.shared.apnsKey.value // Load exact stored value
                cell.textView.delegate = self
                cell.textView.tag = indexPath.row
                
            case NSLocalizedString("Shared Secret", comment: "Shared Secret"):
                cell.configureForMultiline(isMultiline: false)
                cell.textField.text = Storage.shared.sharedSecret.value
                cell.textField.delegate = self
                cell.textField.tag = indexPath.row
                
            case NSLocalizedString("APNS Key ID", comment: "APNS Key ID"):
                cell.configureForMultiline(isMultiline: false)
                cell.textField.text = Storage.shared.keyId.value
                cell.textField.delegate = self
                cell.textField.tag = indexPath.row
                
            case "Twilio SID":
                cell.configureForMultiline(isMultiline: false)
                cell.textField.text = UserDefaultsRepository.twilioSIDString
                cell.textField.delegate = self
                cell.textField.tag = indexPath.row
                
            case "Twilio Secret":
                cell.configureForMultiline(isMultiline: false)
                cell.textField.text = UserDefaultsRepository.twilioSecretString
                cell.textField.delegate = self
                cell.textField.tag = indexPath.row
                
            case NSLocalizedString("Twilio From #", comment: "Twilio From #"):
                cell.configureForMultiline(isMultiline: false)
                cell.textField.text = UserDefaultsRepository.twilioFromNumberString
                cell.textField.delegate = self
                cell.textField.tag = indexPath.row
                
            case NSLocalizedString("Twilio To #", comment: "Twilio To #"):
                cell.configureForMultiline(isMultiline: false)
                cell.textField.text = UserDefaultsRepository.twilioToNumberString
                cell.textField.delegate = self
                cell.textField.tag = indexPath.row
                
            case NSLocalizedString("Entered By", comment: "Entered By"):
                cell.configureForMultiline(isMultiline: false)
                cell.textField.text = UserDefaultsRepository.caregiverName
                cell.textField.delegate = self
                cell.textField.tag = indexPath.row
                
            case NSLocalizedString("Secret Code", comment: "Secret Code"):
                cell.configureForMultiline(isMultiline: false)
                cell.textField.text = UserDefaultsRepository.remoteSecretCode
                cell.textField.delegate = self
                cell.textField.tag = indexPath.row
                
            default:
                cell.configureForMultiline(isMultiline: false)
                cell.textField.delegate = self
                cell.textField.tag = indexPath.row
            }

            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Return a larger height for the APNS Key cell
        if indexPath.section == 3 && indexPath.row == 2 { // Assuming APNS Key is the last row in section 3
            return UITableView.automaticDimension
        }
        return 44
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 3 && indexPath.row == 2 {
            return 150 // Estimated height for APNS Key cell
        }
        return 44
    }

    @objc private func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        let previousMethod = method
        method = sender.selectedSegmentIndex == 0 ? "iOS Shortcuts" : (sender.selectedSegmentIndex == 1 ? "SMS API" : "Trio APNS")

        var sectionsToReload: [Int] = []
        if previousMethod != method {
            sectionsToReload = [1, 2, 3]
        }

        tableView.beginUpdates()
        tableView.reloadSections(IndexSet(sectionsToReload), with: .fade)
        tableView.endUpdates()
    }

    @objc private func limitTextFieldLength(_ textField: UITextField) {
        if textField.text?.count ?? 0 > 50 {
            textField.text = String(textField.text?.prefix(50) ?? "")
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 40
    }
}

//private let sharedSecretStorage = StorageValue<String>(key: "sharedSecret", defaultValue: "")
//private let apnsKeyIdStorage = StorageValue<String>(key: "keyId", defaultValue: "")
//private let apnsKeyStorage = StorageValue<String>(key: "apnsKey", defaultValue: "")

extension RemoteSettingsViewController: UITextFieldDelegate, UITextViewDelegate {
    @objc private func textFieldDidChange(_ textField: UITextField) {
        guard let cell = textField.superview?.superview as? CustomTableViewCell,
              let settingName = cell.label.text else {
            print("Failed to map TextField to a setting name.")
            return
        }

        let newValue = textField.text ?? ""
        print("Updating \(settingName) to: \(newValue)")

        switch settingName {
        case "Twilio SID":
            UserDefaultsRepository.twilioSIDString = newValue
        case "Twilio Secret":
            UserDefaultsRepository.twilioSecretString = newValue
        case NSLocalizedString("Twilio From #", comment: "Twilio From #"):
            UserDefaultsRepository.twilioFromNumberString = newValue
        case NSLocalizedString("Twilio To #", comment: "Twilio To #"):
            UserDefaultsRepository.twilioToNumberString = newValue
        case NSLocalizedString("Entered By", comment: "Entered By"):
            UserDefaultsRepository.caregiverName = newValue
        case NSLocalizedString("Secret Code", comment: "Secret Code"):
            UserDefaultsRepository.remoteSecretCode = newValue
        case NSLocalizedString("Shared Secret", comment: "Shared Secret"):
                Storage.shared.sharedSecret.value = newValue
                UserDefaults.standard.synchronize()
                print("Updated shared secret in Storage.shared: \(newValue)")
        case NSLocalizedString("APNS Key ID", comment: "APNS Key ID"):
                Storage.shared.keyId.value = newValue
                UserDefaults.standard.synchronize()
                print("Updated APNS Key IDt in Storage.shared: \(newValue)")
        default:
            print("Unhandled setting name: \(settingName)")
            break
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let cell = textField.superview?.superview as? CustomTableViewCell,
              let settingName = cell.label.text else {
            return
        }

        switch settingName {
        case "Twilio SID":
            UserDefaultsRepository.twilioSIDString = textField.text ?? ""
        case "Twilio Secret":
            UserDefaultsRepository.twilioSecretString = textField.text ?? ""
        case NSLocalizedString("Twilio From #", comment: "Twilio From #"):
            UserDefaultsRepository.twilioFromNumberString = textField.text ?? ""
        case NSLocalizedString("Twilio To #", comment: "Twilio To #"):
            UserDefaultsRepository.twilioToNumberString = textField.text ?? ""
        case NSLocalizedString("Entered By", comment: "Entered By"):
            UserDefaultsRepository.caregiverName = textField.text ?? ""
        case NSLocalizedString("Secret Code", comment: "Secret Code"):
            UserDefaultsRepository.remoteSecretCode = textField.text ?? ""
        case NSLocalizedString("Shared Secret", comment: "Shared Secret"):
            Storage.shared.sharedSecret.value = textField.text ?? ""
            // Force UserDefaults to synchronize
                        UserDefaults.standard.synchronize()
                        print("Forced save of shared secret on end editing: \(textField.text ?? "")")
        case NSLocalizedString("APNS Key ID", comment: "APNS Key ID"):
            Storage.shared.keyId.value = textField.text ?? ""
        default:
            break
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        guard let cell = textView.superview?.superview as? CustomTableViewCell,
              let settingName = cell.label.text else {
            return
        }

        switch settingName {
        case NSLocalizedString("APNS Key", comment: "APNS Key"):
            // Store the APNS Key exactly as entered in the UITextView
            Storage.shared.apnsKey.value = textView.text
            print("Updated APNS Key in Storage: \(textView.text)")
        default:
            break
        }
    }
}

class CustomTableViewCell: UITableViewCell {
    let label = UILabel()
    let textField = UITextField()
    let textView = UITextView()
    
    private var standardConstraints: [NSLayoutConstraint] = []
    private var apnsKeyConstraints: [NSLayoutConstraint] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        label.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isHidden = true
        
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isScrollEnabled = false
        
        // Enhance TextView appearance
        textView.layer.borderWidth = 1.0
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.cornerRadius = 8
        textView.clipsToBounds = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        
        contentView.addSubview(label)
        contentView.addSubview(textField)
        contentView.addSubview(textView)
        
        // Store standard constraints (side-by-side layout)
        standardConstraints = [
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 120),
            
            textField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 44),
            
            textView.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            textView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ]
        
        // Store APNS Key constraints (stacked layout)
        apnsKeyConstraints = [
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            
            textView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 5),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ]
        
        NSLayoutConstraint.activate(standardConstraints)
    }

    func configureForMultiline(isMultiline: Bool, isAPNSKey: Bool = false) {
        textField.isHidden = isMultiline
        textView.isHidden = !isMultiline
        
        // Deactivate all constraints first
        NSLayoutConstraint.deactivate(standardConstraints)
        NSLayoutConstraint.deactivate(apnsKeyConstraints)
        
        // Activate appropriate constraints
        if isAPNSKey {
            NSLayoutConstraint.activate(apnsKeyConstraints)
        } else {
            NSLayoutConstraint.activate(standardConstraints)
        }
    }
}

class CustomSecureTextField: UITextField {

    override var isSecureTextEntry: Bool {
        didSet {
            if isSecureTextEntry {
                self.delegate = self
            }
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if isSecureTextEntry {
            if action == #selector(paste(_:)) || action == #selector(copy(_:)) {
                return true
            }
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
}

extension CustomSecureTextField: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Disable secure entry temporarily to allow copying/pasting
        isSecureTextEntry = false
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        // Re-enable secure entry after editing
        isSecureTextEntry = true
    }
}
