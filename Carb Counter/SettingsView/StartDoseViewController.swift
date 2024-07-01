import UIKit

class StartDoseViewController: UITableViewController, UITextFieldDelegate {
    var startDoses: [Int: Double] = [:]
    var clearButton: UIBarButtonItem!
    var doneButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Startdoser"
        tableView.register(StartDoseCell.self, forCellReuseIdentifier: "StartDoseCell")
        loadStartDoses()
        
        // Add Done button to the navigation bar
        doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
        navigationItem.rightBarButtonItem = doneButton
        
        // Setup Clear button
                clearButton = UIBarButtonItem(title: "Rensa", style: .plain, target: self, action: #selector(clearButtonTapped))
                clearButton.tintColor = .red
                navigationItem.rightBarButtonItem = clearButton
                
                // Listen for changes to allowDataClearing setting
                NotificationCenter.default.addObserver(self, selector: #selector(updateClearButtonVisibility), name: Notification.Name("AllowDataClearingChanged"), object: nil)
                
                // Update Clear button visibility based on the current setting
                updateClearButtonVisibility()
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
    
    private func loadStartDoses() {
        startDoses = CoreDataHelper.shared.fetchStartDoses()
        tableView.reloadData()
    }
    
    @objc private func doneButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func clearButtonTapped() {
        let alertController = UIAlertController(title: "Rensa", message: "Är du säker på att du vill rensa all data?", preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "Ja", style: .destructive) { _ in
            CoreDataHelper.shared.clearAllStartDoses()
            self.loadStartDoses()
        }
        let noAction = UIAlertAction(title: "Nej", style: .cancel, handler: nil)
        
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
        let formattedDose = dose.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", dose) : String(format: "%.1f", dose)
        cell.configure(hour: hour, dose: formattedDose, delegate: self)
        return cell
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        sanitizeInput(textField)
        if let cell = textField.superview?.superview as? StartDoseCell,
           let indexPath = tableView.indexPath(for: cell),
           let text = textField.text, let value = Double(text) {
            CoreDataHelper.shared.saveStartDose(hour: indexPath.row, dose: value)
            startDoses[indexPath.row] = value
            print("Saved start dose \(value) for hour \(indexPath.row)")
            
            if let startDoseSchedule = CoreDataHelper.shared.fetchStartDoseSchedule(hour: indexPath.row) {
                CloudKitShareController.shared.shareStartDoseScheduleRecord(startDoseSchedule: startDoseSchedule) { share, error in
                    if let error = error {
                        print("Error sharing start dose schedule: \(error)")
                    } else if let share = share {
                        print("Share URL: \(share.url?.absoluteString ?? "No URL")")
                    }
                }
            }
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
                    // Scroll to make the next cell visible and then make the text field the first responder
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
        let nextButton = UIBarButtonItem(title: "Nästa", style: .plain, target: self, action: #selector(nextButtonTapped))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
        toolbar.setItems([nextButton, flexSpace, doneButton], animated: false)
        doseTextField.inputAccessoryView = toolbar
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(hour: String, dose: String, delegate: UITextFieldDelegate) {
        hourLabel.text = hour
        doseTextField.text = dose
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
                    // Scroll to make the next cell visible and then make the text field the first responder
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
