//
//  NightscoutWebViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-10-08.
//

import UIKit
import WebKit

class NightscoutWebViewController: UIViewController {

    var nightscoutURL: URL?

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the navigation bar title
        self.title = "Nightscout"

        // Create the web view and add it to the view
        webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // Set up web view constraints
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Load the Nightscout URL
        if let url = nightscoutURL {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
            return .landscape
        }

        override var shouldAutorotate: Bool {
            return true
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            AppDelegate.AppUtility.lockOrientation(.landscape)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            AppDelegate.AppUtility.lockOrientation(.portrait)
        }

}




