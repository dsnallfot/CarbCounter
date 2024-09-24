//
//  Formatters.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-09-24.
//

import Foundation

public extension Character {
    var isWhitespaceOrNewline: Bool {
        return isWhitespace || isNewline
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
