import UIKit
import WebKit

class NightscoutWebViewController: UIViewController, WKNavigationDelegate {

    var nightscoutURL: URL?
    var mealDate: Date?
    private var currentReportType = "daytoday"
    private var webView: WKWebView!
    private var overlayView: UIView!

    // Add a reference to the toggleReportButton
    private var toggleReportButton: UIBarButtonItem!
    private var glucoseDistributionButton: UIBarButtonItem!
    
    private var currentStartDate: Date? // Track the current start date for glucose distribution
    private var currentEndDate: Date?   // Track the current end date for glucose distribution


    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationBar()
        setupWebView()
        setupOverlayView()

        // Load the Nightscout URL
        reloadNightscoutPage()
    }

    private func setupNavigationBar() {
        if let date = mealDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM HH:mm"
            let formattedDate = dateFormatter.string(from: date)
            self.title = String(format: NSLocalizedString("Måltid %@", comment: "Måltid %@"), formattedDate)
        } else {
            self.title = "Nightscout"
        }

        if isModalPresentation() {
            let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeModal))
            navigationItem.leftBarButtonItem = closeButton
        }

        let previousDayButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(loadPreviousDay))
                let nextDayButton = UIBarButtonItem(image: UIImage(systemName: "chevron.right"), style: .plain, target: self, action: #selector(loadNextDay))
                toggleReportButton = UIBarButtonItem(image: UIImage(systemName: "chart.pie"), style: .plain, target: self, action: #selector(toggleReportType))
                glucoseDistributionButton = UIBarButtonItem(image: UIImage(systemName: "14.square"), style: .plain, target: self, action: #selector(loadGlucoseDistributionReport))

                navigationItem.rightBarButtonItems = [glucoseDistributionButton, toggleReportButton, nextDayButton, previousDayButton]
            }

    private func setupWebView() {
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
    }

    private func setupOverlayView() {
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
    }

    @objc private func closeModal() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func loadPreviousDay() {
        if currentReportType == "glucosedistribution" {
            adjustGlucoseDistributionDates(by: -14)
        } else {
            adjustDate(by: -1)
        }
    }

    @objc private func loadNextDay() {
        if currentReportType == "glucosedistribution" {
            adjustGlucoseDistributionDates(by: 13)
        } else {
            adjustDate(by: 1)
        }
    }
    
    private func adjustGlucoseDistributionDates(by days: Int) {
            let calendar = Calendar.current
            let today = Date()

            if let endDate = currentEndDate {
                // Adjust endDate and startDate by 14 days
                let newEndDate = calendar.date(byAdding: .day, value: days, to: endDate)!
                
                // Check if the new end date is in the future; if so, cap it at today
                let finalEndDate = min(newEndDate, today)
                let finalStartDate = calendar.date(byAdding: .day, value: -13, to: finalEndDate)!

                // Update the current start and end dates
                currentStartDate = finalStartDate
                currentEndDate = finalEndDate

                // Reload the page with the updated dates
                reloadNightscoutPage(startDate: currentStartDate, endDate: currentEndDate)
            }
        }

    @objc private func toggleReportType() {
        currentReportType = (currentReportType == "daytoday") ? "dailystats" : "daytoday"
        reloadNightscoutPage()
    }
    
    @objc private func loadGlucoseDistributionReport() {
            let calendar = Calendar.current
            let today = Date()

            // Set the initial end date to today and start date to 13 days before
            currentEndDate = calendar.date(byAdding: .day, value: -1, to: today)
            currentStartDate = calendar.date(byAdding: .day, value: -13, to: currentEndDate!)

            currentReportType = "glucosedistribution"
            reloadNightscoutPage(startDate: currentStartDate, endDate: currentEndDate)
        }

    private func adjustDate(by days: Int) {
            guard let currentDate = mealDate else { return }
            mealDate = Calendar.current.date(byAdding: .day, value: days, to: currentDate)
            reloadNightscoutPage()
        }

    private func reloadNightscoutPage(startDate: Date? = nil, endDate: Date? = nil) {
            guard var baseURL = UserDefaultsRepository.nightscoutURL,
                  let token = UserDefaultsRepository.nightscoutToken else { return }

            let reportStartDate = startDate ?? mealDate
            let reportEndDate = endDate ?? mealDate

            guard let reportStartDate = reportStartDate, let reportEndDate = reportEndDate else { return }

            if !baseURL.hasSuffix("/") {
                baseURL += "/"
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDateString = dateFormatter.string(from: reportStartDate)
            let endDateString = dateFormatter.string(from: reportEndDate)

            var urlComponents = URLComponents(string: baseURL + "report/")
            urlComponents?.queryItems = [
                URLQueryItem(name: "token", value: token),
                URLQueryItem(name: "report", value: currentReportType),
                URLQueryItem(name: "startDate", value: startDateString),
                URLQueryItem(name: "endDate", value: endDateString),
                URLQueryItem(name: "autoShow", value: "true"),
                URLQueryItem(name: "hideMenu", value: "true"),
            ]

            if let url = urlComponents?.url {
                print("Constructed URL: \(url.absoluteString)")
                overlayView.alpha = 1
                overlayView.isHidden = false
                view.bringSubviewToFront(overlayView)

                updateToggleReportButtonIcon()
                loadNightscoutPage(with: url)
            } else {
                showAlert(title: "Fel", message: "Kunde inte skapa Nightscout URL.")
            }
        }
    
    private func showAlert(title: String, message: String) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }

    private func updateToggleReportButtonIcon() {
        let iconName = (currentReportType == "daytoday") ? "chart.pie" : "chart.dots.scatter"
        toggleReportButton.image = UIImage(systemName: iconName)
    }

    private func loadNightscoutPage(with url: URL) {
        webView.load(URLRequest(url: url))
    }

    // Helper function to check if the view controller is presented modally
    private func isModalPresentation() -> Bool {
        return presentingViewController != nil ||
               navigationController?.presentingViewController?.presentedViewController == navigationController ||
               tabBarController?.presentingViewController is UITabBarController
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Ensure the navigation bar has a background color
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barTintColor = .systemBackground
        navigationController?.navigationBar.backgroundColor = .systemBackground

        AppDelegate.AppUtility.lockOrientation(.landscape)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Reset the navigation bar appearance when leaving this screen
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
                self.overlayView.isHidden = true
            }
        }
    }
}
