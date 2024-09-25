//
//  CKShareTransformer.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-09-25.
//

import Foundation
import CloudKit

class CKShareTransformer: ValueTransformer {

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let share = value as? CKShare else { return nil }
        do {
            // Use NSKeyedArchiver to encode the CKShare object
            let data = try NSKeyedArchiver.archivedData(withRootObject: share, requiringSecureCoding: true)
            return data
        } catch {
            print("Failed to encode CKShare: \(error)")
            return nil
        }
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        do {
            // Use NSKeyedUnarchiver to decode the CKShare object
            let share = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKShare.self, from: data)
            return share
        } catch {
            print("Failed to decode CKShare: \(error)")
            return nil
        }
    }
}

