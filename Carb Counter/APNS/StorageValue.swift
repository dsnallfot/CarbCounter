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
    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    @Published var value: T {
        didSet {
            guard value != oldValue else {
                //print("No change for key \(key). Current value: \(value)")
                return
            }

            do {
                let encodedData = try JSONEncoder().encode(value)
                StorageValue.defaults.set(encodedData, forKey: key)
                StorageValue.defaults.synchronize()
                
                // Verify the save immediately
                if let savedData = StorageValue.defaults.data(forKey: key),
                   let decodedValue = try? JSONDecoder().decode(T.self, from: savedData) {
                    //print("Verification - Value for key \(key) was saved and can be read back as: \(decodedValue)")
                } else {
                    //print("WARNING: Value for key \(key) could not be verified after save!")
                }
            } catch {
                //print("Encoding error for key \(key): \(error)")
            }
        }
    }

    var exists: Bool {
        return StorageValue.defaults.object(forKey: key) != nil
    }

    init(key: String, defaultValue: T) {
        self.key = key
        //print("Initializing StorageValue for key: \(key)")
        
        // Debug: Print all UserDefaults keys and values
        for (key, value) in StorageValue.defaults.dictionaryRepresentation() {
            //print("UserDefaults contains - Key: \(key), Value type: \(type(of: value))")
        }

        if let data = StorageValue.defaults.data(forKey: key) {
            do {
                let decodedValue = try JSONDecoder().decode(T.self, from: data)
                self.value = decodedValue
                //print("Successfully loaded value for key \(key): \(decodedValue)")
            } catch {
                //print("Decoding error for key \(key): \(error). Raw data: \(data)")
                self.value = defaultValue
            }
        } else {
            //print("No existing value for key \(key). Using default value: \(defaultValue)")
            self.value = defaultValue
        }
    }
}
