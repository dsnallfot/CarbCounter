import Foundation

class NightscoutManager {
    static let shared = NightscoutManager()
    
    public var latestBG: Double = 0
    public var latestBGString: String = ""
    public var latestDelta: Double = 0
    public var latestDeltaString: String = ""
    public var latestCOB: Double = 0
    public var latestCOBString: String = ""
    public var latestIOB: Double = 0
    //public var latestCR: Double = 0
    //public var latestISF: Double = 0
    public var latestThreshold: Double = 0
    //public var latestAutosens: Double = 0
    public var latestMinGuardBG: Double = 0
    public var latestMinGuardBGString: String = ""
    public var latestEventualBG: Double = 0
    public var latestEventualBGString: String = ""
    //public var latestInsulinRequired: Double = 0
    //public var latestCarbsRequired: Double = 0
    public var latestMinBG: Double = 0
    public var latestMinBGString: String = ""
    public var latestMaxBG: Double = 0
    public var latestMaxBGString: String = ""
    public var latestTimestamp: String = ""
    public var latestLowestBG: Double = 0
    public var latestLowestBGString: String = ""
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
    
    func fetchDeviceStatus(completion: @escaping () -> Void) {
        guard let nightscoutURL = UserDefaultsRepository.nightscoutURL,
              let nightscoutToken = UserDefaultsRepository.nightscoutToken else {
            print("Nightscout URL or Token is missing")
            completion()
            return
        }

        let urlString = "\(nightscoutURL)/api/v1/devicestatus?token=\(nightscoutToken)&count=2"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion()
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching device status: \(error)")
                completion()
                return
            }

            guard let data = data else {
                print("No data returned for device status")
                completion()
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
                    let decimalPlaces = useMmol ? 1 : 0

                    // Format the value as a string with the appropriate number of decimal places
                    func formatValue(_ value: Double) -> String {
                        return String(format: "%.\(decimalPlaces)f", value)
                    }

                    // Extract and convert the latest and previous BG values
                    let latestBG = round((latestSuggested["bg"] as? Double ?? 0) * conversionFactor * 10) / 10.0
                    let previousBG = round((previousSuggested["bg"] as? Double ?? 0) * conversionFactor * 10) / 10.0

                    // Calculate the latestDelta
                    self.latestDelta = round((latestBG - previousBG) * 10) / 10.0

                    // Set the latestBG to the instance variable and format the string
                    self.latestBG = latestBG
                    self.latestBGString = formatValue(latestBG)

                    self.latestDeltaString = formatValue(self.latestDelta)

                    // Continue with the existing code for other calculations
                    self.latestMinGuardBG = round((latestSuggested["minGuardBG"] as? Double ?? 0) * conversionFactor * 10) / 10.0
                    self.latestEventualBG = round((latestSuggested["eventualBG"] as? Double ?? 0) * conversionFactor * 10) / 10.0

                    self.latestMinGuardBGString = formatValue(self.latestMinGuardBG)
                    self.latestEventualBGString = formatValue(self.latestEventualBG)

                    self.latestCOB = latestSuggested["COB"] as? Double ?? 0
                    self.latestCOBString = String(format: "%.0f", self.latestCOB)
                    self.latestIOB = round((latestSuggested["IOB"] as? Double ?? 0) * 100) / 100.0

                    self.latestThreshold = round((latestSuggested["threshold"] as? Double ?? 0) * 10) / 10.0

                    // Extracting PredBGs to calculate min and max BG, and rounding them
                    if let predBGs = latestSuggested["predBGs"] as? [String: [Double]] {
                        var allBGs: [Double] = []

                        for (_, values) in predBGs {
                            allBGs.append(contentsOf: values)
                        }

                        self.latestMinBG = round((allBGs.min() ?? 0) * conversionFactor * 10) / 10.0
                        self.latestMaxBG = round((allBGs.max() ?? 0) * conversionFactor * 10) / 10.0

                        self.latestMinBGString = formatValue(self.latestMinBG)
                        self.latestMaxBGString = formatValue(self.latestMaxBG)
                    }

                    // Calculate latestLowestBG
                    self.latestLowestBG = min(self.latestMinBG, self.latestMinGuardBG != 0 ? self.latestMinGuardBG : self.latestMinBG)
                    self.latestLowestBGString = formatValue(self.latestLowestBG)

                    // Convert and format the timestamp to local time
                    self.latestTimestamp = latestSuggested["timestamp"] as? String ?? ""
                    
                    if let timestamp = latestSuggested["timestamp"] as? String {
                        self.latestLocalTimestamp = self.convertToLocalTime(timestamp)
                    } else {
                        self.latestLocalTimestamp = "---"
                    }

                    self.checkMinBGWarning()
                    self.checkEvBGWarning()

                    // Logging the extracted values
                    print("latestBG: \(self.latestBG)")
                    print("latestBGString: \(self.latestBGString)")
                    print("latestDelta: \(self.latestDelta)")
                    print("latestDeltaString: \(self.latestDeltaString)")
                    print("latestMinGuardBG: \(self.latestMinGuardBG)")
                    print("latestMinGuardBGString: \(self.latestMinGuardBGString)")
                    print("latestEventualBG: \(self.latestEventualBG)")
                    print("latestEventualBGString: \(self.latestEventualBGString)")
                    print("latestMinBG: \(self.latestMinBG)")
                    print("latestMinBGString: \(self.latestMinBGString)")
                    print("latestMaxBG: \(self.latestMaxBG)")
                    print("latestMaxBGString: \(self.latestMaxBGString)")
                    print("latestThreshold: \(self.latestThreshold)")
                    print("latestIOB: \(self.latestIOB)")
                    print("latestCOB: \(self.latestCOB)")
                    print("latestCOBString: \(self.latestCOBString)")
                    print("latestTimestamp: \(self.latestTimestamp)")
                    print("latestLocalTimestamp: \(self.latestLocalTimestamp)")
                    
                    // Call completion after processing the data
                    completion()
                } else {
                    print("Device status JSON structure is not as expected")
                    completion()
                }
            } catch {
                print("Error parsing device status JSON: \(error)")
                completion()
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
        
    // Convert UTC timestamp to local time and format it to HH:mm:ss
    private func convertToLocalTime(_ utcTimestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: utcTimestamp) {
            let localFormatter = DateFormatter()
            localFormatter.timeStyle = .medium // This will automatically adjust based on the device's settings
            localFormatter.timeZone = TimeZone.current
            return localFormatter.string(from: date)
        } else {
            return "---"
        }
    }
    }
