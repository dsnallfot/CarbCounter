//
//  Treatments.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-16.
//

import Foundation
extension ComposeMealViewController {
    // NS Treatments Web Call
    // Downloads Basal, Bolus, Carbs, BG Check, Notes, Overrides
    func WebLoadNSTreatments(completion: @escaping () -> Void) {
        
        let startTimeString = dateTimeUtils.getDateTimeString(addingDays: -1)
        let currentTimeString = dateTimeUtils.getDateTimeString(addingHours: 6)
        let parameters: [String: String] = [
            "find[created_at][$gte]": startTimeString,
            "find[created_at][$lte]": currentTimeString
        ]
        NightscoutUtils.executeDynamicRequest(eventType: .treatments, parameters: parameters) { (result: Result<Any, Error>) in
            switch result {
            case .success(let data):
                if let entries = data as? [[String: AnyObject]] {
                    DispatchQueue.main.async {
                        self.updateTreatments(entries: entries)
                    }
                } else {
                    print("Error: Unexpected data structure")
                }
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
        DispatchQueue.main.async {
                completion()
            }
    }
    
    // Process and split out treatments to individual tasks
    func updateTreatments(entries: [[String:AnyObject]]) {
        
        var tempBasal: [[String:AnyObject]] = []
        var bolus: [[String:AnyObject]] = []
        var smb: [[String:AnyObject]] = []
        var carbs: [[String:AnyObject]] = []
        var temporaryOverride: [[String:AnyObject]] = []
        var temporaryTarget: [[String:AnyObject]] = []
        var note: [[String:AnyObject]] = []
        var bgCheck: [[String:AnyObject]] = []
        var suspendPump: [[String:AnyObject]] = []
        var resumePump: [[String:AnyObject]] = []
        var pumpSiteChange: [cageData] = []
        var cgmSensorStart: [sageData] = []
        var insulinCartridge: [iageData] = []
        
        struct cageData: Codable {
            var created_at: String
        }

        struct sageData: Codable {
            var created_at: String
        }

        struct iageData: Codable {
            var created_at: String
        }

        for entry in entries {
            guard let eventType = entry["eventType"] as? String else {
                continue
            }
            
            switch eventType {
            case "Temp Basal":
                tempBasal.append(entry)
            case "Correction Bolus", "Bolus":
                if let automatic = entry["automatic"] as? Bool, automatic {
                    smb.append(entry)
                } else {
                    bolus.append(entry)
                }
            case "SMB":
                smb.append(entry)
            case "Meal Bolus":
                carbs.append(entry)
                bolus.append(entry)
            case "Carb Correction":
                carbs.append(entry)
            case "Temporary Override", "Exercise":
                temporaryOverride.append(entry)
            case "Temporary Target":
                temporaryTarget.append(entry)
            case "Note":
                note.append(entry)
            case "BG Check":
                bgCheck.append(entry)
            case "Suspend Pump":
                suspendPump.append(entry)
            case "Resume Pump":
                resumePump.append(entry)
            case "Pump Site Change", "Site Change":
                if let createdAt = entry["created_at"] as? String {
                    let newEntry = cageData(created_at: createdAt)
                    pumpSiteChange.append(newEntry)
                }
            case "Sensor Start":
                if let createdAt = entry["created_at"] as? String {
                    let newEntry = sageData(created_at: createdAt)
                    cgmSensorStart.append(newEntry)
                }
            case "Insulin Change":
                if let createdAt = entry["created_at"] as? String {
                    let newEntry = iageData(created_at: createdAt)
                    insulinCartridge.append(newEntry)
                }
            default:
                print("No Match: \(String(describing: entry))")
            }
        }
        if temporaryOverride.count > 0 {
            processNSOverrides(entries: temporaryOverride)
        }
    }
}
