import UIKit
import CoreData

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

extension Date {
    var year: Int {
        return Calendar.current.component(.year, from: self)
    }
}

extension String {
    func levenshtein(_ other: String) -> Int {
        let sCount = self.count
        let tCount = other.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: tCount + 1), count: sCount + 1)
        
        for i in 0...sCount {
            matrix[i][0] = i
        }
        
        for j in 0...tCount {
            matrix[0][j] = j
        }
        
        for i in 1...sCount {
            for j in 1...tCount {
                if self[self.index(self.startIndex, offsetBy: i - 1)] == other[other.index(other.startIndex, offsetBy: j - 1)] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = Swift.min(matrix[i - 1][j - 1] + 1, Swift.min(matrix[i][j - 1] + 1, matrix[i - 1][j] + 1))
                }
            }
        }
        
        return matrix[sCount][tCount]
    }
    
    func fuzzyMatch(_ other: String) -> Double {
        let maxLen = max(self.count, other.count)
        guard maxLen != 0 else { return 1.0 }
        
        let distance = self.levenshtein(other)
        let levenshteinScore = 1.0 - (Double(distance) / Double(maxLen))
        
        // Additional heuristic for more forgiving match: Jaccard similarity
        let jaccardScore = self.jaccardSimilarity(with: other)
        
        // Combine the scores for a more forgiving fuzzy match
        return (levenshteinScore + jaccardScore) / 2.0
    }
    
    func jaccardSimilarity(with other: String) -> Double {
        let selfSet = Set(self.lowercased().split(separator: " "))
        let otherSet = Set(other.lowercased().split(separator: " "))
        
        let intersection = selfSet.intersection(otherSet).count
        let union = selfSet.union(otherSet).count
        
        return Double(intersection) / Double(union)
    }
    
    func containsIgnoringCase(_ other: String) -> Bool {
            return self.range(of: other, options: .caseInsensitive) != nil
    }
}
