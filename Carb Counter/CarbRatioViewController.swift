import UIKit

class CarbRatioViewController: UITableViewController {
    
    var carbRatios: [Int: Double] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        carbRatios = CoreDataHelper.shared.fetchCarbRatios()
        title = "Carb Ratio Schedule"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 24
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let ratio = carbRatios[indexPath.row] ?? 0.0
        cell.textLabel?.text = "Hour \(indexPath.row): \(ratio)"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let alert = UIAlertController(title: "Edit Carb Ratio", message: "Enter a new carb ratio for hour \(indexPath.row)", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.keyboardType = .decimalPad
            let ratio = self.carbRatios[indexPath.row] ?? 0.0
            textField.text = "\(ratio)"
        }
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            if let textField = alert?.textFields?.first, let text = textField.text, let value = Double(text) {
                CoreDataHelper.shared.saveCarbRatio(hour: indexPath.row, ratio: value)
                self?.carbRatios = CoreDataHelper.shared.fetchCarbRatios()
                self?.tableView.reloadData()
            }
        }
        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
