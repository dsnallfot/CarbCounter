//
//  HomeViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-17.
//

import UIKit

class HomeViewController: UIViewController {
    
    override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            setupHelloWorldLabel()
        }
    
    private func setupHelloWorldLabel() {
        let helloWorldLabel = UILabel()
        helloWorldLabel.text = "Hello World"
        helloWorldLabel.textAlignment = .center
        helloWorldLabel.font = UIFont.systemFont(ofSize: 24)
        helloWorldLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(helloWorldLabel)
        
        // Constraints to center the label
        NSLayoutConstraint.activate([
            helloWorldLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            helloWorldLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

