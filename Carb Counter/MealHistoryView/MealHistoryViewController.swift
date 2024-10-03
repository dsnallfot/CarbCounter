import UIKit
import CoreData

class MealHistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIPopoverPresentationControllerDelegate {
    
    var tableView: UITableView!
    var tableViewBottomConstraint: NSLayoutConstraint!
    var mealHistories: [MealHistory] = []
    var filteredMealHistories: [MealHistory] = []
    private var searchBar: UISearchBar = {
            let searchBar = UISearchBar()
            searchBar.placeholder = NSLocalizedString("Sök livsmedel", comment: "Search Food Item placeholder")
            searchBar.translatesAutoresizingMaskIntoConstraints = false
            searchBar.backgroundImage = UIImage()
            if let textField = searchBar.value(forKey: "searchField") as? UITextField {
                textField.tintColor = .label
                textField.autocorrectionType = .no
                textField.spellCheckingType = .no
                textField.backgroundColor = UIColor.systemGray2.withAlphaComponent(0.2)
                textField.layer.cornerRadius = 8
                textField.layer.masksToBounds = true
            }
            return searchBar
        }()
    
    var datePicker: UIDatePicker!
    
    var dataSharingVC: DataSharingViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Historik", comment: "Title for Meal History screen")
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
        setupSearchBarAndDatePicker()
        setupTableView()
        
        // Add an info button in the navigation bar
                let infoButton = UIBarButtonItem(image: UIImage(systemName: "wand.and.rays"), style: .plain, target: self, action: #selector(navigateToMealInsights))
                navigationItem.rightBarButtonItem = infoButton
        
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
        
        // Re-add the observers every time the view appears
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Remove the observers when the view disappears
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)

        // Dismiss the keyboard when navigating away from the view controller
        searchBar.resignFirstResponder()}
    
    private func setupSearchBarAndDatePicker() {
        // Create a container UIStackView to hold the search bar, date picker, and reset button
        let hStackView = UIStackView()
        hStackView.axis = .horizontal
        hStackView.distribution = .fill
        hStackView.alignment = .center
        hStackView.spacing = 8
        hStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Initialize the searchBar
        searchBar = UISearchBar()
        searchBar.placeholder = NSLocalizedString("Sök i historiken", comment: "Search Food Item history")
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.backgroundImage = UIImage() // Make background clear
        
        // Set content hugging and compression resistance priorities to keep the search bar visible
        searchBar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchBar.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .sentences
            textField.spellCheckingType = .yes
            textField.inputAssistantItem.leadingBarButtonGroups = []
            textField.inputAssistantItem.trailingBarButtonGroups = []

            // Add toolbar with custom buttons
            let toolbar = UIToolbar()
            toolbar.sizeToFit()

            // Cancel button to dismiss the keyboard
            let symbolImage = UIImage(systemName: "keyboard.chevron.compact.down")
            let cancelButton = UIButton(type: .system)
            cancelButton.setImage(symbolImage, for: .normal)
            cancelButton.tintColor = .label
            cancelButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
            cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
            let cancelBarButtonItem = UIBarButtonItem(customView: cancelButton)

            // Flexible space to align done button on the right
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            
            // Done button to complete editing
            let doneButton = UIBarButtonItem(title: NSLocalizedString("Klar", comment: "Done button"), style: .done, target: self, action: #selector(doneButtonTapped))
            
            // Add buttons to the toolbar
            toolbar.setItems([cancelBarButtonItem, flexSpace, doneButton], animated: false)
            textField.inputAccessoryView = toolbar
        }
        
        // Initialize the compact datePicker
        datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.addTarget(self, action: #selector(datePickerValueChanged), for: .valueChanged)
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        // Initialize the reset button
        let resetButton = UIButton(type: .system)
        resetButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        resetButton.tintColor = .systemGray
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.addTarget(self, action: #selector(resetFilters), for: .touchUpInside)
        
        // Set the image size for the reset button
        resetButton.imageView?.contentMode = .scaleAspectFit
        resetButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        // Add the searchBar, datePicker, and reset button to the hStackView
        hStackView.addArrangedSubview(searchBar)
        hStackView.addArrangedSubview(datePicker)
        hStackView.addArrangedSubview(resetButton)
        
        // Add hStackView to the view and set its constraints
        view.addSubview(hStackView)
        
        NSLayoutConstraint.activate([
            hStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            hStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            hStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            searchBar.heightAnchor.constraint(equalToConstant: 40),
            datePicker.widthAnchor.constraint(equalToConstant: 120),
            resetButton.widthAnchor.constraint(equalToConstant: 20),
            resetButton.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    @objc private func cancelButtonTapped() {
        searchBar.resignFirstResponder()
    }

    @objc private func doneButtonTapped() {
        searchBar.resignFirstResponder()
    }

    @objc private func resetFilters() {
        datePicker.date = Date()
        datePickerValueChanged()
        tableView.reloadData()

        searchBar.resignFirstResponder()
    }
    
    @objc private func datePickerValueChanged() {
        // Get the saved search text and filter by both search text and date
        let savedSearchText = UserDefaultsRepository.savedHistorySearchText
        filterMealHistories(searchText: savedSearchText, by: datePicker.date)
    }
    
    private func setupTableView() {
            tableView = UITableView()
            tableView.translatesAutoresizingMaskIntoConstraints = false
            tableView.delegate = self
            tableView.dataSource = self
            tableView.backgroundColor = .clear
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MealHistoryCell")
            view.addSubview(tableView)
            
            tableViewBottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90)
            
            NSLayoutConstraint.activate([
                tableView.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 8),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableViewBottomConstraint
            ])
        }
    
    @objc func keyboardWillShow(notification: NSNotification) {
            if let userInfo = notification.userInfo {
                if let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    tableViewBottomConstraint.constant = -keyboardFrame.height + 2
                    view.layoutIfNeeded()
                }
            }
        }
    
    @objc func keyboardWillHide(notification: NSNotification) {
            tableViewBottomConstraint.constant = -90 // Reset to the original value when the keyboard hides
            view.layoutIfNeeded()
        }
    
    private func fetchMealHistories() {
        let context = CoreDataStack.shared.context
        let fetchRequest = NSFetchRequest<MealHistory>(entityName: "MealHistory")
        let sortDescriptor = NSSortDescriptor(key: "mealDate", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Add a predicate to filter out items where the delete flag is true
        fetchRequest.predicate = NSPredicate(format: "delete == NO OR delete == nil")
        
        do {
            let mealHistories = try context.fetch(fetchRequest)
            DispatchQueue.main.async {
                self.mealHistories = mealHistories // Update the mealHistories array
                
                // Apply filtering based on both search text and date
                let savedSearchText = UserDefaultsRepository.savedHistorySearchText
                self.filterMealHistories(searchText: savedSearchText, by: self.datePicker.date)
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
            detailText += String(format: NSLocalizedString("KH %.0f g", comment: "Carbs amount format"), carbs)
        }

        if mealHistory.totalNetFat > 0 {
            if !detailText.isEmpty { detailText += " | " }
            let fat = mealHistory.totalNetFat
            detailText += String(format: NSLocalizedString("Fett %.0f g", comment: "Fat amount format"), fat)
        }

        if mealHistory.totalNetProtein > 0 {
            if !detailText.isEmpty { detailText += " | " }
            let protein = mealHistory.totalNetProtein
            detailText += String(format: NSLocalizedString("Protein %.0f g", comment: "Protein amount format"), protein)
        }

        if mealHistory.totalNetBolus > 0 {
            if !detailText.isEmpty { detailText += " | " }
            let bolus = mealHistory.totalNetBolus
            detailText += String(format: NSLocalizedString("Bolus %.2f E", comment: "Bolus amount format"), bolus)
        }

        // Collect food item names
        let foodItemNames = (mealHistory.foodEntries?.allObjects as? [FoodItemEntry])?.compactMap { $0.entryName } ?? []
        let foodItemNamesStr = foodItemNames.joined(separator: " | ")

        // Fetch user-defined special items from UserDefaults
        let userTopUps = UserDefaults.standard.string(forKey: "topUps") ?? ""
        let specialItems = userTopUps.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        // Check if any of the food items contain a carbs top-up item
        let containsSpecialItem = foodItemNames.contains { item in
            specialItems.contains { specialItem in
                item.localizedCaseInsensitiveContains(specialItem)
            }
        }

        // Update the cell text and add the emoji if the condition is met
        if containsSpecialItem {
            cell.detailTextLabel?.text = "\(mealDateStr) |🔝\(detailText)"
        } else {
            cell.detailTextLabel?.text = "\(mealDateStr) | \(detailText)"
        }
        cell.detailTextLabel?.textColor = .gray
        cell.textLabel?.text = foodItemNamesStr

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
                Task {
                    await self.deleteMealHistory(at: indexPath)
                    completionHandler(true) // Perform the delete action
                }
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
        deleteAction.image = UIImage(systemName: "trash.fill")
        
        let editAction = UIContextualAction(style: .normal, title: nil) { (action, view, completionHandler) in
            self.presentEditPopover(for: indexPath)
            completionHandler(true)
        }
        editAction.image = UIImage(systemName: "square.and.pencil")
        editAction.backgroundColor = .systemBlue
        
        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }
    
    private func deleteMealHistory(at indexPath: IndexPath) async {
        let mealHistory = filteredMealHistories[indexPath.row]
        
        // Step 1: Set the delete flag to true
        mealHistory.delete = true

        // Step 2: Export the updated list of meal histories
        guard let dataSharingVC = dataSharingVC else { return }
        print(NSLocalizedString("Meal history export triggered", comment: "Log message for exporting meal history"))
        await dataSharingVC.exportMealHistoryToCSV()

        // Step 3: Save the context with the updated delete flag
        let context = CoreDataStack.shared.context
        do {
            try context.save()

            // Step 4: Update the UI by removing the item from the visible list
            filteredMealHistories.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        } catch {
            print(String(format: NSLocalizedString("Failed to delete meal history: %@", comment: "Log message for failed meal history deletion"), error.localizedDescription))
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mealHistory = filteredMealHistories[indexPath.row]
        let detailVC = MealHistoryDetailViewController()
        detailVC.mealHistory = mealHistory
        navigationController?.pushViewController(detailVC, animated: true)
    }
    private func filterMealHistories(searchText: String? = nil, by date: Date? = nil) {
        let lowercasedSearchText = searchText?.lowercased() ?? ""
        
        // Check if the date picker is altered or if it's still at its default state (today's date)
        let isDatePickerUnaltered = Calendar.current.isDateInToday(date ?? Date())
        
        filteredMealHistories = mealHistories.filter { mealHistory in
            // First, filter by search text (if provided)
            if !lowercasedSearchText.isEmpty {
                let foodItemNames = (mealHistory.foodEntries?.allObjects as? [FoodItemEntry])?.compactMap { $0.entryName?.lowercased() } ?? []
                let matchesSearch = foodItemNames.contains { $0.contains(lowercasedSearchText) }
                
                if !matchesSearch {
                    return false // Exclude this item if search text doesn't match
                }
            }
            
            // If the date picker hasn't been altered, ignore the date filter
            if isDatePickerUnaltered {
                return true // Don't apply date filtering if date picker is unaltered
            }
            
            // Otherwise, filter by date (if provided)
            if let mealDate = mealHistory.mealDate, let filterDate = date {
                return Calendar.current.isDate(mealDate, inSameDayAs: filterDate)
            }
            
            return true // Default to include if no date filtering is applied
        }
        
        tableView.reloadData()
    }
   
    @objc private func navigateToMealInsights() {
        // Dismiss the keyboard before navigating to the next view
        searchBar.resignFirstResponder()
        
        // Create an instance of MealInsightsViewController
        let mealInsightsVC = MealInsightsViewController()

        // Pass the search text from the MealHistoryVC's search bar to MealInsightsVC
        mealInsightsVC.prepopulatedSearchText = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Push the MealInsightsViewController to the navigation stack
        navigationController?.pushViewController(mealInsightsVC, animated: true)
    }
    
    private func presentEditPopover(for indexPath: IndexPath) {
        let mealHistory = filteredMealHistories[indexPath.row]

        // Create the custom alert view controller
        let customAlertVC = CustomAlertViewController()
        customAlertVC.mealDate = mealHistory.mealDate
        customAlertVC.modalPresentationStyle = .overFullScreen
        customAlertVC.modalTransitionStyle = .crossDissolve
        customAlertVC.onSave = { [weak self] newDate in
            // Update the meal date in the meal history
            mealHistory.mealDate = newDate

            // Save to Core Data
            let context = CoreDataStack.shared.context
            do {
                try context.save()
            } catch {
                print("Failed to save updated meal date: \(error.localizedDescription)")
            }

            // Run the export function after saving the updated date
            if let dataSharingVC = self?.dataSharingVC {
                Task {
                    await dataSharingVC.exportMealHistoryToCSV()
                    print(NSLocalizedString("Meal history export triggered after updating date", comment: "Log message for exporting meal history"))
                }
            }

            // Reload table
            self?.tableView.reloadRows(at: [indexPath], with: .automatic)
        }

        present(customAlertVC, animated: true, completion: nil)
    }

    private struct AssociatedKeys {
        static var indexPath: UInt8 = 0
        static var datePicker: UInt8 = 1
    }
    
    @objc private func saveDatePickerValue(sender: UIButton) {
        guard let editVC = sender.superview?.viewController,
              let indexPath = objc_getAssociatedObject(editVC, &AssociatedKeys.indexPath) as? IndexPath,
              let datePicker = objc_getAssociatedObject(editVC, &AssociatedKeys.datePicker) as? UIDatePicker else { return }
        
        // Update the meal date in the meal history
        let mealHistory = filteredMealHistories[indexPath.row]
        mealHistory.mealDate = datePicker.date
        
        // Save to Core Data
        let context = CoreDataStack.shared.context
        do {
            try context.save()
        } catch {
            print("Failed to save updated meal date: \(error.localizedDescription)")
        }
        
        // Run the export function after saving the updated date
        if let dataSharingVC = self.dataSharingVC {
            Task {
                await dataSharingVC.exportMealHistoryToCSV()
                print(NSLocalizedString("Meal history export triggered after updating date", comment: "Log message for exporting meal history"))
            }
        }
        
        // Dismiss the popover and reload table
        dismiss(animated: true) {
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}

extension UIView {
    var viewController: UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let vc = responder as? UIViewController {
                return vc
            }
            responder = responder?.next
        }
        return nil
    }
}

extension MealHistoryViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Save the search text in UserDefaultsRepository
        UserDefaultsRepository.savedHistorySearchText = searchText.isEmpty ? nil : searchText
        
        // Filter meal histories based on the entered text and selected date
        filterMealHistories(searchText: searchText.isEmpty ? nil : searchText, by: datePicker.date)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder() // Hide the keyboard when the search button is pressed
    }
}
