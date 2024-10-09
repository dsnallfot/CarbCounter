//
//  SuccessView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-10-05.
//

import UIKit

class SuccessView: UIView {

    private let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false

        // Create a palette configuration for the checkmark and circle
        let paletteConfig = UIImage.SymbolConfiguration(paletteColors: [UIColor.white, UIColor.systemGreen])

        // Apply the palette to the SF Symbol
        imageView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: paletteConfig)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let successLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Lyckades", comment: "Success label text")
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
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
        self.backgroundColor = .systemGray2.withAlphaComponent(0.8)
        self.layer.cornerRadius = 20
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.2
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowRadius = 20

        addSubview(checkmarkImageView)
        addSubview(successLabel)

        NSLayoutConstraint.activate([
            // Center the checkmark image
            checkmarkImageView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            checkmarkImageView.topAnchor.constraint(equalTo: self.topAnchor, constant: 20),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 80),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 80),

            // Center the label below the checkmark image
            successLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            successLabel.topAnchor.constraint(equalTo: checkmarkImageView.bottomAnchor, constant: 10),
            successLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -20)
        ])
    }

    func showInView(_ parentView: UIView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(self)

        NSLayoutConstraint.activate([
            self.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            self.centerYAnchor.constraint(equalTo: parentView.centerYAnchor),
            self.widthAnchor.constraint(equalToConstant: 160),
            self.heightAnchor.constraint(equalToConstant: 160)
        ])

        self.alpha = 0
        UIView.animate(withDuration: 0.5, animations: {
            self.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
                self.alpha = 0
            }) { _ in
                self.removeFromSuperview()
            }
        }
    }
}
