import UIKit

class StartDoseViewController: UITableViewController, UITextFieldDelegate {
    var startDoses: [Int: Double] = [:]
    var clearButton: UIBarButtonItem!
    var doneButton: UIBarButtonItem!
    
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
        
        title = NSLocalizedString("Startdoser", comment: "Startdoser")
        tableView.register(StartDoseCell.self, forCellReuseIdentifier: "StartDoseCell")
        loadStartDoses()
        
        // Add Done button to the navigation bar
        doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Klar"), style: .done, target: self, action: #selector(doneButtonTapped))
        navigationItem.rightBarButtonItem = doneButton
        
        // Setup Clear button
        clearButton = UIBarButtonItem(title: NSLocalizedString("Rensa", comment: "Rensa"), style: .plain, target: self, action: #selector(clearButtonTapped))
        clearButton.tintColor = .red
        navigationItem.rightBarButtonItem = clearButton
        
        // Listen for changes to allowDataClearing setting
        NotificationCenter.default.addObserver(self, selector: #selector(updateClearButtonVisibility), name: Notification.Name("AllowDataClearingChanged"), object: nil)
        
        // Update Clear button visibility based on the current setting
        updateClearButtonVisibility()
        
        // Instantiate DataSharingViewController programmatically
        dataSharingVC = DataSharingViewController()
        
        addRefreshControl()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func updateClearButtonVisibility() {
        clearButton.isHidden = !UserDefaultsRepository.allowDataClearing
    }
    
    @objc private func updateDoneButtonVisibility() {
        doneButton.isHidden = UserDefaultsRepository.allowDataClearing
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadStartDoses()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else { return }
        
        // Call the desired function
        Task {
            print("Startdoses export triggered")
            await dataSharingVC.exportStartDoseScheduleToCSV()

        }
    }
    
    private func loadStartDoses() {
        startDoses = CoreDataHelper.shared.fetchStartDoses()
        tableView.reloadData()
    }
    
    @objc private func doneButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func clearButtonTapped() {
        let alertController = UIAlertController(title: NSLocalizedString("Rensa", comment: "Rensa"), message: NSLocalizedString("Är du säker på att du vill rensa all data?", comment: "Är du säker på att du vill rensa all data?"), preferredStyle: .actionSheet)
        let yesAction = UIAlertAction(title: NSLocalizedString("Ja", comment: "Ja"), style: .destructive) { _ in
            CoreDataHelper.shared.clearAllStartDoses()
            self.loadStartDoses()
        }
        let noAction = UIAlertAction(title: NSLocalizedString("Nej", comment: "Nej"), style: .cancel, handler: nil)
        
        alertController.addAction(yesAction)
        alertController.addAction(noAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 24
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StartDoseCell", for: indexPath) as! StartDoseCell
        let hour = String(format: "%02d:00", indexPath.row)
        let dose = startDoses[indexPath.row] ?? 0.0
        
        // Display an empty string if dose is 0.0, otherwise format the dose
        let formattedDose = dose == 0.0 ? nil : (dose.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", dose) : String(format: "%.1f", dose))
        
        cell.configure(hour: hour, dose: formattedDose, delegate: self)
        cell.backgroundColor = .clear
        return cell
    }
    
    private func addRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: NSLocalizedString("Uppdaterar startdoser...", comment: "Message shown while updating start doses"))
        refreshControl.addTarget(self, action: #selector(refreshStartDoses), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    @objc private func refreshStartDoses() {
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else {
            tableView.refreshControl?.endRefreshing()
            return
        }
        
        // Call the desired function
        print("Data import triggered")
        Task {
            await dataSharingVC.importCSVFiles(specificFileName: "StartDoseSchedule.csv")
            
            // End refreshing after completion
            await MainActor.run {
                tableView.refreshControl?.endRefreshing()
                loadStartDoses()
            }
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        sanitizeInput(textField)
        if let cell = textField.superview?.superview as? StartDoseCell,
           let indexPath = tableView.indexPath(for: cell) {
            let text = textField.text ?? ""
            let value = Double(text) ?? 0.0  // Treat empty string as 0.0
            
            if value == 0.0 {
                CoreDataHelper.shared.deleteStartDose(hour: indexPath.row)
                startDoses[indexPath.row] = nil
            } else {
                CoreDataHelper.shared.saveStartDose(hour: indexPath.row, dose: value)
                startDoses[indexPath.row] = value
            }
            
            tableView.reloadRows(at: [indexPath], with: .automatic)
            print("Saved start dose \(value) for hour \(indexPath.row)")
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        moveToNextTextField(from: textField)
        return true
    }
    
    private func moveToNextTextField(from textField: UITextField) {
        if let cell = textField.superview?.superview as? StartDoseCell,
           let indexPath = tableView.indexPath(for: cell) {
            let nextRow = indexPath.row + 1
            if nextRow < 24 {
                let nextIndexPath = IndexPath(row: nextRow, section: indexPath.section)
                if let nextCell = tableView.cellForRow(at: nextIndexPath) as? StartDoseCell {
                    nextCell.doseTextField.becomeFirstResponder()
                } else {
                    tableView.scrollToRow(at: nextIndexPath, at: .middle, animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let nextCell = self.tableView.cellForRow(at: nextIndexPath) as? StartDoseCell {
                            nextCell.doseTextField.becomeFirstResponder()
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

class StartDoseCell: UITableViewCell {
    let hourLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let doseTextField: UITextField = {
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
        contentView.addSubview(doseTextField)
        
        NSLayoutConstraint.activate([
            hourLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            hourLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            doseTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            doseTextField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            doseTextField.widthAnchor.constraint(equalToConstant: 100)
        ])
        
        // Add toolbar with "Next" and "Done" buttons to the keyboard
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let nextButton = UIBarButtonItem(title: NSLocalizedString("Nästa", comment: "Nästa"), style: .plain, target: self, action: #selector(nextButtonTapped))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Klar"), style: .done, target: self, action: #selector(doneButtonTapped))
        toolbar.setItems([nextButton, flexSpace, doneButton], animated: false)
        doseTextField.inputAccessoryView = toolbar
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(hour: String, dose: String?, delegate: UITextFieldDelegate) {
        hourLabel.text = hour
        doseTextField.text = dose?.isEmpty == true ? nil : dose  // If dose is empty, show placeholder
        doseTextField.delegate = delegate
    }
    
    @objc private func nextButtonTapped() {
        if let tableView = findSuperView(of: UITableView.self),
           let indexPath = tableView.indexPath(for: self) {
            let nextRow = indexPath.row + 1
            if nextRow < 24 {
                let nextIndexPath = IndexPath(row: nextRow, section: indexPath.section)
                if let nextCell = tableView.cellForRow(at: nextIndexPath) as? StartDoseCell {
                    nextCell.doseTextField.becomeFirstResponder()
                } else {
                    tableView.scrollToRow(at: nextIndexPath, at: .middle, animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let nextCell = tableView.cellForRow(at: nextIndexPath) as? StartDoseCell {
                            nextCell.doseTextField.becomeFirstResponder()
                        }
                    }
                }
            } else {
                doseTextField.resignFirstResponder()
            }
        }
    }
    
    @objc private func doneButtonTapped() {
        doseTextField.resignFirstResponder()
    }
    
    private func findSuperView<T>(of type: T.Type) -> T? {
        var view = superview
        while view != nil && !(view is T) {
            view = view?.superview
        }
        return view as? T
    }
}
