import UIKit

struct RSSItem {
    var title: String
    var date: Date
    var description: String
    var courses: [String]
}

class RSSParser: NSObject, XMLParserDelegate {
    
    private var rssItems: [RSSItem] = []
    private var currentElement = ""
    private var currentTitle: String = ""
    private var currentDate: String = ""
    private var currentDescription: String = ""
    private var currentCourses: [String] = []
    
    func parse(data: Data) -> [RSSItem]? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        if parser.parse() {
            return rssItems
        } else {
            return nil
        }
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if currentElement == "item" {
            currentTitle = ""
            currentDate = ""
            currentDescription = ""
            currentCourses = []
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title":
            currentTitle += string
        case "pubDate":
            currentDate += string
        case "description":
            currentDescription += string
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            // Parse the currentDate string to a Date object
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z" // Adjust the format based on your RSS feed's date format
            if let date = dateFormatter.date(from: currentDate) {
                let courses = currentDescription.components(separatedBy: "<br/>").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                let rssItem = RSSItem(title: currentTitle, date: date, description: currentDescription, courses: courses.isEmpty ? ["Måltidsinformation saknas"] : courses)
                rssItems.append(rssItem)
            } else {
                print("Date parsing error: \(currentDate)")
            }
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("Failed to parse XML: \(parseError.localizedDescription)")
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    
    private init() {}
    
    func fetchRSSFeed(url: String, completion: @escaping (Data?) -> Void) {
        guard let url = URL(string: url) else {
            print("Invalid URL")
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching RSS feed: \(error)")
                completion(nil)
                return
            }
            
            if let data = data, let dataString = String(data: data, encoding: .utf8) {
                print("Fetched data string: \(dataString)")  // Print the fetched string for debugging
                completion(data)
            } else {
                completion(nil)
            }
        }
        
        task.resume()
    }
}

class RSSFeedViewController: UIViewController {
    
    var tableView: UITableView!
    var rssItems: [RSSItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Skolmatsedel"
        view.backgroundColor = .systemBackground
        
        setupTableView()
        fetchRSSFeed()
    }
    
    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func fetchRSSFeed() {
        NetworkManager.shared.fetchRSSFeed(url: "https://skolmaten.se/kampetorpsskolan/rss/weeks/?offset=-10") { data in
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
            cell.textLabel?.text = courses[indexPath.row]
        }
        return cell
    }
}

extension Date {
    var year: Int {
        return Calendar.current.component(.year, from: self)
    }
}
