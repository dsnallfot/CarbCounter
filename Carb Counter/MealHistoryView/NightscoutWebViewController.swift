import UIKit
import WebKit

class NightscoutWebViewController: UIViewController, WKNavigationDelegate {

    var nightscoutURL: URL?
    var mealDate: Date?

    private var webView: WKWebView!
    private var overlayView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the navigation bar title
        if let date = mealDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM HH:mm"
            let formattedDate = dateFormatter.string(from: date)
            self.title = String(format: NSLocalizedString("Nightscout • Måltid %@", comment: "Nightscout • Måltid %@"), formattedDate)
        } else {
            self.title = "Nightscout"
        }
        
        // If the view controller is presented modally, add a close button
        if isModalPresentation() {
            let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeModal))
            navigationItem.leftBarButtonItem = closeButton
        }

        // Create and configure the web view
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        view.addSubview(webView)

        // Set up web view constraints
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Create and add the overlay view
        overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = .white
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlayView)

        // Initialize and add the nightscout image view
        let imageView = UIImageView(image: UIImage(named: "nightscout")?.withRenderingMode(.alwaysTemplate))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray
        overlayView.addSubview(imageView)

        // Initialize and add the activity indicator
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .systemGray
        activityIndicator.startAnimating()
        overlayView.addSubview(activityIndicator)

        // Initialize and add the label
        let fetchingLabel = UILabel()
        fetchingLabel.translatesAutoresizingMaskIntoConstraints = false
        fetchingLabel.text = NSLocalizedString("Hämtar rapport", comment: "Fetching report text")
        fetchingLabel.textAlignment = .center
        fetchingLabel.textColor = .systemGray

        // Use a rounded font if available
        let systemFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            fetchingLabel.font = UIFont(descriptor: roundedDescriptor, size: 14)
        } else {
            fetchingLabel.font = systemFont
        }

        overlayView.addSubview(fetchingLabel)

        // Add constraints for image, activity indicator, and label
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            imageView.bottomAnchor.constraint(equalTo: activityIndicator.topAnchor, constant: -12),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            
            activityIndicator.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            
            fetchingLabel.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            fetchingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12)
        ])

        // Load the Nightscout URL
        if let url = nightscoutURL {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    @objc private func closeModal() {
        dismiss(animated: true, completion: nil)
    }
    
    // Helper function to check if the view controller is presented modally
    private func isModalPresentation() -> Bool {
        return presentingViewController != nil || navigationController?.presentingViewController?.presentedViewController == navigationController || tabBarController?.presentingViewController is UITabBarController
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape //.allButUpsideDown
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure the navigation bar has a background color
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barTintColor = .systemBackground // Or any desired color
        navigationController?.navigationBar.backgroundColor = .systemBackground // Or any desired color
        //navigationController?.navigationBar.tintColor = .label // Set this if you need proper contrast
        
        
        AppDelegate.AppUtility.lockOrientation(.landscape) //(.allButUpsideDown)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // If you need to reset the navigation bar appearance when leaving this screen
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.barTintColor = nil
        navigationController?.navigationBar.backgroundColor = nil

        webView.stopLoading()
        AppDelegate.AppUtility.lockOrientation(.portrait)
    }
    
    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Hide the overlay when content has loaded
        fadeOutOverlay()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Hide the overlay if there's an error
        fadeOutOverlay()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fadeOutOverlay()
        let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Error"),
                                      message: NSLocalizedString("Kunde inte ladda Nightscout-sidan. Kontrollera din internetanslutning och försök igen.", comment: "Could not load Nightscout page. Check your internet connection and try again."),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func fadeOutOverlay() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.5, animations: {
                self.overlayView.alpha = 0
            }) { _ in
                self.overlayView.removeFromSuperview()
            }
        }
    }
}
