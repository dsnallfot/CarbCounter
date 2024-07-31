import UIKit
/*
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
        case "summary":
            currentCourses.append(contentsOf: string.components(separatedBy: "<br />").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
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
                let courses = currentDescription.components(separatedBy: "<br />").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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
}*/
