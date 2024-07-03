import Foundation

class NightscoutManager {
    static let shared = NightscoutManager()

    private init() {}

    func fetchAndMapCarbRatio(completion: @escaping (Bool) -> Void) {
        guard let nightscoutURL = UserDefaultsRepository.nightscoutURL,
              let nightscoutToken = UserDefaultsRepository.nightscoutToken else {
            print("Nightscout URL or Token is missing")
            completion(false)
            return
        }

        let urlString = "\(nightscoutURL)/api/v1/profile?token=\(nightscoutToken)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion(false)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error)")
                completion(false)
                return
            }

            guard let data = data else {
                print("No data returned")
                completion(false)
                return
            }

            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    var carbratioArray: [[String: Any]] = []

                    for profile in jsonArray {
                        if let store = profile["store"] as? [String: Any],
                           let defaultProfile = store["default"] as? [String: Any],
                           let carbratio = defaultProfile["carbratio"] as? [[String: Any]] {
                            carbratioArray = carbratio
                            break
                        }
                    }

                    if carbratioArray.isEmpty {
                        completion(false)
                        return
                    }

                    var hourlyCarbRatios = [Int: Double](uniqueKeysWithValues: (0..<24).map { ($0, 0.0) })

                    for i in 0..<carbratioArray.count {
                        let current = carbratioArray[i]
                        let next = carbratioArray[(i + 1) % carbratioArray.count]

                        guard let currentValue = current["value"] as? Double,
                              let currentSeconds = current["timeAsSeconds"] as? Int,
                              let nextSeconds = next["timeAsSeconds"] as? Int else {
                            continue
                        }

                        let startHour = currentSeconds / 3600
                        var endHour = nextSeconds / 3600

                        // Handle wrapping around midnight
                        if endHour <= startHour {
                            endHour += 24
                        }

                        for hour in startHour..<endHour {
                            hourlyCarbRatios[hour % 24] = currentValue
                        }
                    }

                    CoreDataHelper.shared.updateCarbRatios(with: hourlyCarbRatios)
                    completion(true)
                } else {
                    completion(false)
                }
            } catch {
                print("Error parsing JSON: \(error)")
                completion(false)
            }
        }
        task.resume()
    }
}
