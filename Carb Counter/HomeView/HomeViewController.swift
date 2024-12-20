import UIKit

class HomeViewController: UIViewController {
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeHomeViewController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateNavigationBarButtons()
    }
    
    internal func initializeHomeViewController() {
        print("🏠 initializeHomeViewController called")
        view.backgroundColor = .systemBackground
        
        // Check if the app is in dark mode and set the background accordingly
        updateBackgroundForCurrentMode()
        
        setupUI()
        
        // Observe changes to allowViewingOngoingMeals
        NotificationCenter.default.addObserver(self, selector: #selector(updateNavigationBarButtons), name: .allowViewingOngoingMealsChanged, object: nil)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Check if the user interface style (light/dark mode) has changed
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackgroundForCurrentMode()
        }
    }

    private func updateBackgroundForCurrentMode() {
        // Remove any existing gradient views before updating
        view.subviews.filter { $0 is GradientView }.forEach { $0.removeFromSuperview() }
        
        // Update the background based on the current interface style
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .systemBackground
            // Create the gradient view for dark mode
            let colors: [CGColor] = [
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor
            ]
            let gradientView = GradientView(colors: colors)
            gradientView.translatesAutoresizingMaskIntoConstraints = false

            // Add the gradient view to the main view
            view.addSubview(gradientView)
            view.sendSubviewToBack(gradientView)

            // Set up constraints for the gradient view
            NSLayoutConstraint.activate([
                gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                gradientView.topAnchor.constraint(equalTo: view.topAnchor),
                gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        } else {
            // In light mode, set a solid background
            view.backgroundColor = .systemGray6
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        // Create and setup the title label
        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("Räkna Kolhydrater", comment: "Title for the home screen")
        titleLabel.textAlignment = .center
        
        let systemFont = UIFont.systemFont(ofSize: 36, weight: .semibold)
        if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: roundedDescriptor, size: 36)
        } else {
            titleLabel.font = systemFont
        }

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        
        
        // Create and setup the container view for the image
        let imageContainerView = UIView()
        imageContainerView.backgroundColor = .clear
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.layer.cornerRadius = 40 // Increase corner radius
        imageContainerView.layer.masksToBounds = true

        // Create and setup the app icon image view
        let appIconImageView = UIImageView()
        if let image = UIImage(named: "launch") {
            appIconImageView.image = image
        } else {
            print("Error: Image 'launch' not found")
            appIconImageView.image = UIImage(systemName: "photo") // Placeholder image
        }
        appIconImageView.contentMode = .scaleAspectFit
        appIconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the image view to the container view
        imageContainerView.addSubview(appIconImageView)
        
        // Create and setup the copyright label
        let copyrightLabel = UILabel()
        copyrightLabel.text = "© 2024 Daniel Snällfot"
        copyrightLabel.textAlignment = .center
        copyrightLabel.textColor = .clear
        copyrightLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews to the main view
        view.addSubview(titleLabel)
        view.addSubview(imageContainerView)
        view.addSubview(copyrightLabel)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Title label constraints
            titleLabel.bottomAnchor.constraint(equalTo: imageContainerView.topAnchor, constant: -33),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Image container view constraints
            //imageContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: -10), // Adjusted to move higher
            imageContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageContainerView.heightAnchor.constraint(equalTo: imageContainerView.widthAnchor), // Maintain aspect ratio
            
            // App icon image view constraints within the container view
            appIconImageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            appIconImageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),
            appIconImageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            appIconImageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            
            // Copyright label constraints
            copyrightLabel.topAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: 33),
            copyrightLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            //copyrightLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -110)
        ])
        updateNavigationBarButtons()
    }
        
    @objc private func updateNavigationBarButtons() {
        let eyeButton = UIBarButtonItem(image: UIImage(systemName: "eye"), style: .plain, target: self, action: #selector(showOngoingMeal))
        eyeButton.isEnabled = UserDefaultsRepository.allowViewingOngoingMeals
        navigationItem.leftBarButtonItem = eyeButton
        
        // Add cog wheel icon to the top right corner
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(openSettings))
        navigationItem.rightBarButtonItem = settingsButton
    }
    
    @objc func showOngoingMeal() {
        let ongoingMealVC = OngoingMealViewController()
        let navigationController = UINavigationController(rootViewController: ongoingMealVC)
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true, completion: nil)
    }
    
    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true, completion: nil)
    }
}
