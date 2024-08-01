import UIKit
import CoreData

class RSSFeedViewController: UIViewController {
    
    var tableView: UITableView!
    var rssItems: [RSSItem] = []
    var foodItems: [FoodItem] = []
    let excludedWords = ["med", "samt", "olika", "och", "serveras", "het", "i", "pålägg"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Veckans Skolmat"
        setupTableView()
        fetchRSSFeed()
        fetchFoodItems()
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
    
    @objc private func doneButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func fetchRSSFeed() {
        guard let schoolFoodURL = UserDefaultsRepository.schoolFoodURL else {
            print("Schoolfood URL is missing")
            return
        }
        
        NetworkManager.shared.fetchRSSFeed(url: schoolFoodURL) { data in
            guard let data = data else { return }
            let parser = RSSParser()
            if let items = parser.parse(data: data) {
                self.rssItems = items
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            } else {
                print("Failed to parse RSS feed")
            }
        }
    }
    
    private func fetchFoodItems() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let request: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        do {
            foodItems = try context.fetch(request)
        } catch {
            print("Failed to fetch food items: \(error)")
        }
    }
    
    private func fuzzySearch(query: String, in items: [FoodItem]) -> [FoodItem] {
        return items.filter {
            let name = $0.name ?? ""
            return name.fuzzyMatch(query) > 0.7 || name.containsIgnoringCase(query)
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
        let weekdayItems = rssItems.filter {
            let calendar = Calendar(identifier: .iso8601)
            return calendar.component(.weekday, from: $0.date) == indexPath.section + 2 // Måndag is 2, Tisdag is 3, ..., Fredag is 6
        }
        if weekdayItems.isEmpty || weekdayItems.first?.courses.isEmpty == true {
            cell.textLabel?.text = "Måltidsinformation saknas"
        } else {
            let courses = weekdayItems.flatMap { $0.courses }
            cell.textLabel?.text = courses[indexPath.row].replacingOccurrences(of: "<br/>", with: "\n")
        }
        return cell
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
        
        var matchedFoodItems: [FoodItem] = []
        var bestMatches: [String: (FoodItem, Double)] = [:]
        
        for word in parsedWords {
            let matchedItems = fuzzySearch(query: word, in: foodItems)
            for item in matchedItems {
                if let itemName = item.name {
                    let score = itemName.fuzzyMatch(word)
                    if let existingItem = bestMatches[itemName], existingItem.1 >= score {
                        continue
                    }
                    bestMatches[itemName] = (item, score)
                }
            }
        }
        
        // Filter items that start with "Ⓢ"
        let sPrefixMatches = bestMatches.values.filter { $0.0.name?.hasPrefix("Ⓢ") == true }
        
        // Use sPrefixMatches if any, otherwise use bestMatches
        let prioritizedMatches: [FoodItem]
        if !sPrefixMatches.isEmpty {
            prioritizedMatches = sPrefixMatches.map { $0.0 }
        } else {
            prioritizedMatches = bestMatches.values.map { $0.0 }
        }
        
        matchedFoodItems = prioritizedMatches
        print("Matched food items: \(matchedFoodItems)")
        
        if let composeMealVC = navigationController?.viewControllers.first(where: { $0 is ComposeMealViewController }) as? ComposeMealViewController {
            navigationController?.popToViewController(composeMealVC, animated: true)
            composeMealVC.populateWithMatchedFoodItems(matchedFoodItems)
        } else {
            let composeMealVC = ComposeMealViewController()
            composeMealVC.matchedFoodItems = matchedFoodItems
            navigationController?.pushViewController(composeMealVC, animated: true)
        }
    }
}
