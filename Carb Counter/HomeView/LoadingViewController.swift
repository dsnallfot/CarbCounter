// LoadingViewController.swift
// Carb Counter
//
// Created by Daniel Snällfot on 2024-07-14.

import UIKit

class LoadingViewController: UIViewController {
    
    var dataSharingVC: DataSharingViewController?
    var minimumDisplayTime: TimeInterval = 2.5

    override func viewDidLoad() {
            super.viewDidLoad()
            
            view.backgroundColor = .systemBackground
            
        // Check if the app is in dark mode
        if traitCollection.userInterfaceStyle == .dark {
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
            
            // Ensure dataSharingVC is instantiated
            dataSharingVC = DataSharingViewController()
            
            // Setup UI components
            setupUI()
        }
    
    override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            print("LoadingViewController appeared")
            
            // Start the minimum display timer
            let minimumDisplayTime = self.minimumDisplayTime
            let startTime = Date()
            
            // Create a DispatchGroup to synchronize tasks
            let dispatchGroup = DispatchGroup()
            
            // Ensure dataSharingVC is instantiated
            guard let dataSharingVC = dataSharingVC else {
                print("dataSharingVC is nil")
                return
            }
            
            dispatchGroup.enter()
            // Perform data import
            print("Data import triggered")
            Task {
                await dataSharingVC.importCSVFiles()
                print("Data import completed")
                dispatchGroup.leave()
            }
            
            // Wait for both tasks to complete
            dispatchGroup.notify(queue: .main) {
                let elapsedTime = Date().timeIntervalSince(startTime)
                let remainingTime = minimumDisplayTime - elapsedTime
                
                if remainingTime > 0 {
                    // Wait for the remaining time before transitioning
                    DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                        self.transitionToMainViewController()
                    }
                } else {
                    // Minimum display time already passed, transition immediately
                    self.transitionToMainViewController()
                }
            }
        }
        
        private func transitionToMainViewController() {
            // Instantiate the main view controller
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let mainVC = storyboard.instantiateInitialViewController() else {
                print("Failed to instantiate main view controller")
                return
            }
            
            // Access the ComposeMealViewController from the mainVC
            if let tabBarController = mainVC as? UITabBarController {
                if let composeNavVC = tabBarController.viewControllers?.first(where: { ($0 as? UINavigationController)?.topViewController is ComposeMealViewController }) as? UINavigationController,
                   let composeMealVC = composeNavVC.topViewController as? ComposeMealViewController {
                    
                    // Call fetchFoodItems on composeMealVC
                    composeMealVC.fetchFoodItems()
                    print("fetchFoodItems completed")
                }
            }
            
            // Transition to the main view controller
            // Add a transition animation
            let transition = CATransition()
            transition.type = .fade
            transition.duration = 0.5
            self.view.window?.layer.add(transition, forKey: kCATransition)
            
            self.view.window?.rootViewController = mainVC
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
           titleLabel.textColor = UIColor.label.withAlphaComponent(0.4)
        
        // Create and setup the container view for the image
        let imageContainerView = UIView()
        imageContainerView.backgroundColor = .clear
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.layer.cornerRadius = 40
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
        appIconImageView.alpha = 0.3
        
        // Add the image view to the container view
        imageContainerView.addSubview(appIconImageView)
        
        // Create and set up the loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        
        // Create and set up the label
        let loadingLabel = UILabel()
        loadingLabel.text = NSLocalizedString("Uppdaterar data", comment: "Updating data")
        loadingLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        loadingLabel.textAlignment = .center
        loadingLabel.textColor = .label
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        
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
        view.addSubview(loadingIndicator)
        view.addSubview(loadingLabel)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Title label constraints
            titleLabel.bottomAnchor.constraint(equalTo: imageContainerView.topAnchor, constant: -33),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Image container view constraints
            imageContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageContainerView.heightAnchor.constraint(equalTo: imageContainerView.widthAnchor),
            
            // App icon image view constraints within the container view
            appIconImageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            appIconImageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),
            appIconImageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            appIconImageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            
            // Copyright label constraints
            copyrightLabel.topAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: 33),
            copyrightLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            copyrightLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -159),
            
            // Loading indicator constraints
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: copyrightLabel.bottomAnchor, constant: 10),
            
            // Loading label constraints
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 20)
            
            
        ])
    }
}
