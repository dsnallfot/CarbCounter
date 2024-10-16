import UIKit

class CarbRatioViewController: UITableViewController, UITextFieldDelegate {
    var carbRatios: [Int: Double] = [:]
    var clearButton: UIBarButtonItem!
    var doneButton: UIBarButtonItem!
    var downloadButton: UIBarButtonItem!
    
    var dataSharingVC: DataSharingViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .clear // Make sure the table view itself is clear
                
                // Create the solid background view
                let solidBackgroundView = UIView()
                solidBackgroundView.backgroundColor = .systemBackground
                solidBackgroundView.translatesAutoresizingMaskIntoConstraints = false
                
                // Create the gradient view
                let colors: [CGColor] = [
                    UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
                    UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
                    UIColor.systemBlue.withAlphaComponent(0.15).cgColor
                ]
                let gradientView = GradientView(colors: colors)
                gradientView.translatesAutoresizingMaskIntoConstraints = false
                
                // Add the solid background view and gradient view as the table view's background view
                let backgroundContainerView = UIView()
                backgroundContainerView.addSubview(solidBackgroundView)
                backgroundContainerView.addSubview(gradientView)
                tableView.backgroundView = backgroundContainerView
                
                // Set up constraints for the solid background view
                NSLayoutConstraint.activate([
                    solidBackgroundView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
                    solidBackgroundView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
                    solidBackgroundView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
                    solidBackgroundView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
                ])
                
                // Set up constraints for the gradient view
                NSLayoutConstraint.activate([
                    gradientView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
                    gradientView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
                    gradientView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
                    gradientView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
                ])
        
        title = NSLocalizedString("Carb Ratio", comment: "Carb Ratio")
        tableView.register(CarbRatioCell.self, forCellReuseIdentifier: "CarbRatioCell")
        loadCarbRatios()

        // Add Done button to the navigation bar
        doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Klar"), style: .done, target: self, action: #selector(doneButtonTapped))
        navigationItem.rightBarButtonItem = doneButton

        // Setup Clear button
        clearButton = UIBarButtonItem(title: NSLocalizedString("Rensa", comment: "Rensa"), style: .plain, target: self, action: #selector(clearButtonTapped))
        clearButton.tintColor = .red

        // Setup Download button with SF Symbol
        let downloadImage = UIImage(systemName: "square.and.arrow.down")
        downloadButton = UIBarButtonItem(image: downloadImage, style: .plain, target: self, action: #selector(downloadButtonTapped))

        // Listen for changes to allowDataClearing setting
        NotificationCenter.default.addObserver(self, selector: #selector(updateButtonVisibility), name: Notification.Name("AllowDataClearingChanged"), object: nil)

        // Update button visibility based on the current setting
        updateButtonVisibility()
        
        // Instantiate DataSharingViewController programmatically
        dataSharingVC = DataSharingViewController()
        
        addRefreshControl()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func updateButtonVisibility() {
        if UserDefaultsRepository.allowDataClearing {
            navigationItem.rightBarButtonItems = [clearButton]
        } else {
            navigationItem.rightBarButtonItems = [doneButton, downloadButton]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCarbRatios()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else { return }
        
        // Call the desired function
        Task {
            print("Carb ratios export triggered")
            await dataSharingVC.exportCarbRatioScheduleToCSV()

        }
    }

    private func loadCarbRatios() {
        carbRatios = CoreDataHelper.shared.fetchCarbRatios()
        tableView.reloadData()
    }

    @objc private func doneButtonTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func clearButtonTapped() {
        let alertController = UIAlertController(title: NSLocalizedString("Rensa", comment: "Rensa"), message: NSLocalizedString("Är du säker på att du vill rensa all data?", comment: "Är du säker på att du vill rensa all data?"), preferredStyle: .actionSheet)
        let yesAction = UIAlertAction(title: NSLocalizedString("Ja", comment: "Ja"), style: .destructive) { _ in
            CoreDataHelper.shared.clearAllCarbRatios()
            self.loadCarbRatios()
        }
        let noAction = UIAlertAction(title: NSLocalizedString("Nej", comment: "Nej"), style: .cancel, handler: nil)

        alertController.addAction(yesAction)
        alertController.addAction(noAction)

        present(alertController, animated: true, completion: nil)
    }

    @objc private func downloadButtonTapped() {
        let alertController = UIAlertController(
            title: NSLocalizedString("Nightscout import", comment: "Nightscout import"),
            message: NSLocalizedString("Vill du ladda ner Carb Ratios från Nightscout?\n\nObservera att dina nuvarande data skrivs över.", comment: "Vill du ladda ner Carb Ratios från Nightscout?\n\nObservera att dina nuvarande data skrivs över."),
            preferredStyle: .actionSheet
        )

        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel, handler: nil)
        let confirmAction = UIAlertAction(title: NSLocalizedString("Ja", comment: "Ja"), style: .destructive) { _ in
            self.downloadCarbRatiosFromNightscout()
        }

        alertController.addAction(cancelAction)
        alertController.addAction(confirmAction)

        present(alertController, animated: true, completion: nil)
    }

    private func downloadCarbRatiosFromNightscout() {
        NightscoutManager.shared.fetchAndMapCarbRatio { success in
            DispatchQueue.main.async {
                if success {
                    self.loadCarbRatios()
                    let alert = UIAlertController(title: NSLocalizedString("Lyckades", comment: "Lyckades"), message: NSLocalizedString("Carb ratios importerade och mappede från Nightscout.", comment: "Carb ratios importerade och mappede från Nightscout."), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                } else {
                    let alert = UIAlertController(title: NSLocalizedString("Fel", comment: "Fel"), message: NSLocalizedString("Kunde inte importera carb ratios från Nightscout.", comment: "Kunde inte importera carb ratios från Nightscout."), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 24
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CarbRatioCell", for: indexPath) as! CarbRatioCell
        let hour = String(format: "%02d:00", indexPath.row)
        let ratio = carbRatios[indexPath.row] ?? 0.0

        // Pass nil to the text field if the ratio is 0.0, otherwise pass the formatted ratio
        let formattedRatio = ratio == 0.0 ? nil : (ratio.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", ratio) : String(format: "%.1f", ratio))

        cell.configure(hour: hour, ratio: formattedRatio, delegate: self)
        cell.backgroundColor = .clear
        return cell
    }
    
    private func addRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: NSLocalizedString("Uppdaterar insulinkvoter...", comment: "Message shown while updating carb ratios"))
        refreshControl.addTarget(self, action: #selector(refreshCarbRatios), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    @objc private func refreshCarbRatios() {
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else {
            tableView.refreshControl?.endRefreshing()
            return
        }
        
        // Call the desired function
        print("Data import triggered")
        Task {
            await dataSharingVC.importCSVFiles(specificFileName: "CarbRatioSchedule.csv")
            
            // End refreshing after completion
            await MainActor.run {
                tableView.refreshControl?.endRefreshing()
                loadCarbRatios()
            }
        }
    }

    // MARK: - UITextFieldDelegate

    func textFieldDidEndEditing(_ textField: UITextField) {
        sanitizeInput(textField)
        if let cell = textField.superview?.superview as? CarbRatioCell,
           let indexPath = tableView.indexPath(for: cell),
           let text = textField.text {
            let value = Double(text) ?? 0.0  // Treat empty string as 0.0

            // Save the carb ratio and update the carbRatios dictionary
            CoreDataHelper.shared.saveCarbRatio(hour: indexPath.row, ratio: value)
            carbRatios[indexPath.row] = value

            print("Saved CR \(value) for hour \(indexPath.row)")
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        moveToNextTextField(from: textField)
        return true
    }

    private func moveToNextTextField(from textField: UITextField) {
        if let cell = textField.superview?.superview as? CarbRatioCell,
           let indexPath = tableView.indexPath(for: cell) {
            let nextRow = indexPath.row + 1
            if nextRow < 24 {
                let nextIndexPath = IndexPath(row: nextRow, section: indexPath.section)
                if let nextCell = tableView.cellForRow(at: nextIndexPath) as? CarbRatioCell {
                    nextCell.ratioTextField.becomeFirstResponder()
                } else {
                    tableView.scrollToRow(at: nextIndexPath, at: .middle, animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let nextCell = self.tableView.cellForRow(at: nextIndexPath) as? CarbRatioCell {
                            nextCell.ratioTextField.becomeFirstResponder()
                        }
                    }
                }
            } else {
                textField.resignFirstResponder()
            }
        }
    }

    private func sanitizeInput(_ textField: UITextField) {
        if let text = textField.text {
            textField.text = text.replacingOccurrences(of: ",", with: ".")
        }
    }
}

extension UIView {
    func superview<T>(of type: T.Type) -> T? {
        var view = superview
        while view != nil && !(view is T) {
            view = view?.superview
        }
        return view as? T
    }
}

import UIKit

class CarbRatioCell: UITableViewCell {
    let hourLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let ratioTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textAlignment = .right
        textField.keyboardType = .decimalPad
        textField.placeholder = "..."  // Set the default placeholder
        return textField
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(hourLabel)
        contentView.addSubview(ratioTextField)

        NSLayoutConstraint.activate([
            hourLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            hourLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ratioTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            ratioTextField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ratioTextField.widthAnchor.constraint(equalToConstant: 100)
        ])

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let nextButton = UIBarButtonItem(title: NSLocalizedString("Nästa", comment: "Nästa"), style: .plain, target: self, action: #selector(nextButtonTapped))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Klar"), style: .done, target: self, action: #selector(doneButtonTapped))
        toolbar.setItems([nextButton, flexSpace, doneButton], animated: false)
        ratioTextField.inputAccessoryView = toolbar
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(hour: String, ratio: String?, delegate: UITextFieldDelegate) {
        hourLabel.text = hour
        ratioTextField.text = ratio?.isEmpty == true ? nil : ratio  // If ratio is empty, show placeholder
        ratioTextField.delegate = delegate
    }

    @objc private func nextButtonTapped() {
        if let tableView = findSuperView(of: UITableView.self),
           let indexPath = tableView.indexPath(for: self) {
            let nextRow = indexPath.row + 1
            if nextRow < 24 {
                let nextIndexPath = IndexPath(row: nextRow, section: indexPath.section)
                if let nextCell = tableView.cellForRow(at: nextIndexPath) as? CarbRatioCell {
                    nextCell.ratioTextField.becomeFirstResponder()
                } else {
                    tableView.scrollToRow(at: nextIndexPath, at: .middle, animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let nextCell = tableView.cellForRow(at: nextIndexPath) as? CarbRatioCell {
                            nextCell.ratioTextField.becomeFirstResponder()
                        }
                    }
                }
            } else {
                ratioTextField.resignFirstResponder()
            }
        }
    }

    @objc private func doneButtonTapped() {
        ratioTextField.resignFirstResponder()
    }

    private func findSuperView<T>(of type: T.Type) -> T? {
        var view = superview
        while view != nil && !(view is T) {
            view = view?.superview
        }
        return view as? T
    }
}
