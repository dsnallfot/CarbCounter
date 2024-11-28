import Foundation

class UserDefaultsRepository {
    static var method: String {
        get {
            return UserDefaults.standard.string(forKey: "method") ?? "iOS Shortcuts"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "method")
            NotificationCenter.default.post(name: .methodChanged, object: nil)
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
    
    static var overrideFactor: Double {
        get {
            return UserDefaults.standard.double(forKey: "overrideFactor")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "overrideFactor")
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
    
    static var override: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "override")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "override")
        }
    }
        
    static var overrideName: String? {
        get {
            return UserDefaults.standard.string(forKey: "overrideName")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "overrideName")
        }
    }

    static var overrideStartTime: Date? {
        get {
            return UserDefaults.standard.object(forKey: "overrideStartTime") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "overrideStartTime")
        }
    }
    
    static var overrideFactorUsed: String {
            get {
                return UserDefaults.standard.string(forKey: "overrideFactorUsed") ?? "100 %"
            }
            set {
                UserDefaults.standard.set(newValue, forKey: "overrideFactorUsed")
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
    
    static var gptAPIKey: String {
        get {
            return UserDefaults.standard.string(forKey: "gptAPIKey") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "gptAPIKey")
        }
    }
    
    static var useMmol: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "useMmol")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useMmol")
            // Update the units UserDefaults value based on the new value of useMmol
            if newValue {
                UserDefaultsRepository.units.value = "mmol/L"
            } else {
                UserDefaultsRepository.units.value = "mg/dL"
            }
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
    
    static var allowCSVSync: Bool {
        get {
            return UserDefaults.standard.object(forKey: "allowCSVSync") as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "allowCSVSync")
            NotificationCenter.default.post(name: .allowCSVSync, object: nil)
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
    static var savedHistorySearchText: String? {
        get {
            return UserDefaults.standard.string(forKey: "savedHistorySearchText")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "savedHistorySearchText")
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
    
    static var historyNotificationsAllowed: Bool {
        get {
            if UserDefaults.standard.object(forKey: "historyNotificationsAllowed") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "historyNotificationsAllowed")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "historyNotificationsAllowed")
        }
    }

    static var registrationNotificationsAllowed: Bool {
        get {
            if UserDefaults.standard.object(forKey: "registrationNotificationsAllowed") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "registrationNotificationsAllowed")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "registrationNotificationsAllowed")
        }
    }

    static var preBolusNotificationsAllowed: Bool {
        get {
            if UserDefaults.standard.object(forKey: "preBolusNotificationsAllowed") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "preBolusNotificationsAllowed")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "preBolusNotificationsAllowed")
        }
    }
    
    static var finishMealNotificationsAllowed: Bool {
        get {
            if UserDefaults.standard.object(forKey: "finishMealNotificationsAllowed") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "finishMealNotificationsAllowed")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "finishMealNotificationsAllowed")
        }
    }
}

extension Notification.Name {
    static let allowViewingOngoingMealsChanged = Notification.Name("allowViewingOngoingMealsChanged")
    static let allowCSVSync = Notification.Name("allowCSVSync")
    static let schoolFoodURLChanged = Notification.Name("schoolFoodURLChanged")
    static let methodChanged = Notification.Name("methodChanged")
}
