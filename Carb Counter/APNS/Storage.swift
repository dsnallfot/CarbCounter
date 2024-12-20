//
//  Storage.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//


import Foundation
import HealthKit

class Storage {
    private static let sharedSecretKey = "sharedSecret"
    var deviceToken = StorageValue<String>(key: "deviceToken", defaultValue: "")
    var sharedSecret: StorageValue<String> = {
            //print("Creating sharedSecret StorageValue")
            return StorageValue<String>(key: Storage.sharedSecretKey, defaultValue: "")
        }()
    var productionEnvironment = StorageValue<Bool>(key: "productionEnvironment", defaultValue: true)
    var apnsKey = StorageValue<String>(key: "apnsKey", defaultValue: "")
    var teamId = StorageValue<String?>(key: "teamId", defaultValue: nil)
    var keyId = StorageValue<String>(key: "keyId", defaultValue: "")
    var bundleId = StorageValue<String>(key: "bundleId", defaultValue: "")
    var user = StorageValue<String>(key: "user", defaultValue: "")

    var maxBolus = SecureStorageValue<HKQuantity>(key: "maxBolus", defaultValue: HKQuantity(unit: .internationalUnit(), doubleValue: 1.0))
    var maxCarbs = SecureStorageValue<HKQuantity>(key: "maxCarbs", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))
    var maxProtein = SecureStorageValue<HKQuantity>(key: "maxProtein", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))
    var maxFat = SecureStorageValue<HKQuantity>(key: "maxFat", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))

    var mealWithBolus = StorageValue<Bool>(key: "mealWithBolus", defaultValue: false)
    var mealWithFatProtein = StorageValue<Bool>(key: "mealWithFatProtein", defaultValue: false)

    var cachedJWT = StorageValue<String?>(key: "cachedJWT", defaultValue: nil)
    var jwtExpirationDate = StorageValue<Date?>(key: "jwtExpirationDate", defaultValue: nil)

    static let shared = Storage()

    private init() {
        //print("Initializing Storage singleton")
    }
}
