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
        title = NSLocalizedString("Måltidshistorik", comment: "Title for Meal History screen")
        view.backgroundColor = .systemBackground
        
        // Create the gradient view
        let colors: [CGColor] = [
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        ]
        let gradientView = GradientView(colors: colors)
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the gradient view to the main view
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)
        
        // Set up constraints for the gradient view
        NSLayoutConstraint.activate([
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        setupDatePicker()
        setupTableView()
        fetchMealHistories()
        
        // Instantiate DataSharingViewController programmatically
        dataSharingVC = DataSharingViewController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchMealHistories()
        
        // Set the back button title for the next view controller
        let backButton = UIBarButtonItem()
        backButton.title = NSLocalizedString("Historik", comment: "Back button title for history")
        navigationItem.backBarButtonItem = backButton
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
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MealHistoryCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 8),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90),
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
            let mealHistories = try context.fetch(fetchRequest)
            DispatchQueue.main.async {
                self.mealHistories = mealHistories
                self.filteredMealHistories = mealHistories
                self.tableView.reloadData()
            }
        } catch {
            DispatchQueue.main.async {
                print("Failed to fetch meal histories: \(error.localizedDescription)")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredMealHistories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "MealHistoryCell")
        cell.backgroundColor = .clear // Set cell background to clear
        let mealHistory = filteredMealHistories[indexPath.row]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM HH:mm"
        let mealDateStr = dateFormatter.string(from: mealHistory.mealDate ?? Date())
        
        var detailText = ""
        
        if mealHistory.totalNetCarbs > 0 {
            let carbs = mealHistory.totalNetCarbs
            detailText += String(format: NSLocalizedString("Kh %.1f g", comment: "Carbs amount format"), carbs)
        }
        
        if mealHistory.totalNetFat > 0 {
            if !detailText.isEmpty { detailText += " • " }
            let fat = mealHistory.totalNetFat
            detailText += String(format: NSLocalizedString("Fett %.1f g", comment: "Fat amount format"), fat)
        }
        
        if mealHistory.totalNetProtein > 0 {
            if !detailText.isEmpty { detailText += " • " }
            let protein = mealHistory.totalNetProtein
            detailText += String(format: NSLocalizedString("Protein %.1f g", comment: "Protein amount format"), protein)
        }
        
        // Collect food item names
        let foodItemNames = (mealHistory.foodEntries?.allObjects as? [FoodItemEntry])?.compactMap { $0.entryName } ?? []
        let foodItemNamesStr = foodItemNames.joined(separator: " • ")
        
        // Update the cell text
        cell.textLabel?.text = foodItemNamesStr
        cell.detailTextLabel?.text = "[\(mealDateStr)]  \(detailText)"
        cell.detailTextLabel?.textColor = .gray
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { (action, view, completionHandler) in
            let alert = UIAlertController(
                title: NSLocalizedString("Radera måltidshistorik", comment: "Delete meal history title"),
                message: NSLocalizedString("Bekräfta att du vill radera denna måltid från historiken?", comment: "Delete meal history confirmation"),
                preferredStyle: .actionSheet)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel deletion"), style: .cancel, handler: { _ in
                completionHandler(false) // Dismiss the swipe action
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Radera", comment: "Confirm deletion"), style: .destructive, handler: { _ in
                let mealHistory = self.filteredMealHistories[indexPath.row]
                let context = CoreDataStack.shared.context
                context.delete(mealHistory)
                
                // Ensure dataSharingVC is instantiated
                guard let dataSharingVC = self.dataSharingVC else { return }
                
                // Call the desired function
                Task {
                    print(NSLocalizedString("Meal history export triggered", comment: "Log message for exporting meal history"))
                    await dataSharingVC.exportMealHistoryToCSV()
                }
                
                do {
                    try context.save()
                    self.mealHistories.removeAll { $0 == mealHistory }
                    self.filteredMealHistories.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                } catch {
                    print(String(format: NSLocalizedString("Failed to delete meal history: %@", comment: "Log message for failed meal history deletion"), error.localizedDescription))
                }
                completionHandler(true) // Perform the delete action
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
        deleteAction.image = UIImage(systemName: "trash.fill")
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
