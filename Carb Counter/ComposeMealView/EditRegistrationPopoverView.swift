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
        ZStack {
            Color(red: 90/255, green: 104/255, blue: 125/255).opacity(0.7).edgesIgnoringSafeArea(.all) // Add background
            
            VStack(spacing: 0) {
                Form {
                    Section(header: Text("EditRegistration.Header".localized).padding(.top, 12).padding(.bottom, 12)) {
                        VStack(spacing: 0) {
                            ForEach([
                                ("EditRegistration.Carbs".localized, $registeredCarbsSoFar),
                                ("EditRegistration.Fat".localized, $registeredFatSoFar),
                                ("EditRegistration.Protein".localized, $registeredProteinSoFar),
                                ("EditRegistration.Bolus".localized, $registeredBolusSoFar)
                            ], id: \.0) { label, binding in
                                HStack {
                                    Text(label)
                                    Spacer()
                                    TextField(label, text: Binding(
                                        get: {
                                            binding.wrappedValue == 0 ? "" : formatValue(binding.wrappedValue)
                                        },
                                        set: {
                                            binding.wrappedValue = Double($0) ?? 0
                                        }
                                    ))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                                    Text(label == "EditRegistration.Bolus".localized ? "EditRegistration.BolusMeasurement".localized : "EditRegistration.WeightMeasurement".localized)
                                }
                                .padding(.vertical, 12)
                                
                                Divider()
                            }
                            
                            HStack {
                                Text("EditRegistration.MealTime".localized)
                                Spacer()
                                DatePicker("", selection: Binding(get: {
                                    self.mealDate ?? Date()
                                }, set: {
                                    self.mealDate = $0
                                }), displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.white.opacity(0.1))
                }
                .scrollContentBackground(.hidden)
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    onDismiss?()
                }) {
                    Text("EditRegistration.Done".localized)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 15)
            }
        }
    }
}

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}
