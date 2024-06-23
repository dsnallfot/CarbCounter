import UIKit

class RemoteSettingsViewController: UITableViewController {

    let sectionHeaders = ["SELECT REMOTE COMMANDS METHOD", "TWILIO SETTINGS", "REMOTE CONFIGURATION"]
    let twilioSettings = ["Twilio SID", "Twilio Secret", "Twilio From #", "Twilio To #"]
    let remoteConfig = ["Entered By", "Secret Code"]

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
        title = "Remote Inställningar"
        tableView.register(CustomTableViewCell.self, forCellReuseIdentifier: "CustomCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SegmentedControlCell")
        tableView.tableFooterView = UIView()

        if method.isEmpty {
            method = "iOS Shortcuts"
        }
    
        // Add Done button to the navigation bar
        let doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
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

            let segmentedControl = UISegmentedControl(items: ["iOS Shortcuts", "SMS API"])
            segmentedControl.selectedSegmentIndex = method == "SMS API" ? 1 : 0
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

            switch settingName {
            case "Twilio SID":
                cell.textField.text = UserDefaultsRepository.twilioSIDString
            case "Twilio Secret":
                cell.textField.text = UserDefaultsRepository.twilioSecretString
            case "Twilio From #":
                cell.textField.text = UserDefaultsRepository.twilioFromNumberString
            case "Twilio To #":
                cell.textField.text = UserDefaultsRepository.twilioToNumberString
            case "Entered By":
                cell.textField.text = UserDefaultsRepository.caregiverName
            case "Secret Code":
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
        if textField.text?.count ?? 0 > 10 {
            textField.text = String(textField.text?.prefix(10) ?? "")
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
        case "Twilio From #":
            UserDefaultsRepository.twilioFromNumberString = textField.text ?? ""
        case "Twilio To #":
            UserDefaultsRepository.twilioToNumberString = textField.text ?? ""
        case "Entered By":
            UserDefaultsRepository.caregiverName = textField.text ?? ""
        case "Secret Code":
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
