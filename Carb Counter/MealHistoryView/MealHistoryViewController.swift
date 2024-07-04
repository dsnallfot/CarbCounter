import UIKit
import CoreData

class MealHistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var tableView: UITableView!
    var mealHistories: [MealHistory] = []
    var filteredMealHistories: [MealHistory] = []
    var datePicker: UIDatePicker!
    
    var dataSharingVC: DataSharingViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Måltidshistorik"
        view.backgroundColor = .systemBackground
        setupDatePicker()
        setupTableView()
        fetchMealHistories()
        
        // Add Cancel button to the navigation bar
        let cancelButton = UIBarButtonItem(title: "Avbryt", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = cancelButton
        
        // Instantiate DataSharingViewController programmatically
        dataSharingVC = DataSharingViewController()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchMealHistories()
        
        // Set the back button title for the next view controller
        let backButton = UIBarButtonItem()
        backButton.title = "Historik"
        navigationItem.backBarButtonItem = backButton
    }
    
    @objc private func cancelButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupDatePicker() {
        datePicker = UIDatePicker()
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.addTarget(self, action: #selector(datePickerValueChanged), for: .valueChanged)
        
        view.addSubview(datePicker)
        
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    @objc private func datePickerValueChanged() {
        filterMealHistories(by: datePicker.date)
    }
    
    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MealHistoryCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 8),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func fetchMealHistories() {
        let context = CoreDataStack.shared.context
        let fetchRequest = NSFetchRequest<MealHistory>(entityName: "MealHistory")
        let sortDescriptor = NSSortDescriptor(key: "mealDate", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            mealHistories = try context.fetch(fetchRequest)
            filteredMealHistories = mealHistories
            tableView.reloadData()
        } catch {
            print("Failed to fetch meal histories: \(error)")
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredMealHistories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "MealHistoryCell")
        let mealHistory = filteredMealHistories[indexPath.row]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let mealDateStr = dateFormatter.string(from: mealHistory.mealDate ?? Date())
        
        cell.textLabel?.text = mealDateStr
        
        var detailText = ""
        if mealHistory.totalNetCarbs > 0 {
            let carbs = mealHistory.totalNetCarbs.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", mealHistory.totalNetCarbs) :
                String(format: "%.1f", mealHistory.totalNetCarbs)
            detailText += "Kolhydrater: \(carbs) g"
        }
        if mealHistory.totalNetFat > 0 {
            if !detailText.isEmpty { detailText += " • " }
            let fat = mealHistory.totalNetFat.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", mealHistory.totalNetFat) :
                String(format: "%.1f", mealHistory.totalNetFat)
            detailText += "Fett: \(fat) g"
        }
        if mealHistory.totalNetProtein > 0 {
            if !detailText.isEmpty { detailText += " • " }
            let protein = mealHistory.totalNetProtein.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", mealHistory.totalNetProtein) :
                String(format: "%.1f", mealHistory.totalNetProtein)
            detailText += "Protein: \(protein) g"
        }
        cell.detailTextLabel?.text = detailText
        cell.detailTextLabel?.textColor = .gray
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Radera") { (action, view, completionHandler) in
            let alert = UIAlertController(title: "Radera måltidshistorik", message: "Vill du radera denna måltid från historiken?", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { _ in
                completionHandler(false) // Dismiss the swipe action
            }))
            alert.addAction(UIAlertAction(title: "Ja", style: .destructive, handler: { _ in
                let mealHistory = self.filteredMealHistories[indexPath.row]
                let context = CoreDataStack.shared.context
                context.delete(mealHistory)
                // Ensure dataSharingVC is instantiated
                guard let dataSharingVC = self.dataSharingVC else { return }

                        // Call the desired function
                        dataSharingVC.exportMealHistoryToCSV()
                print("Meal history export triggered")
                
                do {
                    try context.save()
                    self.mealHistories.removeAll { $0 == mealHistory }
                    self.filteredMealHistories.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                } catch {
                    print("Failed to delete meal history: \(error)")
                }
                completionHandler(true) // Perform the delete action
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mealHistory = filteredMealHistories[indexPath.row]
        let detailVC = MealHistoryDetailViewController()
        detailVC.mealHistory = mealHistory
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    private func filterMealHistories(by date: Date) {
        filteredMealHistories = mealHistories.filter { mealHistory in
            if let mealDate = mealHistory.mealDate {
                return Calendar.current.isDate(mealDate, inSameDayAs: date)
            }
            return false
        }
        tableView.reloadData()
    }
}
