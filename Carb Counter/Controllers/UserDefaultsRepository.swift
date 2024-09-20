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
    
    static var useStartDosePercentage: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "useStartDosePercentage")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useStartDosePercentage")
        }
    }
    
    static var startDoseFactor: Double {
        get {
            return UserDefaults.standard.double(forKey: "startDoseFactor")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "startDoseFactor")
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
        
    static var lateBreakfastOverrideName: String? {
        get {
            return UserDefaults.standard.string(forKey: "lateBreakfastOverrideName")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lateBreakfastOverrideName")
        }
    }

    static var lateBreakfastStartTime: Date? {
        get {
            return UserDefaults.standard.object(forKey: "lateBreakfastStartTime") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lateBreakfastStartTime")
        }
    }
    
    static var lateBreakfastFactorUsed: String {
            get {
                return UserDefaults.standard.string(forKey: "lateBreakfastFactorUsed") ?? "100 %"
            }
            set {
                UserDefaults.standard.set(newValue, forKey: "lateBreakfastFactorUsed")
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
    
    static var useMmol: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "useMmol")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useMmol")
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
    
    static var allowSharingOngoingMeals: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "allowSharingOngoingMeals")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "allowSharingOngoingMeals")
        }
    }
    
    static var allowViewingOngoingMeals: Bool {
        get {
            return UserDefaults.standard.object(forKey: "allowViewingOngoingMeals") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "allowViewingOngoingMeals")
            NotificationCenter.default.post(name: .allowViewingOngoingMealsChanged, object: nil)
        }
    }
    
    static var schoolFoodURL: String? {
        get {
            return UserDefaults.standard.string(forKey: "schoolFoodURL")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "schoolFoodURL")
            NotificationCenter.default.post(name: .schoolFoodURLChanged, object: nil)
        }
    }
    
    static var dropdownSearchText: String? {
            get {
                return UserDefaults.standard.string(forKey: "dropdownSearchText")
            }
            set {
                UserDefaults.standard.set(newValue, forKey: "dropdownSearchText")
            }
        }
    static var savedSearchText: String? {
        get {
            return UserDefaults.standard.string(forKey: "savedSearchText")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "savedSearchText")
        }
        }
    static var excludeWords: String? {
        get {
            return UserDefaults.standard.string(forKey: "excludeWords")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "excludeWords")
        }
    }
    static var topUps: String? {
        get {
            return UserDefaults.standard.string(forKey: "topUps")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "topUps")
        }
    }
}

extension Notification.Name {
    static let allowViewingOngoingMealsChanged = Notification.Name("allowViewingOngoingMealsChanged")
    static let schoolFoodURLChanged = Notification.Name("schoolFoodURLChanged")
}
