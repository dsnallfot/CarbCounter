//
//  UserDefaults.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/4/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//
//
//
//
//

import Foundation
import UIKit
import HealthKit

extension UserDefaultsRepository {
    
    // Nightscout Settings
    static let showNS = UserDefaultsValue<Bool>(key: "showNS", default: false)
    //static let url = UserDefaultsValue<String>(key: "url", default: "")
    static let token = UserDefaultsValue<String>(key: "token", default: "")
    static let units = UserDefaultsValue<String>(key: "units", default: "mg/dL")

    static func getPreferredUnit() -> HKUnit {
        let unitString = units.value
        switch unitString {
        case "mmol/L":
            return .millimolesPerLiter
        default:
            return .milligramsPerDeciliter
        }
    }

    static func setPreferredUnit(_ unit: HKUnit) {
        var unitString = "mg/dL"
        if unit == .millimolesPerLiter {
            unitString = "mmol/L"
        }
        units.value = unitString
    }

    //What version is the cache valid for
    static let cachedForVersion = UserDefaultsValue<String?>(key: "cachedForVersion", default: nil)

    //Caching of latest version
    static let latestVersion = UserDefaultsValue<String?>(key: "latestVersion", default: nil)
    static let latestVersionChecked = UserDefaultsValue<Date?>(key: "latestVersionChecked", default: nil)

    //Caching of blacklisted version
    static let currentVersionBlackListed = UserDefaultsValue<Bool>(key: "currentVersionBlackListed", default: false)

    // Tracking notifications to manage frequency
    static let lastBlacklistNotificationShown = UserDefaultsValue<Date?>(key: "lastBlacklistNotificationShown", default: nil)
    static let lastVersionUpdateNotificationShown = UserDefaultsValue<Date?>(key: "lastVersionUpdateNotificationShown", default: nil)
    
    // Tracking the last time the expiration notification was shown
    static let lastExpirationNotificationShown = UserDefaultsValue<Date?>(key: "lastExpirationNotificationShown", default: nil)
}
