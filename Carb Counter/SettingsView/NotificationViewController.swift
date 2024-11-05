import UIKit

class NotificationViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBackground()
        setupNotificationToggles()
        self.title = NSLocalizedString("Notiser", comment: "Title for Notification settings")
    }
    
    private func setupBackground() {
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .systemBackground
            let colors: [CGColor] = [
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor
            ]
            let gradientView = GradientView(colors: colors)
            gradientView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(gradientView)
            
            NSLayoutConstraint.activate([
                gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                gradientView.topAnchor.constraint(equalTo: view.topAnchor),
                gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        } else {
            view.backgroundColor = .systemGray6
        }
    }
    
    private func setupNotificationToggles() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let historyToggle = createToggle(labelText: NSLocalizedString("Måltidshistorik (via genväg)", comment: "Allow history notifications"), isOn: UserDefaultsRepository.historyNotificationsAllowed, action: #selector(toggleHistoryNotifications(_:)))
        
        let registrationToggle = createToggle(labelText: NSLocalizedString("Registrerade värden (via genväg)", comment: "Allow registration notifications"), isOn: UserDefaultsRepository.registrationNotificationsAllowed, action: #selector(toggleRegistrationNotifications(_:)))
        
        let preBolusToggle = createToggle(labelText: NSLocalizedString("Prebolus 20 min varning", comment: "Allow pre-bolus notifications"), isOn: UserDefaultsRepository.preBolusNotificationsAllowed, action: #selector(togglePreBolusNotifications(_:)))
        
        stackView.addArrangedSubview(historyToggle)
        stackView.addArrangedSubview(registrationToggle)
        stackView.addArrangedSubview(preBolusToggle)
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }
    
    private func createToggle(labelText: String, isOn: Bool, action: Selector) -> UIStackView {
        let toggleSwitch = UISwitch()
        toggleSwitch.isOn = isOn
        toggleSwitch.addTarget(self, action: action, for: .valueChanged)
        
        let toggleLabel = UILabel()
        toggleLabel.text = labelText
        toggleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [toggleLabel, toggleSwitch])
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.distribution = .fill
        
        return stackView
    }
    
    @objc private func toggleHistoryNotifications(_ sender: UISwitch) {
        UserDefaultsRepository.historyNotificationsAllowed = sender.isOn
    }
    
    @objc private func toggleRegistrationNotifications(_ sender: UISwitch) {
        UserDefaultsRepository.registrationNotificationsAllowed = sender.isOn
    }
    
    @objc private func togglePreBolusNotifications(_ sender: UISwitch) {
        UserDefaultsRepository.preBolusNotificationsAllowed = sender.isOn
    }
}
