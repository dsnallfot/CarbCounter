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

    var composeMealViewController: ComposeMealViewController?
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false

    var onDismiss: (() -> Void)?

    private func formatValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else if value * 10 == floor(value * 10) {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    private func getRoundedFont(size: CGFloat, weight: UIFont.Weight) -> Font {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            let roundedFont = UIFont(descriptor: roundedDescriptor, size: size)
            return Font(roundedFont)
        } else {
            return Font(systemFont)
        }
    }

    var body: some View {
        ZStack {
            Color(red: 90/255, green: 104/255, blue: 125/255).opacity(0.7).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                Button(action: {
                    showAlert = true
                }) {
                    HStack {
                        Spacer()
                        
                        Text("EditRegistration.Header".localized)
                            .font(getRoundedFont(size: 19, weight: .bold))
                        
                        Spacer()
                        
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                    }
                    .padding(.top, 15)
                    .padding(.trailing, 20)
                    .padding(.leading, 20)
                }
                .buttonStyle(PlainButtonStyle())
                
                Form {
                    Section {
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
                                    TextField("...", text: Binding(
                                        get: {
                                            binding.wrappedValue == 0 ? "" : formatValue(binding.wrappedValue)
                                        },
                                        set: {
                                            binding.wrappedValue = Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0
                                        }
                                    ))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                                    Text(label == "EditRegistration.Bolus".localized ? "EditRegistration.BolusMeasurement".localized : "EditRegistration.WeightMeasurement".localized)
                                }
                                .padding(.vertical, 11)
                                
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
                            .padding(.vertical, 5.5)
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
                        .font(getRoundedFont(size: 19, weight: .semibold))
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 15)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("DeleteAllValues.Title".localized),
                message: Text("DeleteAllValues.Message".localized),
                primaryButton: .destructive(Text("DeleteAllValues.Button".localized)) {
                    registeredFatSoFar = 0
                    registeredProteinSoFar = 0
                    registeredBolusSoFar = 0
                    registeredCarbsSoFar = 0
                },
                secondaryButton: .cancel(Text("Avbryt"))
            )
        }
        .onDisappear {
            composeMealViewController?.updateRemainsBolus()
            if registeredFatSoFar == 0 &&
                registeredProteinSoFar == 0 &&
                registeredBolusSoFar == 0 &&
                registeredCarbsSoFar == 0 {
                
                mealDate = nil
            }
            onDismiss?()
        }
    }
}

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}
