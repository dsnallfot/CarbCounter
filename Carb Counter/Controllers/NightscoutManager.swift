import Foundation

class NightscoutManager {
    static let shared = NightscoutManager()
    
    public var latestBG: Double = 0
    public var latestCOB: Double = 0
    public var latestIOB: Double = 0
    public var latestCR: Double = 0
    public var latestThreshold: Double = 0
    public var latestAutosens: Double = 0
    public var latestMinGuardBG: Double = 0
    public var latestEventualBG: Double = 0
    public var latestInsulinRequired: Double = 0
    public var latestCarbsRequired: Double = 0
    public var latestMinBG: Double = 0
    public var latestMaxBG: Double = 0
    public var latestTimestamp: String = ""

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
    
    func fetchDeviceStatus() {
            guard let nightscoutURL = UserDefaultsRepository.nightscoutURL,
                  let nightscoutToken = UserDefaultsRepository.nightscoutToken else {
                print("Nightscout URL or Token is missing")
                return
            }

            let urlString = "\(nightscoutURL)/api/v1/devicestatus?token=\(nightscoutToken)&count=1"
            guard let url = URL(string: urlString) else {
                print("Invalid URL")
                return
            }

            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error fetching device status: \(error)")
                    return
                }

                guard let data = data else {
                    print("No data returned for device status")
                    return
                }

                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                       let latestStatus = jsonArray.first,
                       let openaps = latestStatus["openaps"] as? [String: Any],
                       let suggested = openaps["suggested"] as? [String: Any] {
                        
                        // Check if we need to convert to mmol/L
                        let useMmol = UserDefaultsRepository.useMmol
                        let conversionFactor = useMmol ? 0.0555 : 1.0

                        // Extracting and converting the values if needed, and rounding to 1 decimal place
                        self.latestBG = round((suggested["bg"] as? Double ?? 0) * conversionFactor * 10) / 10.0
                        self.latestMinGuardBG = round((suggested["minGuardBG"] as? Double ?? 0) * conversionFactor * 10) / 10.0
                        self.latestEventualBG = round((suggested["eventualBG"] as? Double ?? 0) * conversionFactor * 10) / 10.0
                        self.latestCOB = round((suggested["COB"] as? Double ?? 0) * 10) / 10.0
                        self.latestIOB = round((suggested["IOB"] as? Double ?? 0) * 100) / 100.0
                        self.latestCR = round((suggested["CR"] as? Double ?? 0) * 10) / 10.0
                        self.latestThreshold = round((suggested["threshold"] as? Double ?? 0) * 10) / 10.0
                        self.latestAutosens = round((suggested["sensitivityRatio"] as? Double ?? 0) * 10) / 10.0
                        self.latestInsulinRequired = round((suggested["insulinReq"] as? Double ?? 0) * 100) / 100.0
                        self.latestCarbsRequired = round(suggested["carbsReq"] as? Double ?? 0)
                        self.latestTimestamp = suggested["timestamp"] as? String ?? "---"

                        // Extracting PredBGs to calculate min and max BG, and rounding them
                        if let predBGs = suggested["predBGs"] as? [String: [Double]] {
                            var allBGs: [Double] = []
                            
                            for (_, values) in predBGs {
                                allBGs.append(contentsOf: values)
                            }

                            self.latestMinBG = round((allBGs.min() ?? 0) * conversionFactor * 10) / 10.0
                            self.latestMaxBG = round((allBGs.max() ?? 0) * conversionFactor * 10) / 10.0
                        }

                        // Logging the extracted values
                        print("latestBG: \(self.latestBG)")
                        print("latestCOB: \(self.latestCOB)")
                        print("latestIOB: \(self.latestIOB)")
                        print("latestCR: \(self.latestCR)")
                        print("latestThreshold: \(self.latestThreshold)")
                        print("latestAutosens: \(self.latestAutosens)")
                        print("latestMinGuardBG: \(self.latestMinGuardBG)")
                        print("latestEventualBG: \(self.latestEventualBG)")
                        print("latestInsulinRequired: \(self.latestInsulinRequired)")
                        print("latestCarbsRequired: \(self.latestCarbsRequired)")
                        print("latestMinBG: \(self.latestMinBG)")
                        print("latestMaxBG: \(self.latestMaxBG)")
                        print("latestTimestamp: \(self.latestTimestamp)")
                    } else {
                        print("Device status JSON structure is not as expected")
                    }
                } catch {
                    print("Error parsing device status JSON: \(error)")
                }
            }
            task.resume()
        }
    }
