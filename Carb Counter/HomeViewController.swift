import UIKit

class HomeViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    private func setupUI() {
        // Create and setup the title label
        let titleLabel = UILabel()
        titleLabel.text = "Carb Counter"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 40, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create and setup the app icon image view
        let appIconImageView = UIImageView()
        if let image = UIImage(named: "Image512") {
            appIconImageView.image = image
        } else {
            print("Error: Image 'Image512' not found")
            appIconImageView.image = UIImage(systemName: "photo") // Placeholder image
        }
        appIconImageView.contentMode = .scaleAspectFit
        appIconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create and setup the copyright label
        let copyrightLabel = UILabel()
        copyrightLabel.text = "© 2024 Daniel Snällfot"
        copyrightLabel.textAlignment = .center
        copyrightLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews to the main view
        view.addSubview(titleLabel)
        view.addSubview(appIconImageView)
        view.addSubview(copyrightLabel)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Title label constraints
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // App icon image view constraints
            appIconImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            appIconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            appIconImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            appIconImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            appIconImageView.heightAnchor.constraint(equalTo: appIconImageView.widthAnchor), // Maintain aspect ratio
            
            // Copyright label constraints
            copyrightLabel.topAnchor.constraint(equalTo: appIconImageView.bottomAnchor, constant: 20),
            copyrightLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            copyrightLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
}
