import UIKit

class NotificationViewController: UITableViewController {
    
    private let settings: [(title: String, isOn: () -> Bool, toggleAction: Selector)] = [
        (NSLocalizedString("Måltidshistorik (via genväg)", comment: "Allow history notifications"),
         { UserDefaultsRepository.historyNotificationsAllowed },
         #selector(toggleHistoryNotifications(_:))),
        
        (NSLocalizedString("Registrerade värden (via genväg)", comment: "Allow registration notifications"),
         { UserDefaultsRepository.registrationNotificationsAllowed },
         #selector(toggleRegistrationNotifications(_:))),
        
        (NSLocalizedString("Prebolus 20 min varning", comment: "Allow pre-bolus notifications"),
         { UserDefaultsRepository.preBolusNotificationsAllowed },
         #selector(togglePreBolusNotifications(_:))),
        
        (NSLocalizedString("Ej avslutad måltid 45 min varning", comment: "Allow finish meal notifications"),
         { UserDefaultsRepository.finishMealNotificationsAllowed },
         #selector(toggleFinishMealNotifications(_:)))
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("Notiser", comment: "Title for Notification settings")
        setupBackground()
        
        // Add Done button to the navigation bar
        let doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Done"), style: .done, target: self, action: #selector(doneButtonTapped))
        navigationItem.rightBarButtonItem = doneButton
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "switchCell")
    }
    
    @objc private func doneButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupBackground() {
            // Create a solid background for light mode and a gradient for dark mode
            let backgroundContainerView = UIView()
            let solidBackgroundView = UIView()
            solidBackgroundView.translatesAutoresizingMaskIntoConstraints = false
            backgroundContainerView.addSubview(solidBackgroundView)
            
            if traitCollection.userInterfaceStyle == .dark {
                solidBackgroundView.backgroundColor = .systemBackground
                
                // Set up gradient
                let colors: [CGColor] = [
                    UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
                    UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
                    UIColor.systemBlue.withAlphaComponent(0.15).cgColor
                ]
                let gradientView = GradientView(colors: colors)
                gradientView.translatesAutoresizingMaskIntoConstraints = false
                backgroundContainerView.addSubview(gradientView)
                
                NSLayoutConstraint.activate([
                    gradientView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
                    gradientView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
                    gradientView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
                    gradientView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
                ])
            } else {
                solidBackgroundView.backgroundColor = .systemGray6
            }

            // Set the container view as the table's background view
            tableView.backgroundView = backgroundContainerView

            NSLayoutConstraint.activate([
                solidBackgroundView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
                solidBackgroundView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
                solidBackgroundView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
                solidBackgroundView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
            ])
        }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settings.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "switchCell")
        cell.backgroundColor = .clear
        
        // Custom selection color
        let customSelectionColor = UIView()
        customSelectionColor.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        cell.selectedBackgroundView = customSelectionColor
        
        let setting = settings[indexPath.row]
        
        // Configure label
        cell.textLabel?.text = setting.title
        cell.textLabel?.font = .systemFont(ofSize: 17)
        cell.textLabel?.textColor = .label
        
        // Configure switch
        let toggleSwitch = UISwitch()
        toggleSwitch.isOn = setting.isOn()
        toggleSwitch.addTarget(self, action: setting.toggleAction, for: .valueChanged)
        cell.accessoryView = toggleSwitch
        
        return cell
    }
    
    // Toggle actions
    @objc private func toggleHistoryNotifications(_ sender: UISwitch) {
        UserDefaultsRepository.historyNotificationsAllowed = sender.isOn
    }
    
    @objc private func toggleRegistrationNotifications(_ sender: UISwitch) {
        UserDefaultsRepository.registrationNotificationsAllowed = sender.isOn
    }
    
    @objc private func togglePreBolusNotifications(_ sender: UISwitch) {
        UserDefaultsRepository.preBolusNotificationsAllowed = sender.isOn
    }
    
    @objc private func toggleFinishMealNotifications(_ sender: UISwitch) {
        UserDefaultsRepository.finishMealNotificationsAllowed = sender.isOn
    }
}
