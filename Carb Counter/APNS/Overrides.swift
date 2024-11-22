//
//  Overrides.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-16.
//

import Foundation
import UIKit

extension ComposeMealViewController {
    // NS Override Response Processor
    func processNSOverrides(entries: [[String:AnyObject]]) {
        var activeOverrideNote: String? = nil
        
        let now = Date().timeIntervalSince1970
        let predictionLoadHours = 3.0
        let predictionLoadSeconds = predictionLoadHours * 3600
        let maxEndDate = now + predictionLoadSeconds
        
        entries.reversed().enumerated().forEach { (index, currentEntry) in
            guard let dateStr = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String else { return }
            guard let parsedDate = NightscoutUtils.parseDate(dateStr) else { return }
            
            var dateTimeStamp = parsedDate.timeIntervalSince1970
            var duration: Double = 5.0
            if let _ = currentEntry["durationType"] as? String, index == entries.count - 1 {
                duration = dateTimeUtils.getNowTimeIntervalUTC() - dateTimeStamp + (60 * 60)
            } else {
                duration = (currentEntry["duration"] as? Double ?? 5.0) * 60
            }
            
            if duration < 300 { return }
            
            let reason = currentEntry["reason"] as? String ?? ""
            
            guard let enteredBy = currentEntry["enteredBy"] as? String else {
                return
            }
            
            var endDate = dateTimeStamp + duration
            if endDate > maxEndDate {
                endDate = maxEndDate
            }
            
            if dateTimeStamp <= now && now < endDate {
                activeOverrideNote = currentEntry["notes"] as? String
            }
            Observable.shared.override.value = activeOverrideNote
        }
    }
}
