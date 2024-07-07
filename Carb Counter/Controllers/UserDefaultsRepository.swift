//
//  UserDefaultsRepository.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-23.
//
import Foundation

class UserDefaultsRepository {
    static var method: String {
        get {
            return UserDefaults.standard.string(forKey: "method") ?? "iOS Shortcuts"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "method")
        }
    }
    
    static var twilioSIDString: String {
        get {
            return UserDefaults.standard.string(forKey: "twilioSIDString") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "twilioSIDString")
        }
    }
    
    static var twilioSecretString: String {
        get {
            return UserDefaults.standard.string(forKey: "twilioSecretString") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "twilioSecretString")
        }
    }
    
    static var twilioFromNumberString: String {
        get {
            return UserDefaults.standard.string(forKey: "twilioFromNumberString") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "twilioFromNumberString")
        }
    }
    
    static var twilioToNumberString: String {
        get {
            return UserDefaults.standard.string(forKey: "twilioToNumberString") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "twilioToNumberString")
        }
    }
    
    static var caregiverName: String {
        get {
            return UserDefaults.standard.string(forKey: "caregiverName") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "caregiverName")
        }
    }
    
    static var remoteSecretCode: String {
        get {
            return UserDefaults.standard.string(forKey: "remoteSecretCode") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "remoteSecretCode")
        }
    }

    static var allowShortcuts: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "allowShortcuts")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "allowShortcuts")
        }
    }

    static var allowDataClearing: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "allowDataClearing")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "allowDataClearing")
        }
    }
    
    static var maxCarbs: Double {
        get {
            return UserDefaults.standard.double(forKey: "maxCarbs")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "maxCarbs")
        }
    }
    
    static var maxBolus: Double {
        get {
            return UserDefaults.standard.double(forKey: "maxBolus")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "maxBolus")
        }
    }
    
    static var lateBreakfastFactor: Double {
        get {
            return UserDefaults.standard.double(forKey: "lateBreakfastFactor")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lateBreakfastFactor")
        }
    }
    
    static var scheduledCarbRatio: Double {
        get {
            return UserDefaults.standard.double(forKey: "scheduledCarbRatio") != 0 ? UserDefaults.standard.double(forKey: "scheduledCarbRatio") : 30.0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "scheduledCarbRatio")
        }
    }
    
    static var lateBreakfast: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "lateBreakfast")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lateBreakfast")
        }
    }
    
    static var dabasAPISecret: String {
            get {
                return UserDefaults.standard.string(forKey: "dabasAPISecret") ?? ""
            }
            set {
                UserDefaults.standard.set(newValue, forKey: "dabasAPISecret")
            }
        }
    
    static var nightscoutURL: String? {
            get {
                return UserDefaults.standard.string(forKey: "nightscoutURL")
            }
            set {
                UserDefaults.standard.set(newValue, forKey: "nightscoutURL")
            }
        }
        
        static var nightscoutToken: String? {
            get {
                return UserDefaults.standard.string(forKey: "nightscoutToken")
            }
            set {
                UserDefaults.standard.set(newValue, forKey: "nightscoutToken")
            }
        }
}
