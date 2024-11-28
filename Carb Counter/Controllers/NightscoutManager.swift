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
        let nightscoutURL = ObservableUserDefaults.shared.url.value
        let nightscoutToken = UserDefaultsRepository.token.value

            // Check if Nightscout URL or Token is empty
            guard !nightscoutURL.isEmpty, !nightscoutToken.isEmpty else {
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

        let urlString = "\(nightscoutURL)/api/v1/devicestatus?token=\(nightscoutToken)&count=3"
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
                   jsonArray.count >= 3 {

                    // Extract three most recent entries
                    let latestStatus = jsonArray[0]
                    let secondStatus = jsonArray[1]
                    let thirdStatus = jsonArray[2]

                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                    // Helper to extract suggested or enacted
                    func extractRelevantOpenAPS(_ entry: [String: Any]) -> [String: Any]? {
                        if let openaps = entry["openaps"] as? [String: Any] {
                            return openaps["suggested"] as? [String: Any] ?? openaps["enacted"] as? [String: Any]
                        }
                        return nil
                    }

                    // Extract relevant data
                    guard let latestOpenaps = extractRelevantOpenAPS(latestStatus),
                          let secondOpenaps = extractRelevantOpenAPS(secondStatus),
                          let thirdOpenaps = extractRelevantOpenAPS(thirdStatus),
                          let latestTimestampString = latestOpenaps["timestamp"] as? String,
                          let secondTimestampString = secondOpenaps["timestamp"] as? String,
                          let thirdTimestampString = thirdOpenaps["timestamp"] as? String,
                          let latestTimestamp = isoFormatter.date(from: latestTimestampString),
                          let secondTimestamp = isoFormatter.date(from: secondTimestampString),
                          let thirdTimestamp = isoFormatter.date(from: thirdTimestampString) else {
                        print("Missing or invalid `openaps.suggested` or `openaps.enacted`")
                        completion()
                        return
                    }

                    // Determine whether to use the second or third entry
                    let now = Date()
                    let fourMinutesAgo = now.addingTimeInterval(-240)
                    let previousOpenaps = secondTimestamp <= fourMinutesAgo ? secondOpenaps : thirdOpenaps

                    // Extract BG values
                    let useMmol = UserDefaultsRepository.useMmol
                    let conversionFactor = useMmol ? 0.0555 : 1.0
                    let decimalPlaces = useMmol ? 1 : 0

                    func formatValue(_ value: Double) -> String {
                        return String(format: "%.\(decimalPlaces)f", value)
                    }

                    let rawLatestBG = latestOpenaps["bg"] as? Double ?? 0
                    let rawPreviousBG = previousOpenaps["bg"] as? Double ?? 0

                    let latestBG = rawLatestBG > 22 ? round(rawLatestBG * conversionFactor * 10) / 10.0 : rawLatestBG
                    let previousBG = rawPreviousBG > 22 ? round(rawPreviousBG * conversionFactor * 10) / 10.0 : rawPreviousBG

                    // Calculate and store the delta
                    self.latestDelta = round((latestBG - previousBG) * 10) / 10.0
                    self.latestBG = latestBG
                    self.latestBGString = formatValue(latestBG)
                    self.latestDeltaString = formatValue(self.latestDelta)

                    // Logging for debugging
                    print("latestBG: \(latestBG), previousBG: \(previousBG), latestDelta: \(self.latestDelta)")

                    // Continue with the existing code for other calculations
                    self.latestMinGuardBG = round((latestOpenaps["minGuardBG"] as? Double ?? 0) * conversionFactor * 10) / 10.0
                    self.latestEventualBG = round((latestOpenaps["eventualBG"] as? Double ?? 0) * conversionFactor * 10) / 10.0

                    self.latestMinGuardBGString = formatValue(self.latestMinGuardBG)
                    self.latestEventualBGString = formatValue(self.latestEventualBG)

                    self.latestCOB = latestOpenaps["COB"] as? Double ?? 0
                    self.latestCOBString = String(format: "%.0f", self.latestCOB)
                    self.latestIOB = round((latestOpenaps["IOB"] as? Double ?? 0) * 100) / 100.0

                    self.latestThreshold = round((latestOpenaps["threshold"] as? Double ?? 0) * conversionFactor * 10) / 10.0

                    // Extracting PredBGs to calculate min and max BG, and rounding them
                    if let predBGs = latestOpenaps["predBGs"] as? [String: [Double]] {
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
                    self.latestTimestamp = latestOpenaps["timestamp"] as? String ?? ""
                    
                    if let timestamp = latestOpenaps["timestamp"] as? String {
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
