import UIKit

class CarbRatioViewController: UITableViewController, UITextFieldDelegate {
    
    var carbRatios: [Int: Double] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        carbRatios = CoreDataHelper.shared.fetchCarbRatios()
        title = "Carb Ratio Schema"
        tableView.register(CarbRatioCell.self, forCellReuseIdentifier: "CarbRatioCell")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 24
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CarbRatioCell", for: indexPath) as! CarbRatioCell
        let hour = String(format: "%02d:00", indexPath.row)
        let ratio = carbRatios[indexPath.row] ?? 0.0
        cell.configure(hour: hour, ratio: ratio, delegate: self)
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
                    // Scroll to make the next cell visible and then make the text field the first responder
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
        
        // Add toolbar with "Next" and "Done" buttons to the keyboard
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
    
    func configure(hour: String, ratio: Double, delegate: UITextFieldDelegate) {
        hourLabel.text = hour
        ratioTextField.text = String(ratio)
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
                    // Scroll to make the next cell visible and then make the text field the first responder
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
