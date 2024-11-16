//
//  Observable.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//

import Foundation
import HealthKit

class Observable {
static let shared = Observable()

var tempTarget = ObservableValue<HKQuantity?>(default: nil)
var override = ObservableValue<String?>(default: nil)

private init() {}
}
