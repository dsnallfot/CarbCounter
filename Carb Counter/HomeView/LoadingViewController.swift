// LoadingViewController.swift
// Carb Counter
//
// Created by Daniel Snällfot on 2024-07-14.

import UIKit

class LoadingViewController: UIViewController {
    
    var dataSharingVC: DataSharingViewController?
    var minimumDisplayTime: TimeInterval = 1.5
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check if the app is in dark mode
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
        
        if UserDefaultsRepository.allowCSVSync {
            dispatchGroup.enter()
            // Perform data import
            print("Data import triggered")
            Task {
                await dataSharingVC.importCSVFiles()
                print("Data import completed")
                dispatchGroup.leave()
            }
        } else {
            print("CSV import is disabled in settings.")
        }
        
        // Wait for tasks to complete
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
        guard let mainVC = storyboard.instantiateInitialViewController() as? UITabBarController else {
            print("❌ Failed to instantiate main view controller")
            return
        }
        
        print("✅ Main view controller instantiated successfully")
        print("📊 Total view controllers: \(mainVC.viewControllers?.count ?? 0)")
        
        // Explicitly access and initialize each main view controller
        for (index, navigationController) in (mainVC.viewControllers ?? []).enumerated() {
            guard let navigationController = navigationController as? UINavigationController else {
                print("❌ Not a navigation controller at index \(index)")
                continue
            }
            
            print("🔍 Processing navigation controller at index \(index)")
            
            // Access the root view controller of the navigation controller
            guard let rootViewController = navigationController.viewControllers.first else {
                print("❌ No root view controller found in navigation controller")
                continue
            }
            
            print("🚀 Accessing view for \(type(of: rootViewController))")
            _ = rootViewController.view
            /*
            // Initialize specific view controllers
            if let homeVC = rootViewController as? HomeViewController {
                print("🏠 Found HomeViewController")
                homeVC.initializeHomeViewController()
            }*/
            if let composeMealVC = rootViewController as? ComposeMealViewController {
                print("🍽 Found ComposeMealViewController")
                composeMealVC.initializeView()
                
                // Ensure the shared instance is set
                ComposeMealViewController.shared = composeMealVC
            } /*
                // Existing fetch logic
                composeMealVC.fetchFoodItems {
                    print("✅ fetchFoodItems completed for ComposeMealViewController")
                }
            }
            if let foodItemsListVC = rootViewController as? FoodItemsListViewController {
                print("📋 Found FoodItemsListViewController")
                foodItemsListVC.initializeFoodItemsListViewController()
            }
            */
            print("✨ Finished processing \(type(of: rootViewController))")
        }
        
        print("🌟 About to transition to main view controller")
        
        // Transition to the main view controller
        // Add a transition animation
        let transition = CATransition()
        transition.type = .fade
        transition.duration = 0.5
        self.view.window?.layer.add(transition, forKey: kCATransition)
        
        self.view.window?.rootViewController = mainVC
        
        print("🎉 Transition to main view controller complete")
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
        
        // Add subviews to the main view
        view.addSubview(titleLabel)
        view.addSubview(imageContainerView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Title label constraints
            titleLabel.bottomAnchor.constraint(equalTo: imageContainerView.topAnchor, constant: -33),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Image container view constraints
            imageContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageContainerView.heightAnchor.constraint(equalTo: imageContainerView.widthAnchor),
            
            // App icon image view constraints within the container view
            appIconImageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            appIconImageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),
            appIconImageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            appIconImageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            
        ])
    }
}
