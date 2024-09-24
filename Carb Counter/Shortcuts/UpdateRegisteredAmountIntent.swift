//
//  UpdateRegisteredAmountIntent.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-08-10.
//

import AppIntents

struct UpdateRegisteredAmountIntent: AppIntent {
    static var title: LocalizedStringResource = "Uppdatera registrerad mängd"
    static var description = IntentDescription("Uppdatera registrerad mängd kh, fett, protein och bolus.")

    @Parameter(title: "Kolhydrater (g)")
    var khValue: Double

    @Parameter(title: "Fett (g)")
    var fatValue: Double

    @Parameter(title: "Protein (g)")
    var proteinValue: Double

    @Parameter(title: "Bolus (E)")
    var bolusValue: Double

    @Parameter(title: "Startdos", default: false)
    var startDose: Bool

    func perform() async throws -> some IntentResult {
        // Convert Double values to String
        let khValueString = String(format: "%.1f", khValue)  // Convert to string with 2 decimal places
        let fatValueString = String(format: "%.1f", fatValue)
        let proteinValueString = String(format: "%.1f", proteinValue)
        let bolusValueString = String(format: "%.2f", bolusValue)
        
        // Call the function on the shared instance with converted strings
        await ComposeMealViewController.shared?.updateRegisteredAmount(
            khValue: khValueString,
            fatValue: fatValueString,
            proteinValue: proteinValueString,
            bolusValue: bolusValueString,
            startDose: startDose
        )
        return .result()
    }
}
