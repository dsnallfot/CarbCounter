//
//  UpdateView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-06.
//

import UIKit

class UpdateView: UIView {

    private let loadingIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()

    private let successLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Uppdaterar data...", comment: "Updating data label text")
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        self.backgroundColor = .systemGray4.withAlphaComponent(0)//1)
        self.layer.cornerRadius = 10
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0//0.2
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowRadius = 20

        addSubview(loadingIndicator)
        addSubview(successLabel)

        NSLayoutConstraint.activate([
            // Center the loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: self.topAnchor),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 40),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 40),

            // Center the label below the loading indicator
            successLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            successLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor),
        ])
    }

    func showInView(_ parentView: UIView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(self)

        NSLayoutConstraint.activate([
            self.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            self.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -140),
            self.widthAnchor.constraint(equalToConstant: 160),
            self.heightAnchor.constraint(equalToConstant: 80)
        ])

        loadingIndicator.startAnimating()
        
        self.alpha = 0
        UIView.animate(withDuration: 0.5) {
            self.alpha = 1
        }
    }

    func hide() {
        Task {
            // Wait for 1 second before starting the hide animation
            try await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            
            await MainActor.run {
                UIView.animate(withDuration: 0.5, animations: {
                    self.alpha = 0
                }) { _ in
                    self.loadingIndicator.stopAnimating()
                    self.removeFromSuperview()
                }
            }
        }
    }
}
