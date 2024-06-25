import UIKit

class CarbRatioViewController: UITableViewController, UITextFieldDelegate {
    var carbRatios: [Int: Double] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Carb Ratio Schema"
        tableView.register(CarbRatioCell.self, forCellReuseIdentifier: "CarbRatioCell")
        loadCarbRatios()
        
        // Add Clear button to the navigation bar
        let clearButton = UIBarButtonItem(title: "Rensa", style: .plain, target: self, action: #selector(clearButtonTapped))
        clearButton.tintColor = .red
        navigationItem.rightBarButtonItem = clearButton
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCarbRatios()
    }
    
    private func loadCarbRatios() {
        carbRatios = CoreDataHelper.shared.fetchCarbRatios()
        tableView.reloadData()
    }
    
    @objc private func clearButtonTapped() {
        let alertController = UIAlertController(title: "Rensa", message: "Är du säker på att du vill rensa all data?", preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "Ja", style: .destructive) { _ in
            CoreDataHelper.shared.clearAllCarbRatios()
            self.loadCarbRatios()
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "CarbRatioCell", for: indexPath) as! CarbRatioCell
        let hour = String(format: "%02d:00", indexPath.row)
        let ratio = carbRatios[indexPath.row] ?? 0.0
        let formattedRatio = ratio.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", ratio) : String(format: "%.1f", ratio)
        cell.configure(hour: hour, ratio: formattedRatio, delegate: self)
        return cell
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        sanitizeInput(textField)
        if let cell = textField.superview?.superview as? CarbRatioCell,
           let indexPath = tableView.indexPath(for: cell),
           let text = textField.text, let value = Double(text) {
            CoreDataHelper.shared.saveCarbRatio(hour: indexPath.row, ratio: value)
            carbRatios[indexPath.row] = value
            print("Saved CR \(value) for hour \(indexPath.row)")
            
            if let carbRatioSchedule = CoreDataHelper.shared.fetchCarbRatioSchedule(hour: indexPath.row) {
                CloudKitShareController.shared.shareCarbRatioScheduleRecord(carbRatioSchedule: carbRatioSchedule) { share, error in
                    if let error = error {
                        print("Error sharing carb ratio schedule: \(error)")
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
        let nextButton = UIBarButtonItem(title: "Nästa", style: .plain, target: self, action: #selector(nextButtonTapped))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
        toolbar.setItems([nextButton, flexSpace, doneButton], animated: false)
        ratioTextField.inputAccessoryView = toolbar
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(hour: String, ratio: String, delegate: UITextFieldDelegate) {
        hourLabel.text = hour
        ratioTextField.text = ratio
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