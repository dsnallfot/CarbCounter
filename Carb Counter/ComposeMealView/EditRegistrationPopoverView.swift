//
//  EditRegistrationPopoverView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-09-18.
//

import SwiftUI

struct EditRegistrationPopoverView: View {
    @Binding var registeredFatSoFar: Double
    @Binding var registeredProteinSoFar: Double
    @Binding var registeredBolusSoFar: Double
    @Binding var registeredCarbsSoFar: Double
    @Binding var mealDate: Date?

    @Environment(\.presentationMode) var presentationMode

    var onDismiss: (() -> Void)?

    // Custom formatter to remove trailing zeros
    private func formatValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value) // No decimal places if it's a whole number
        } else {
            return String(format: "%.1f", value).replacingOccurrences(of: ".0", with: "") // Show one decimal places, but remove ".0"
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Edit registration").font(.subheadline)) {
                HStack {
                    Text("Carbs")
                    Spacer()
                    TextField("Carbs", text: Binding(
                        get: {
                            registeredCarbsSoFar == 0 ? "" : formatValue(registeredCarbsSoFar)
                        },
                        set: {
                            registeredCarbsSoFar = Double($0) ?? 0
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    Text("g")
                }
                HStack {
                    Text("Fat")
                    Spacer()
                    TextField("Fat", text: Binding(
                        get: {
                            registeredFatSoFar == 0 ? "" : formatValue(registeredFatSoFar)
                        },
                        set: {
                            registeredFatSoFar = Double($0) ?? 0
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    Text("g")
                }
                HStack {
                    Text("Protein")
                    Spacer()
                    TextField("Protein", text: Binding(
                        get: {
                            registeredProteinSoFar == 0 ? "" : formatValue(registeredProteinSoFar)
                        },
                        set: {
                            registeredProteinSoFar = Double($0) ?? 0
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    Text("g")
                }
                HStack {
                    Text("Bolus")
                    Spacer()
                    TextField("Bolus", text: Binding(
                        get: {
                            registeredBolusSoFar == 0 ? "" : String(format: "%.2f", registeredBolusSoFar)
                        },
                        set: {
                            registeredBolusSoFar = Double($0) ?? 0
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    Text("E")
                }
                HStack {
                    Text("Meal time")
                    Spacer()
                    DatePicker("", selection: Binding(get: {
                        self.mealDate ?? Date()
                    }, set: {
                        self.mealDate = $0
                    }), displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                }
            }

            Button(action: {
                presentationMode.wrappedValue.dismiss()
                onDismiss?()
            }) {
                Text("Done")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}
