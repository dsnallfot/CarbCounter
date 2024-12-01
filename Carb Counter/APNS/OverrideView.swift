//
//  OverrideView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//

import SwiftUI
import HealthKit
import LocalAuthentication

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

struct OverrideView: View, TwilioRequestable {
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
    @State private var methodText: String = ""
    
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
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button {
                                        alertType = .confirmCancellation
                                        showAlert = true
                                    } label: {
                                        Image(systemName: "xmark.square.fill")
                                            .font(.title2)
                                    }
                                    .tint(.white)
                                }
                                //.modifier(CustomListRowStyle())
                                .onAppear {
                                    if let matchedOverride = profileManager.trioOverrides.first(where: { $0.name == activeNote }) {
                                        if let percentage = matchedOverride.percentage {
                                            print("Matched override percentage: \(percentage)")
                                            delegate?.didActivateOverride(percentage: percentage)
                                        } else {
                                            print("Matched override has no percentage, activating override in composemealVC but setting override % to 100")
                                            delegate?.didActivateOverride(percentage: 100)
                                        }
                                    } else {
                                        print("No matching override found for activeNote: \(activeNote)")
                                    }
                                }
                            }
                            .listRowBackground(Color.purple.opacity(0.8))
                        }
                        
                        Section(header: Text("Tillgängliga Overrides")) {
                            if profileManager.trioOverrides.isEmpty {
                                Text("Inga tillgängliga overrides.")
                                    .foregroundColor(.secondary)
                                    .onAppear {
                                        print("No available overrides found, cancelling.")
                                        delegate?.didCancelOverride()
                                    }
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
                                                .foregroundColor(.purple.opacity(0.7))
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
            },
                                trailing: Text(methodText)
                .font(.footnote)
                .foregroundColor(.gray)
            )
        .onAppear {
            updateMethodText()
            if overrideNote.value == nil {
                delegate?.didCancelOverride()
            }
        }
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
            .onAppear {
                        if overrideNote.value == nil {
                            print("No active override found, cancelling.")
                            delegate?.didCancelOverride()
                        }
                    }
        }
    }

    // MARK: - Functions

    private func closeButtonTapped() {
        presentationMode.wrappedValue.dismiss()
    }

private func updateMethodText() {
    if UserDefaultsRepository.method == "iOS Shortcuts" {
        methodText = NSLocalizedString("ⓘ  iOS Genväg", comment: "ⓘ  iOS Genväg")
    } else if UserDefaultsRepository.method == "Trio APNS" {
        methodText = NSLocalizedString("ⓘ  Trio APNS", comment: "ⓘ  Trio APNS")
    } else {
        methodText = NSLocalizedString("ⓘ  Twilio SMS", comment: "ⓘ  Twilio SMS")
    }
}
    
    private func createCombinedString(for override: ProfileManager.TrioOverride) -> String {
        let caregiverName = UserDefaultsRepository.caregiverName
        let remoteSecretCode = UserDefaultsRepository.remoteSecretCode

        // Use only the required format for iOS Shortcuts and Twilio
        return "Remote Override\n\(override.name)\nInlagt av: \(caregiverName)\nHemlig kod: \(remoteSecretCode)"
    }

    private func activateOverride(_ override: ProfileManager.TrioOverride) {
        isLoading = true

        // Combine the override details into a string
        let combinedString = createCombinedString(for: override)

        // Send the override request based on the selected method
        sendOverrideRequest(override: override, combinedString: combinedString) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success:
                    self.statusMessage = "Override skickades"
                    self.alertType = .statusSuccess
                    delegate?.didActivateOverride(percentage: override.percentage ?? 100)
                case .failure(let error):
                    self.statusMessage = error.localizedDescription
                    self.alertType = .statusFailure
                }
                self.showAlert = true
            }
        }
    }

    private func sendOverrideRequest(override: ProfileManager.TrioOverride, combinedString: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if UserDefaultsRepository.method == "iOS Shortcuts" {
            guard let encodedString = combinedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                completion(.failure(NetworkError.invalidURL))
                return
            }
            let urlString = "shortcuts://run-shortcut?name=CC%20Override&input=text&text=\(encodedString)"
            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        print("Shortcut succesfully triggered")
                        completion(.success(())) // Daniel ToDO: Change to X callback url shortcut for correct handling success/errors
                    } else {
                        completion(.failure(NetworkError.invalidURL))
                    }
                }
            } else {
                completion(.failure(NetworkError.invalidURL))
            }
        } else if UserDefaultsRepository.method == "Trio APNS" {
            pushNotificationManager.sendOverridePushNotification(override: override) { success, errorMessage in
                if success {
                    completion(.success(()))
                } else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "Unknown error"])
                    completion(.failure(error))
                }
            }
        } else {
            authenticateUser { authenticated in
                if authenticated {
                    self.twilioRequest(combinedString: combinedString, completion: completion)
                } else {
                    completion(.failure(NetworkError.invalidURL))
                }
            }
        }
    }
    
    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate with biometrics to proceed"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        completion(true)
                    } else {
                        if let error = authenticationError as NSError?,
                           error.code == LAError.biometryNotAvailable.rawValue || error.code == LAError.biometryNotEnrolled.rawValue || error.code == LAError.biometryLockout.rawValue {
                            self.authenticateWithPasscode(completion: completion)
                        } else {
                            completion(false)
                        }
                    }
                }
            }
        } else {
            authenticateWithPasscode(completion: completion)
        }
    }
    
    private func authenticateWithPasscode(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        let reason = "Authenticate with passcode to proceed"
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }

    private func cancelOverride() {
        isLoading = true

        // Create the combined string using the hardcoded override name
        let caregiverName = UserDefaultsRepository.caregiverName
        let remoteSecretCode = UserDefaultsRepository.remoteSecretCode
        let combinedString = "Remote Override\n🚫 Avbryt Override\nInlagt av: \(caregiverName)\nHemlig kod: \(remoteSecretCode)"

        if UserDefaultsRepository.method == "iOS Shortcuts" {
            // Encode the combined string for use in the URL
            guard let encodedString = combinedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.statusMessage = "Fel: Kan inte koda URL-strängen."
                    self.alertType = .statusFailure
                    self.showAlert = true
                }
                return
            }
            let urlString = "shortcuts://run-shortcut?name=CC%20Override&input=text&text=\(encodedString)"
            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if success {
                            self.statusMessage = "Avbryt override lyckades."
                            self.alertType = .statusSuccess
                            self.delegate?.didCancelOverride()
                        } else {
                            self.statusMessage = "Fel: Kan inte öppna genväg."
                            self.alertType = .statusFailure
                        }
                        self.showAlert = true
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.statusMessage = "Fel: Kan inte öppna genväg."
                    self.alertType = .statusFailure
                    self.showAlert = true
                }
            }
        } else if UserDefaultsRepository.method == "Trio APNS" {
            // Use existing Trio APNS logic
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
        } else {
            // Twilio SMS logic
            self.authenticateUser { authenticated in
                DispatchQueue.main.async {
                    if authenticated {
                        self.twilioRequest(combinedString: combinedString) { result in
                            self.isLoading = false
                            switch result {
                            case .success:
                                self.statusMessage = "Avbryt override lyckades."
                                self.alertType = .statusSuccess
                                self.delegate?.didCancelOverride()
                            case .failure(let error):
                                self.statusMessage = error.localizedDescription
                                self.alertType = .statusFailure
                            }
                            self.showAlert = true
                        }
                    } else {
                        self.isLoading = false
                        self.statusMessage = "Autentisering misslyckades."
                        self.alertType = .statusFailure
                        self.showAlert = true
                    }
                }
            }
        }
    }
}
