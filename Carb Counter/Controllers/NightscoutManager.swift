import Foundation

class NightscoutManager {
    static let shared = NightscoutManager()
    
    public var latestBG: Double = 0
    public var latestDelta: Double = 0
    public var latestCOB: Double = 0
    public var latestIOB: Double = 0
    //public var latestCR: Double = 0
    //public var latestISF: Double = 0
    public var latestThreshold: Double = 0
    //public var latestAutosens: Double = 0
    public var latestMinGuardBG: Double = 0
    public var latestEventualBG: Double = 0
    //public var latestInsulinRequired: Double = 0
    //public var latestCarbsRequired: Double = 0
    public var latestMinBG: Double = 0
    public var latestMaxBG: Double = 0
    public var latestTimestamp: String = ""
    public var latestLowestBG: Double = 0
    public var latestLocalTimestamp: String = ""
    public var minBGWarning: Bool = false {
            didSet {
                minBGWarningDidChange?(minBGWarning)
            }
        }
    var minBGWarningDidChange: ((Bool) -> Void)?
    public var evBGWarning: Bool = false {
            didSet {
                evBGWarningDidChange?(evBGWarning)
            }
        }
    var evBGWarningDidChange: ((Bool) -> Void)?
    
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

        let urlString = "\(nightscoutURL)/api/v1/devicestatus?token=\(nightscoutToken)&count=2"
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
                   jsonArray.count >= 2,
                   let latestStatus = jsonArray.first,
                   let previousStatus = jsonArray.dropFirst().first, // Find the second most recent status
                   let latestOpenaps = latestStatus["openaps"] as? [String: Any],
                   let latestSuggested = latestOpenaps["suggested"] as? [String: Any],
                   let previousOpenaps = previousStatus["openaps"] as? [String: Any],
                   let previousSuggested = previousOpenaps["suggested"] as? [String: Any] {

                    // Check if we need to convert to mmol/L
                    let useMmol = UserDefaultsRepository.useMmol
                    let conversionFactor = useMmol ? 0.0555 : 1.0

                    // Extract and convert the latest and previous BG values
                    let latestBG = round((latestSuggested["bg"] as? Double ?? 0) * conversionFactor * 10) / 10.0
                    let previousBG = round((previousSuggested["bg"] as? Double ?? 0) * conversionFactor * 10) / 10.0

                    // Calculate the latestDelta
                    self.latestDelta = round((latestBG - previousBG) * 10) / 10.0

                    // Set the latestBG to the instance variable
                    self.latestBG = latestBG

                    // Continue with the existing code for other calculations
                    self.latestMinGuardBG = round((latestSuggested["minGuardBG"] as? Double ?? 0) * conversionFactor * 10) / 10.0
                    self.latestEventualBG = round((latestSuggested["eventualBG"] as? Double ?? 0) * conversionFactor * 10) / 10.0
                    self.latestCOB = round((latestSuggested["COB"] as? Double ?? 0) * 10) / 10.0
                    self.latestIOB = round((latestSuggested["IOB"] as? Double ?? 0) * 100) / 100.0
                    //self.latestISF = round((latestSuggested["ISF"] as? Double ?? 0) * 10) / 10.0
                    //self.latestCR = round((latestSuggested["CR"] as? Double ?? 0) * 10) / 10.0
                    self.latestThreshold = round((latestSuggested["threshold"] as? Double ?? 0) * 10) / 10.0
                    //self.latestAutosens = round((latestSuggested["sensitivityRatio"] as? Double ?? 0) * 10) / 10.0
                    //self.latestInsulinRequired = round((latestSuggested["insulinReq"] as? Double ?? 0) * 100) / 100.0
                    //self.latestCarbsRequired = round(latestSuggested["carbsReq"] as? Double ?? 0)

                    // Extracting PredBGs to calculate min and max BG, and rounding them
                    if let predBGs = latestSuggested["predBGs"] as? [String: [Double]] {
                        var allBGs: [Double] = []

                        for (_, values) in predBGs {
                            allBGs.append(contentsOf: values)
                        }

                        self.latestMinBG = round((allBGs.min() ?? 0) * conversionFactor * 10) / 10.0
                        self.latestMaxBG = round((allBGs.max() ?? 0) * conversionFactor * 10) / 10.0
                    }

                    // Calculate latestLowestBG
                    self.latestLowestBG = min(self.latestMinBG, self.latestMinGuardBG != 0 ? self.latestMinGuardBG : self.latestMinBG)

                    // Convert and format the timestamp to local time
                    if let timestamp = latestSuggested["timestamp"] as? String {
                        self.latestLocalTimestamp = self.convertToLocalTime(timestamp)
                    } else {
                        self.latestLocalTimestamp = "---"
                    }

                    self.checkMinBGWarning()
                    self.checkEvBGWarning()

                    // Logging the extracted values
                    print("latestBG: \(self.latestBG)")
                    print("latestDelta: \(self.latestDelta)")
                    print("latestCOB: \(self.latestCOB)")
                    print("latestIOB: \(self.latestIOB)")
                    //print("latestCR: \(self.latestCR)")
                    //print("latestISF: \(self.latestISF)")
                    print("latestThreshold: \(self.latestThreshold)")
                    //print("latestAutosens: \(self.latestAutosens)")
                    print("latestMinGuardBG: \(self.latestMinGuardBG)")
                    print("latestEventualBG: \(self.latestEventualBG)")
                    //print("latestInsulinRequired: \(self.latestInsulinRequired)")
                    //print("latestCarbsRequired: \(self.latestCarbsRequired)")
                    print("latestMinBG: \(self.latestMinBG)")
                    print("latestMaxBG: \(self.latestMaxBG)")
                    print("latestLowestBG: \(self.latestLowestBG)")
                    print("latestLocalTimestamp: \(self.latestLocalTimestamp)")
                } else {
                    print("Device status JSON structure is not as expected")
                }
            } catch {
                print("Error parsing device status JSON: \(error)")
            }
        }
        task.resume()
    }
    
    func checkMinBGWarning() {
        let newMinBGWarning = NightscoutManager.shared.latestLowestBG < NightscoutManager.shared.latestThreshold
        NightscoutManager.shared.minBGWarning = newMinBGWarning
    }
    
    func checkEvBGWarning() {
        let newEvBgWarning = NightscoutManager.shared.latestEventualBG < NightscoutManager.shared.latestThreshold
        NightscoutManager.shared.evBGWarning = newEvBgWarning
    }
        
        // Convert UTC timestamp to local time and format it
        private func convertToLocalTime(_ utcTimestamp: String) -> String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = formatter.date(from: utcTimestamp) {
                let localFormatter = DateFormatter()
                localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                localFormatter.timeZone = TimeZone.current
                return localFormatter.string(from: date)
            } else {
                return "---"
            }
        }
    }
