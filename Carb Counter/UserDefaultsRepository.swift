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
            if UserDefaults.standard.object(forKey: "allowShortcuts") == nil {
                UserDefaults.standard.set(false, forKey: "allowShortcuts")
            }
            return UserDefaults.standard.bool(forKey: "allowShortcuts")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "allowShortcuts")
        }
    }
}
