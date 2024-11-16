//
//  ObservableUserDefaults.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//

import Foundation
import Combine

class ObservableUserDefaults {
    static let shared = ObservableUserDefaults()

    var url = ObservableUserDefaultsValue<String>(key: "url", default: "")
    var device = ObservableUserDefaultsValue<String>(key: "device", default: "")
    var nsWriteAuth = ObservableUserDefaultsValue<Bool>(key: "nsWriteAuth", default: false)

    private init() {}
}
