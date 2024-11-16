//
//  SecureStorageValue.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//

import Foundation
import Combine

class SecureStorageValue<T: NSObject & NSSecureCoding & Equatable>: ObservableObject {
    let key: String

    @Published var value: T {
        didSet {
            guard self.value != oldValue else { return }
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true) {
                SecureStorageValue.defaults.set(data, forKey: key)
            }
        }
    }

    var exists: Bool {
        return SecureStorageValue.defaults.object(forKey: key) != nil
    }

    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    init(key: String, defaultValue: T) {
        self.key = key
        if let data = SecureStorageValue.defaults.data(forKey: key),
           let decodedValue = try? NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data) {
            self.value = decodedValue
        } else {
            self.value = defaultValue
        }
    }

    func remove() {
        SecureStorageValue.defaults.removeObject(forKey: key)
    }
}
