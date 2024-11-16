//
//  ObservableValue.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//

import Foundation
import Combine
import HealthKit
import SwiftUI

class ObservableValue<T>: ObservableObject {
    @Published var value: T

    init(default: T) {
        self.value = `default`
    }

    func set(_ newValue: T) {
        print("Setting new value: \(newValue)")
        DispatchQueue.main.async {
            self.value = newValue
        }
    }
}
