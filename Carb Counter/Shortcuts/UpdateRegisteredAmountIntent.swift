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
    var khValue: String

    @Parameter(title: "Fett (g)")
    var fatValue: String

    @Parameter(title: "Protein (g)")
    var proteinValue: String

    @Parameter(title: "Bolus (E)")
    var bolusValue: String

    @Parameter(title: "Startdos", default: false)
    var startDose: Bool

    func perform() async throws -> some IntentResult {
        // Call the function on the shared instance
        await ComposeMealViewController.shared?.updateRegisteredAmount(
            khValue: khValue,
            fatValue: fatValue,
            proteinValue: proteinValue,
            bolusValue: bolusValue,
            startDose: startDose
        )
        return .result()
    }
}
