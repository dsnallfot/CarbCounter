//
//  StorageValue.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//

import Foundation
import Combine

class StorageValue<T: Codable & Equatable>: ObservableObject {
    let key: String

    @Published var value: T {
        didSet {
            guard self.value != oldValue else { return }

            if let encodedData = try? JSONEncoder().encode(value) {
                StorageValue.defaults.set(encodedData, forKey: key)
            }
        }
    }

    var exists: Bool {
        return StorageValue.defaults.object(forKey: key) != nil
    }

    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    init(key: String, defaultValue: T) {
        self.key = key

        if let data = StorageValue.defaults.data(forKey: key),
           let decodedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.value = decodedValue
        } else {
            self.value = defaultValue
        }
    }

    func remove() {
        StorageValue.defaults.removeObject(forKey: key)
    }
}
