import UIKit

class RemoteSettingsViewController: UITableViewController {

    let sectionHeaders = [NSLocalizedString("SELECT REMOTE COMMANDS METHOD", comment: "SELECT REMOTE COMMANDS METHOD"), NSLocalizedString("TWILIO SETTINGS", comment: "TWILIO SETTINGS"), NSLocalizedString("REMOTE CONFIGURATION", comment: "REMOTE CONFIGURATION")]
    let twilioSettings = ["Twilio SID", "Twilio Secret", NSLocalizedString("Twilio From #", comment: "Twilio From #"), NSLocalizedString("Twilio To #", comment: "Twilio To #")]
    let remoteConfig = [NSLocalizedString("Entered By", comment: "Entered By"), NSLocalizedString("Secret Code", comment: "Secret Code")]

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
        tableView.backgroundColor = .clear
            let solidBackgroundView = UIView()
            solidBackgroundView.translatesAutoresizingMaskIntoConstraints = false
            
            // Set solid background depending on light or dark mode
            if traitCollection.userInterfaceStyle == .dark {
                solidBackgroundView.backgroundColor = .systemBackground // This is the solid background in dark mode
            } else {
                solidBackgroundView.backgroundColor = .systemBackground // Solid white background in light mode
            }

            // Create gradient view (used only in dark mode)
            let colors: [CGColor] = [
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor
            ]
            let gradientView = GradientView(colors: colors)
            gradientView.translatesAutoresizingMaskIntoConstraints = false
            
            let backgroundContainerView = UIView()
            backgroundContainerView.addSubview(solidBackgroundView)
            
            // Only add gradient view in dark mode
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
    
        // Add Done button to the navigation bar
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
            return 1
        case 1:
            return method == "SMS API" ? twilioSettings.count : 0
        case 2:
            return remoteConfig.count
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionHeaders[section]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentedControlCell", for: indexPath)
            cell.selectionStyle = .none
            cell.backgroundColor = .clear

            let segmentedControl = UISegmentedControl(items: [NSLocalizedString("Använd genvägar", comment: "Använd genvägar"), NSLocalizedString("Använd SMS API", comment: "Använd SMS API")])
            segmentedControl.selectedSegmentIndex = (UserDefaultsRepository.allowShortcuts && method == "SMS API") ? 1 : 0
            segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false

            cell.contentView.addSubview(segmentedControl)
            NSLayoutConstraint.activate([
                segmentedControl.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 15),
                segmentedControl.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -15),
                segmentedControl.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
                segmentedControl.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10)
            ])

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CustomCell", for: indexPath) as! CustomTableViewCell
            cell.selectionStyle = .none
            let settingName: String

            if indexPath.section == 1 {
                settingName = twilioSettings[indexPath.row]
            } else {
                settingName = remoteConfig[indexPath.row]
            }

            cell.label.text = settingName
            cell.textField.placeholder = "Enter \(settingName)"
            cell.textField.isSecureTextEntry = (settingName.contains("Secret") || settingName.contains("SID"))
            cell.textField.keyboardType = settingName.contains("#") ? .phonePad : .default
            cell.backgroundColor = .clear

            switch settingName {
            case "Twilio SID":
                cell.textField.text = UserDefaultsRepository.twilioSIDString
            case "Twilio Secret":
                cell.textField.text = UserDefaultsRepository.twilioSecretString
            case NSLocalizedString("Twilio From #", comment: "Twilio From #"):
                cell.textField.text = UserDefaultsRepository.twilioFromNumberString
            case NSLocalizedString("Twilio To #", comment: "Twilio To #"):
                cell.textField.text = UserDefaultsRepository.twilioToNumberString
            case NSLocalizedString("Entered By", comment: "Entered By"):
                cell.textField.text = UserDefaultsRepository.caregiverName
            case NSLocalizedString("Secret Code", comment: "Secret Code"):
                cell.textField.text = UserDefaultsRepository.remoteSecretCode
                cell.textField.addTarget(self, action: #selector(limitTextFieldLength(_:)), for: .editingChanged)
            default:
                break
            }

            cell.textField.tag = indexPath.row
            cell.textField.delegate = self

            return cell
        }
    }

    @objc private func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        method = sender.selectedSegmentIndex == 0 ? "iOS Shortcuts" : "SMS API"
        tableView.reloadData()
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

extension RemoteSettingsViewController: UITextFieldDelegate {
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
        default:
            break
        }
    }
}

class CustomTableViewCell: UITableViewCell {
    let label = UILabel()
    let textField = CustomSecureTextField() // Use CustomSecureTextField

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

        contentView.addSubview(label)
        contentView.addSubview(textField)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 120),

            textField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
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
