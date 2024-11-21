//
//  OverrideView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//

import SwiftUI
import HealthKit

struct CustomBackgroundContainer: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        ZStack {
            // Background layer
            Group {
                if colorScheme == .dark {
                    // Gradient background for dark mode
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.15),
                            Color.blue.opacity(0.25),
                            Color.blue.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                } else {
                    // Light mode background
                    Color(UIColor.systemGray6)
                        .ignoresSafeArea()
                }
            }
            
            // Content layer
            content
                .scrollContentBackground(.hidden) // This hides the default Form background
        }
    }
}

struct CustomListRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.primary.opacity(0.08))
    }
}

protocol OverrideViewDelegate: AnyObject {
    func didActivateOverride(percentage: Double)
    func didCancelOverride()
}

struct OverrideView: View {
    @Environment(\.presentationMode) private var presentationMode
    private let pushNotificationManager = PushNotificationManager()

    @ObservedObject var device = ObservableUserDefaults.shared.device
    @ObservedObject var overrideNote = Observable.shared.override
    
    weak var delegate: OverrideViewDelegate?

    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var alertMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil

    @State private var selectedOverride: ProfileManager.TrioOverride? = nil
    @State private var showConfirmation: Bool = false

    @FocusState private var noteFieldIsFocused: Bool

    private var profileManager = ProfileManager.shared
    

    enum AlertType {
        case confirmActivation
        case confirmCancellation
        case statusSuccess
        case statusFailure
        case validation
    }

    var body: some View {
        NavigationView {
            VStack {
                    Form {
                        if let activeNote = overrideNote.value {
                            Section(header: Text("Aktiv Override")) {
                                HStack {
                                    Text(activeNote)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Button {
                                        alertType = .confirmCancellation
                                        showAlert = true
                                    } label: {
                                        Image(systemName: "xmark.square.fill")
                                            .font(.title2)
                                    }
                                    .tint(.red)
                                }
                                .modifier(CustomListRowStyle())
                                .onAppear {
                                    if let matchedOverride = profileManager.trioOverrides.first(where: { $0.name == activeNote }) {
                                        if let percentage = matchedOverride.percentage {
                                            print("Matched override percentage: \(percentage)")
                                            delegate?.didActivateOverride(percentage: percentage)
                                        } else {
                                            print("Matched override has no percentage")
                                        }
                                    } else {
                                        print("No matching override found for activeNote: \(activeNote)")
                                    }
                                }
                            }
                        }

                        Section(header: Text("Tillgängliga Overrides")) {
                            if profileManager.trioOverrides.isEmpty {
                                Text("Inga tillgängliga overrides.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(profileManager.trioOverrides, id: \.name) { override in
                                    Button(action: {
                                        selectedOverride = override
                                        alertType = .confirmActivation
                                        showAlert = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(override.name)
                                                    .font(.headline)
                                                if let duration = override.duration {
                                                    Text("Varaktighet: \(Int(duration)) minuter")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }
                                                if let percentage = override.percentage {
                                                    Text("Procent: \(Int(percentage))%")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }

                                                if let target = override.target {
                                                    Text("Mål: \(Localizer.formatQuantity(target)) \(UserDefaultsRepository.getPreferredUnit().localizedShortUnitString)")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.right.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.title2)
                                        }
                                    }
                                    .modifier(CustomListRowStyle())
                                }
                            }
                        }
                    }
                    .modifier(CustomBackgroundContainer())

                    if isLoading {
                        ProgressView("Vänta...")
                            .padding()
                    }
                }
            .navigationTitle("Overrides")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(action: closeButtonTapped) {
                ZStack {
                    // Circle background
                    Image(systemName: "circle.fill")
                        .opacity(0.08)
                        .foregroundColor(.primary)
                        .font(.system(size: 23)) // Adjusted size for the circle
                        .offset(x: -6) // Move the circle slightly to the left
                    
                    // Xmark symbol
                    Image(systemName: "xmark")
                        .opacity(0.5)
                        .foregroundColor(.primary)
                        .font(.system(size: 12, weight: .bold)) // Adjusted size and weight to semibold
                        .offset(x: -6) // Align with the circle
                }
            })
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .confirmActivation:
                    return Alert(
                        title: Text("Aktivera Override"),
                        message: Text("Vill du aktivera overriden '\(selectedOverride?.name ?? "")'?"),
                        primaryButton: .default(Text("Bekräfta"), action: {
                            if let override = selectedOverride {
                                activateOverride(override)
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                case .confirmCancellation:
                    return Alert(
                        title: Text("Avsluta Override"),
                        message: Text("Är du säker på att du vill avsluta den aktiva overriden?"),
                        primaryButton: .default(Text("Bekräfta"), action: {
                            cancelOverride()
                        }),
                        secondaryButton: .cancel()
                    )
                case .statusSuccess:
                    return Alert(
                        title: Text("Lyckades"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"), action: {
                            presentationMode.wrappedValue.dismiss()
                        })
                    )
                case .statusFailure:
                    return Alert(
                        title: Text("Fel"),
                        message: Text(statusMessage ?? "Ett fel uppstod."),
                        dismissButton: .default(Text("OK"))
                    )
                case .validation:
                    return Alert(
                        title: Text("Validation Error"),
                        message: Text(alertMessage ?? "Invalid input."),
                        dismissButton: .default(Text("OK"))
                    )
                case .none:
                    return Alert(title: Text("Unknown Alert"))
                }
            }
        }
    }

    // MARK: - Functions

    private func closeButtonTapped() {
        presentationMode.wrappedValue.dismiss()
    }
    
    private func activateOverride(_ override: ProfileManager.TrioOverride) {
        isLoading = true

        pushNotificationManager.sendOverridePushNotification(override: override) { success, errorMessage in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.statusMessage = "Override skickades"
                    self.alertType = .statusSuccess
                    delegate?.didActivateOverride(percentage: override.percentage ?? 100)
                } else {
                    self.statusMessage = errorMessage ?? "Override misslyckades."
                    self.alertType = .statusFailure
                }
                self.showAlert = true
            }
        }
    }

    private func cancelOverride() {
        isLoading = true

        pushNotificationManager.sendCancelOverridePushNotification { success, errorMessage in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.statusMessage = "Avbryt override lyckades."
                    self.alertType = .statusSuccess
                    self.delegate?.didCancelOverride()
                } else {
                    self.statusMessage = errorMessage ?? "Avbryt override misslyckades."
                    self.alertType = .statusFailure
                }
                self.showAlert = true
            }
        }
    }
}
