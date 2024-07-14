import UIKit

class HomeViewController: UIViewController {
    
    var dataSharingVC: DataSharingViewController?
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create the gradient view
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
        
        setupUI()
        
        // Get a reference to the ComposeMealViewController
        if let tabBarController = self.tabBarController,
           let viewControllers = tabBarController.viewControllers {
            for viewController in viewControllers {
                if let navController = viewController as? UINavigationController,
                   let composeMealVC = navController.viewControllers.first(where: { $0 is ComposeMealViewController }) as? ComposeMealViewController {
                        composeMealVC.fetchFoodItems()
                }
            }
        }
        
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else { return }
        
        // Call the desired function
        print("Data import triggered")
        dataSharingVC.importAllCSVFiles()
        
        // Observe changes to allowViewingOngoingMeals
        NotificationCenter.default.addObserver(self, selector: #selector(updateNavigationBarButtons), name: .allowViewingOngoingMealsChanged, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateNavigationBarButtons()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .allowViewingOngoingMealsChanged, object: nil)
    }
    
    private func setupUI() {
        // Create and setup the title label
        let titleLabel = UILabel()
        titleLabel.text = "Carbs Counter"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 48, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create and setup the container view for the image
        let imageContainerView = UIView()
        imageContainerView.backgroundColor = .clear
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.layer.cornerRadius = 40 // Increase corner radius
        imageContainerView.layer.masksToBounds = true
        
        /*
        // Add shadow/glow to the container view - Needs to check why this doesn't work
        imageContainerView.layer.shadowColor = UIColor.white.cgColor
        imageContainerView.layer.shadowOffset = CGSize(width: 0, height: 10)
        imageContainerView.layer.shadowRadius = 30
        imageContainerView.layer.shadowOpacity = 0.5 // Increase shadow opacity
        */
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
        copyrightLabel.textColor = .gray
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
            copyrightLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -110)
        ])
        
        // Add cog wheel icon to the top right corner
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(openSettings))
        navigationItem.rightBarButtonItem = settingsButton
        
        updateNavigationBarButtons()
    }
        
    @objc private func updateNavigationBarButtons() {
        let eyeButton = UIBarButtonItem(image: UIImage(systemName: "eye"), style: .plain, target: self, action: #selector(showOngoingMeal))
        eyeButton.isEnabled = UserDefaultsRepository.allowViewingOngoingMeals
        navigationItem.leftBarButtonItem = eyeButton
    }
    
    @objc func showOngoingMeal() {
        let ongoingMealVC = OngoingMealViewController()
        let navigationController = UINavigationController(rootViewController: ongoingMealVC)
        navigationController.modalPresentationStyle = .automatic // or .pageSheet or .formSheet for iPad
        present(navigationController, animated: true, completion: nil)
    }
    
    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true, completion: nil)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update shadow/glow based on user interface style
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        if let imageContainerView = view.subviews.first(where: { $0 is UIView }) {
            imageContainerView.layer.shadowColor = isDarkMode ? UIColor.white.cgColor : UIColor.black.cgColor
            imageContainerView.layer.shadowOpacity = isDarkMode ? 0.5 : 0.25 // Adjust based on mode
        }
    }
}
