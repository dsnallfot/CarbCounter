//
//  ProfileManager.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//

import Foundation
import HealthKit

final class ProfileManager {
    // MARK: - Singleton Instance
    static let shared = ProfileManager()

    // MARK: - Properties
    var isfSchedule: [TimeValue<HKQuantity>]
    var basalSchedule: [TimeValue<Double>]
    var carbRatioSchedule: [TimeValue<Double>]
    var targetLowSchedule: [TimeValue<HKQuantity>]
    var targetHighSchedule: [TimeValue<HKQuantity>]
    var overrides: [Override]
    var trioOverrides: [TrioOverride]
    var units: HKUnit
    var timezone: TimeZone
    var defaultProfile: String

    // MARK: - Nested Structures
    struct TimeValue<T> {
        let timeAsSeconds: Int
        let value: T
    }

    struct Override {
        let name: String
        let targetRange: [HKQuantity]
        let duration: Int
        let insulinNeedsScaleFactor: Double
        let symbol: String
    }

    struct TrioOverride {
        let name: String
        let duration: Double?
        let percentage: Double?
        let target: HKQuantity?
    }

    // MARK: - Initializer
    private init() {
        self.isfSchedule = []
        self.basalSchedule = []
        self.carbRatioSchedule = []
        self.targetLowSchedule = []
        self.targetHighSchedule = []
        self.overrides = []
        self.trioOverrides = []
        self.units = .millimolesPerLiter
        self.timezone = TimeZone.current
        self.defaultProfile = ""
    }

    // MARK: - Methods
    
    func loadProfile(from profileData: NSProfile) {
        guard let store = profileData.store[profileData.defaultProfile] else {
            print("Error: No store found for default profile \(profileData.defaultProfile).")
            return
        }

        print("Loading profile for default profile: \(profileData.defaultProfile)")

        self.units = store.units.lowercased() == "mg/dl" ? .milligramsPerDeciliter : .millimolesPerLiter
        print("Units set to: \(self.units)")

        self.defaultProfile = profileData.defaultProfile
        print("Default profile: \(self.defaultProfile)")

        self.timezone = getTimeZone(from: store.timezone)
        print("Timezone set to: \(self.timezone.identifier)")

        self.isfSchedule = store.sens.map {
            let timeValue = TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: HKQuantity(unit: self.units, doubleValue: $0.value))
            print("ISF schedule time: \($0.timeAsSeconds), value: \($0.value)")
            return timeValue
        }

        self.basalSchedule = store.basal.map {
            let timeValue = TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: $0.value)
            print("Basal schedule time: \($0.timeAsSeconds), value: \($0.value)")
            return timeValue
        }

        self.carbRatioSchedule = store.carbratio.map {
            let timeValue = TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: $0.value)
            print("Carb ratio schedule time: \($0.timeAsSeconds), value: \($0.value)")
            return timeValue
        }

        self.targetLowSchedule = store.target_low?.map {
            let timeValue = TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: HKQuantity(unit: self.units, doubleValue: $0.value))
            print("Target low schedule time: \($0.timeAsSeconds), value: \($0.value)")
            return timeValue
        } ?? []
        print("Target low schedule: \(self.targetLowSchedule)")

        self.targetHighSchedule = store.target_high?.map {
            let timeValue = TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: HKQuantity(unit: self.units, doubleValue: $0.value))
            print("Target high schedule time: \($0.timeAsSeconds), value: \($0.value)")
            return timeValue
        } ?? []
        print("Target high schedule: \(self.targetHighSchedule)")

        if let overrides = store.overrides {
            self.overrides = overrides.map {
                print("Override name: \($0.name ?? ""), target range: \($0.targetRange ?? []), duration: \($0.duration ?? 0), insulin needs scale factor: \($0.insulinNeedsScaleFactor ?? 1.0), symbol: \($0.symbol ?? "")")
                return Override(
                    name: $0.name ?? "",
                    targetRange: $0.targetRange?.map { HKQuantity(unit: self.units, doubleValue: $0) } ?? [],
                    duration: $0.duration ?? 0,
                    insulinNeedsScaleFactor: $0.insulinNeedsScaleFactor ?? 1.0,
                    symbol: $0.symbol ?? ""
                )
            }
        } else {
            self.overrides = []
            print("No overrides found.")
        }

        if let trioOverrides = profileData.trioOverrides {
            self.trioOverrides = trioOverrides.map { entry in
                let targetQuantity = entry.target != nil ? HKQuantity(unit: .milligramsPerDeciliter, doubleValue: entry.target!) : nil
                print("TrioOverride name: \(entry.name), duration: \(entry.duration), percentage: \(entry.percentage), target: \(entry.target ?? 0)")
                return TrioOverride(
                    name: entry.name,
                    duration: entry.duration,
                    percentage: entry.percentage,
                    target: targetQuantity
                )
            }
        } else {
            self.trioOverrides = []
            print("No trioOverrides found.")
        }

        Storage.shared.deviceToken.value = profileData.deviceToken ?? ""
        print("Device token: \(Storage.shared.deviceToken.value)")

        Storage.shared.bundleId.value = profileData.bundleIdentifier ?? ""
        print("Bundle ID: \(Storage.shared.bundleId.value)")

        Storage.shared.productionEnvironment.value = profileData.isAPNSProduction ?? false
        print("APNS production environment: \(Storage.shared.productionEnvironment.value)")

        Storage.shared.teamId.value = profileData.teamID ?? Storage.shared.teamId.value ?? ""
        print("Team ID: \(Storage.shared.teamId.value)")
    }

    func currentISF() -> HKQuantity? {
        return getCurrentValue(from: isfSchedule)
    }

    func currentBasal() -> String? {
        if let basal = getCurrentValue(from: basalSchedule) {
            return Localizer.formatToLocalizedString(basal, maxFractionDigits: 2, minFractionDigits: 0)
        }
        return nil
    }

    func currentCarbRatio() -> Double? {
        return getCurrentValue(from: carbRatioSchedule)
    }

    func currentTargetLow() -> HKQuantity? {
        return getCurrentValue(from: targetLowSchedule)
    }

    func currentTargetHigh() -> HKQuantity? {
        return getCurrentValue(from: targetHighSchedule)
    }

    private func getCurrentValue<T>(from schedule: [TimeValue<T>]) -> T? {
        guard !schedule.isEmpty else { return nil }

        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = self.timezone

        let currentTimeInSeconds = calendar.component(.hour, from: now) * 3600 +
        calendar.component(.minute, from: now) * 60 +
        calendar.component(.second, from: now)

        var lastValue: T?
        for timeValue in schedule {
            if currentTimeInSeconds >= timeValue.timeAsSeconds {
                lastValue = timeValue.value
            } else {
                break
            }
        }
        return lastValue
    }

    private func getTimeZone(from identifier: String) -> TimeZone {
        if let timeZone = TimeZone(identifier: identifier) {
            return timeZone
        }

        let adjustedIdentifier = identifier.replacingOccurrences(of: "ETC/", with: "Etc/")
        if let timeZone = TimeZone(identifier: adjustedIdentifier) {
            return timeZone
        }

        if identifier.uppercased().contains("GMT") {
            let components = identifier.uppercased().components(separatedBy: "GMT")
            if components.count > 1 {
                let offsetString = components[1]
                if let offsetHours = Int(offsetString) {
                    let correctedOffsetHours = -offsetHours
                    let secondsFromGMT = correctedOffsetHours * 3600
                    if let timeZone = TimeZone(secondsFromGMT: secondsFromGMT) {
                        return timeZone
                    }
                }
            }
        }

        return TimeZone.current
    }

    func clear() {
        self.isfSchedule = []
        self.basalSchedule = []
        self.carbRatioSchedule = []
        self.targetLowSchedule = []
        self.targetHighSchedule = []
        self.overrides = []
        self.units = .millimolesPerLiter
        self.timezone = TimeZone.current
        self.defaultProfile = ""
    }
}
