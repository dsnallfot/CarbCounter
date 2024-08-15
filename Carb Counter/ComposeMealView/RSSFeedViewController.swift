import UIKit
import CoreData

class RSSFeedViewController: UIViewController {
    weak var delegate: RSSFeedDelegate?
    
    var tableView: UITableView!
    var rssItems: [RSSItem] = []
    var foodItems: [FoodItem] = []
    let excludedWords = ["med", "samt", "olika", "och pålägg", "kalla", "serveras", "het", "i", "pålägg", "kokosmjölk", "grönpeppar"]
    var offset = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // Setup gradient view and close button
        setupGradientView()
        setupCloseButton()
        
        title = NSLocalizedString("Skolmaten Vecka --", comment: "Skolmaten Vecka --")
        setupNavigationBar()
        setupTableView()
        fetchRSSFeed()
        fetchFoodItems()
    }
    
    private func setupGradientView() {
        let colors: [CGColor] = [
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        ]
        let gradientView = GradientView(colors: colors)
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)
        
        NSLayoutConstraint.activate([
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupCloseButton() {
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
    }
    
    private func setupNavigationBar() {
        let leftChevron = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(decrementOffset))
        let rightChevron = UIBarButtonItem(image: UIImage(systemName: "chevron.right"), style: .plain, target: self, action: #selector(incrementOffset))
        navigationItem.rightBarButtonItems = [rightChevron, leftChevron]
    }
    
    @objc private func decrementOffset() {
        offset -= 1
        fetchRSSFeed()
    }
    
    @objc private func incrementOffset() {
        offset += 1
        fetchRSSFeed()
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = .clear
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func fetchRSSFeed() {
        guard var schoolFoodURL = UserDefaultsRepository.schoolFoodURL else {
            print("Schoolfood URL is missing")
            return
        }
        
        schoolFoodURL += "/?offset=\(offset)"
        
        NetworkManager.shared.fetchRSSFeed(url: schoolFoodURL) { data in
            guard let data = data else { return }
            let parser = RSSParser()
            if let items = parser.parse(data: data), let firstItem = items.first {
                if let weekOfYear = Calendar(identifier: .iso8601).dateComponents([.weekOfYear], from: firstItem.date).weekOfYear {
                    DispatchQueue.main.async {
                        self.rssItems = items
                        self.title = "Skolmaten Vecka \(weekOfYear)"
                        self.tableView.reloadData()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.title = "Skolmaten Vecka --"
                        self.rssItems = []
                        self.tableView.reloadData()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.title = "Skolmaten Vecka --"
                    self.rssItems = []
                    self.tableView.reloadData()
                    print("Failed to parse RSS feed or no items found")
                }
            }
        }
    }
    
    private func fetchFoodItems() {
        let context = CoreDataStack.shared.context
        let request: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        
        do {
            foodItems = try context.fetch(request)
        } catch {
            print("Failed to fetch food items: \(error)")
        }
    }
    // MARK: Adjust Fuzziness here
    private func fuzzySearch(query: String, in items: [FoodItem]) -> [FoodItem] {
        return items.filter {
            let name = $0.name ?? ""
            return name.fuzzyMatch(query) > 0.2 || name.containsIgnoringCase(query) || query.containsIgnoringCase(name)
        }
    }

    private func parseCourseDescription(_ description: String) -> [String] {
        let separators = CharacterSet(charactersIn: ", ")
        let components = description.components(separatedBy: separators)
        
        var parsedComponents: [String] = []
        var currentComponent = ""
        
        for component in components {
            let trimmedComponent = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if excludedWords.contains(trimmedComponent.lowercased()) {
                if !currentComponent.isEmpty {
                    parsedComponents.append(currentComponent.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentComponent = ""
                }
            } else {
                if !currentComponent.isEmpty {
                    currentComponent += " "
                }
                currentComponent += trimmedComponent
            }
        }
        
        if !currentComponent.isEmpty {
            parsedComponents.append(currentComponent.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return parsedComponents
    }
}

extension RSSFeedViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 5 // Måndag to Fredag
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let weekdayItems = rssItems.filter {
            let calendar = Calendar(identifier: .iso8601)
            return calendar.component(.weekday, from: $0.date) == section + 2 // Måndag is 2, Tisdag is 3, ..., Fredag is 6
        }
        return max(1, weekdayItems.flatMap { $0.courses }.count)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale(identifier: "sv_SE")
        guard let year = rssItems.first?.date.year else { return nil }
        guard let date = calendar.date(from: DateComponents(weekday: section + 2, weekOfYear: calendar.component(.weekOfYear, from: rssItems.first?.date ?? Date()), yearForWeekOfYear: year)) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE dd MMM yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: date).capitalized
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.backgroundColor = .clear
        let weekdayItems = rssItems.filter {
            let calendar = Calendar(identifier: .iso8601)
            return calendar.component(.weekday, from: $0.date) == indexPath.section + 2 // Måndag is 2, Tisdag is 3, ..., Fredag is 6
        }
        if weekdayItems.isEmpty || weekdayItems.first?.courses.isEmpty == true {
            cell.textLabel?.text = "Måltidsinformation saknas"
            cell.backgroundColor = .clear
        } else {
            let courses = weekdayItems.flatMap { $0.courses }
            cell.textLabel?.text = courses[indexPath.row].replacingOccurrences(of: "<br/>", with: "\n")
            cell.backgroundColor = .clear
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        label.font = UIFont.boldSystemFont(ofSize: 16)
        
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale(identifier: "sv_SE")
        guard let year = rssItems.first?.date.year else { return nil }
        guard let date = calendar.date(from: DateComponents(weekday: section + 2, weekOfYear: calendar.component(.weekOfYear, from: rssItems.first?.date ?? Date()), yearForWeekOfYear: year)) else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE dd MMM yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        var dateText = formatter.string(from: date).capitalized
        
        // Offset the date by "value: -X" days for testing
        if let offsetDate = calendar.date(byAdding: .day, value: -0, to: date), calendar.isDateInToday(offsetDate) {
            label.textColor = .orange
            dateText = "Dagens lunch • \(dateText)" // Add the prefix if the date is today
        } else {
            label.textColor = .gray // Default color for other days
        }
        
        label.text = dateText
        
        headerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8)
        ])
        
        return headerView
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let weekdayItems = rssItems.filter {
            let calendar = Calendar(identifier: .iso8601)
            return calendar.component(.weekday, from: $0.date) == indexPath.section + 2 // Måndag is 2, Tisdag is 3, ..., Fredag is 6
        }
        let courses = weekdayItems.flatMap { $0.courses }
        let selectedCourse = courses[indexPath.row]
        let parsedWords = parseCourseDescription(selectedCourse)
        
        var matchedFoodItems: Set<FoodItem> = []  // Using a set to avoid duplicates
        
        for word in parsedWords {
            let matchedItems = fuzzySearch(query: word, in: foodItems)
            var bestSPrefixMatch: (FoodItem, Double)?
            var bestMatch: (FoodItem, Double)?
            
            for item in matchedItems {
                if let itemName = item.name {
                    let score = itemName.fuzzyMatch(word)
                    if itemName.hasPrefix("Ⓢ") {
                        if let currentBestSPrefixMatch = bestSPrefixMatch {
                            if currentBestSPrefixMatch.1 < score {
                                bestSPrefixMatch = (item, score)
                            }
                        } else {
                            bestSPrefixMatch = (item, score)
                        }
                    } else {
                        if let currentBestMatch = bestMatch {
                            if currentBestMatch.1 < score {
                                bestMatch = (item, score)
                            }
                        } else {
                            bestMatch = (item, score)
                        }
                    }
                }
            }
            
            if let bestSPrefixMatch = bestSPrefixMatch {
                matchedFoodItems.insert(bestSPrefixMatch.0)
            } else if let bestMatch = bestMatch {
                matchedFoodItems.insert(bestMatch.0)
            }
        }
        
        // Always add "Mjölk" and "Ⓢ Blandade grönsaker (ej majs & ärtor)" if they exist
        if let milkItem = foodItems.first(where: { $0.name == "Mjölk" }) {
            matchedFoodItems.insert(milkItem)
        }
        if let mixedVegetablesItem = foodItems.first(where: { $0.name == "Ⓢ Blandade grönsaker (ej majs & ärtor)" }) {
            matchedFoodItems.insert(mixedVegetablesItem)
        }
        
        print("Matched food items: \(matchedFoodItems)")
        
        delegate?.didSelectFoodItems(Array(matchedFoodItems))
        dismiss(animated: true, completion: nil)
    }
}

protocol RSSFeedDelegate: AnyObject {
    func didSelectFoodItems(_ foodItems: [FoodItem])
}
