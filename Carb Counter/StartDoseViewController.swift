import UIKit

class StartDoseViewController: UITableViewController {
    
    var startDoses: [Int: Double] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Start Dose Schedule"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        startDoses = CoreDataHelper.shared.fetchStartDoses()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 24
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let dose = startDoses[indexPath.row] ?? 0.0
        cell.textLabel?.text = "Hour \(indexPath.row): \(dose)"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let alert = UIAlertController(title: "Edit Start Dose", message: "Enter a new start dose for hour \(indexPath.row)", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.keyboardType = .decimalPad
            let dose = self.startDoses[indexPath.row] ?? 0.0
            textField.text = "\(dose)"
        }
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            if let textField = alert?.textFields?.first, let text = textField.text, let value = Double(text) {
                CoreDataHelper.shared.saveStartDose(hour: indexPath.row, dose: value)
                self?.startDoses = CoreDataHelper.shared.fetchStartDoses()
                self?.tableView.reloadData()
            }
        }
        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
