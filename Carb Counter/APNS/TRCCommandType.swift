//
//  TRCCommandType.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//


import Foundation

enum TRCCommandType: String {
    case bolus = "bolus"
    case tempTarget = "temp_target"
    case cancelTempTarget = "cancel_temp_target"
    case meal = "meal"
    case startOverride = "start_override"
    case cancelOverride = "cancel_override"
}
