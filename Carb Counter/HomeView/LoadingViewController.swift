// LoadingViewController.swift
// Carb Counter
//
// Created by Daniel Snällfot on 2024-07-14.

import UIKit

class LoadingViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
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
        
        // Setup UI components
        setupUI()
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
