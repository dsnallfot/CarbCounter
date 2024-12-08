//
//  OverrideView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//

import SwiftUI
import HealthKit
import AudioToolbox
import LocalAuthentication
import ObjectiveC

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
    @State private var coordinator: OverrideViewCoordinator
    @Environment(\.presentationMode) internal var presentationMode
    private let pushNotificationManager = PushNotificationManager()
    
    @ObservedObject var device = ObservableUserDefaults.shared.device
    @ObservedObject var overrideNote = Observable.shared.override
    
    weak var delegate: OverrideViewDelegate?
    
    @State internal var showAlert: Bool = false
    @State internal var alertType: AlertType? = nil
    @State internal var alertMessage: String? = nil
    //@State internal var isLoading: Bool = false
    @State internal var statusMessage: String? = nil
    
    @State internal var selectedOverride: ProfileManager.TrioOverride? = nil
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
                                        self.alertType = .confirmCancellation
                                        self.showAlert = true
                                    } label: {
                                        Image(systemName: "xmark.square.fill")
                                            .font(.title2)
                                    }
                                    .tint(.white)
                                }
                                //.modifier(CustomListRowStyle())
                                .onAppear {
                                    if let matchedOverride = self.profileManager.trioOverrides.first(where: { $0.name == activeNote }) {
                                        if let percentage = matchedOverride.percentage {
                                            print("Matched override percentage: \(percentage)")
                                            self.delegate?.didActivateOverride(percentage: percentage)
                                        } else {
                                            print("Matched override has no percentage, activating override in composemealVC but setting override % to 100")
                                            self.delegate?.didActivateOverride(percentage: 100)
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
                                        self.delegate?.didCancelOverride()
                                    }
                            } else {
                                ForEach(profileManager.trioOverrides, id: \.name) { override in
                                    Button(action: {
                                        self.selectedOverride = override
                                        self.alertType = .confirmActivation
                                        self.showAlert = true
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

                    /*if isLoading {
                        ProgressView("Vänta...")
                            .padding()
                    }*/
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
            self.updateMethodText()
            if self.overrideNote.value == nil {
                self.delegate?.didCancelOverride()
            }
        }
        .alert(isPresented: $showAlert) {
            switch alertType {
            case .confirmActivation:
                return Alert(
                        title: Text("Aktivera Override"),
                        message: Text("Vill du aktivera overriden '\(selectedOverride?.name ?? "")'?"),
                        primaryButton: .default(Text("Bekräfta"), action: {
                            if let override = self.selectedOverride {
                                self.activateOverride(override)
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                case .confirmCancellation:
                    return Alert(
                        title: Text("Avsluta Override"),
                        message: Text("Är du säker på att du vill avsluta den aktiva overriden?"),
                        primaryButton: .default(Text("Bekräfta"), action: {
                            self.cancelOverride()
                        }),
                        secondaryButton: .cancel()
                    )
                case .statusSuccess:
                    return Alert(
                        title: Text("Lyckades"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"), action: {
                            self.presentationMode.wrappedValue.dismiss()
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
                if self.overrideNote.value == nil {
                            print("No active override found, cancelling.")
                    self.delegate?.didCancelOverride()
                        }
                    }
            .onAppear {
                self.updateMethodText()
                if self.overrideNote.value == nil {
                    self.delegate?.didCancelOverride()
                }
                coordinator.setupShortcutObservers(for: self)
            }
            .onDisappear {
                coordinator.removeShortcutObservers()
            }
        }
    }

    // MARK: - Functions
    
    init(delegate: OverrideViewDelegate? = nil) {
            let coord = OverrideViewCoordinator()
            coord.delegate = delegate
            _coordinator = State(initialValue: coord)
        }

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
    
    // Function to format date to ISO 8601 without seconds and milliseconds
        func formatDateToISO8601(_ date: Date) -> String {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
            return dateFormatter.string(from: date)
        }
    
    private func createCombinedString(for override: ProfileManager.TrioOverride) -> String {
        let caregiverName = UserDefaultsRepository.caregiverName
        let remoteSecretCode = UserDefaultsRepository.remoteSecretCode
        
        // Get the current timestamp and format to ISO 8601
        let currentTimestamp = Date()
        let formattedTimestamp = formatDateToISO8601(currentTimestamp)

        // Use only the required format for iOS Shortcuts and Twilio
        //return "Remote Override\n\(override.name)\nInlagt av: \(caregiverName)\nHemlig kod: \(remoteSecretCode)"
        return "Remote Override\n\(override.name)\nInlagt av: \(caregiverName)\nSecret: \(remoteSecretCode)\nSkickades: \(formattedTimestamp)"
    }

    private func activateOverride(_ override: ProfileManager.TrioOverride) {
        //isLoading = true

        let combinedString = createCombinedString(for: override)

        sendOverrideRequest(override: override, combinedString: combinedString) { result in
            DispatchQueue.main.async {
                //self.isLoading = false
                switch result {
                case .success:
                    // Play a success sound
                    AudioServicesPlaySystemSound(SystemSoundID(1322))
                    
                    // Update the Observable override valuev immediately to avoid it getting blank in composemealVC until ns is updated and treatments re-fetched
                    Observable.shared.override.value = override.name
                    
                    // Show the success view
                    let successView = SuccessView()
                    if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                        successView.showInView(keyWindow)
                    }
                    
                    // Dismiss the modal after showing the success view
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                    
                    self.delegate?.didActivateOverride(percentage: override.percentage ?? 100)
                case .failure(let error):
                    // Play failure sound
                    AudioServicesPlaySystemSound(SystemSoundID(1053))
                    
                    self.statusMessage = error.localizedDescription
                    self.alertType = .statusFailure
                    self.showAlert = true
                }
            }
        }
    }

    private func sendOverrideRequest(override: ProfileManager.TrioOverride, combinedString: String, completion: @escaping (Result<Void, Error>) -> Void) {
            if UserDefaultsRepository.method == "iOS Shortcuts" {
                guard let encodedString = combinedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    completion(.failure(NetworkError.invalidURL))
                    return
                }

                // Define x-callback URLs
                let successCallback = "carbcounter://completed"
                let errorCallback = "carbcounter://error"
                let cancelCallback = "carbcounter://cancel"
                let passcodeCallback = "carbcounter://passcode"

                guard let successEncoded = successCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let errorEncoded = errorCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let cancelEncoded = cancelCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let passcodeEncoded = passcodeCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    completion(.failure(NetworkError.invalidURL))
                    return
                }

                let urlString = "shortcuts://x-callback-url/run-shortcut?name=CC%20Override&input=text&text=\(encodedString)&x-success=\(successEncoded)&x-error=\(errorEncoded)&x-cancel=\(cancelEncoded)&x-passcode=\(passcodeEncoded)"
                            
                            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url, options: [:]) { success in
                                    if success {
                                        print("Shortcut successfully triggered")
                                        Observable.shared.override.value = override.name
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
                    Observable.shared.override.value = override.name
                } else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "Unknown error"])
                    completion(.failure(error))
                }
            }
        } else {
            authenticateUser { authenticated in
                if authenticated {
                    self.twilioRequest(combinedString: combinedString, completion: completion)
                    Observable.shared.override.value = override.name
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
        //isLoading = true

        let caregiverName = UserDefaultsRepository.caregiverName
        let remoteSecretCode = UserDefaultsRepository.remoteSecretCode
        
        // Get the current timestamp and format to ISO 8601
        let currentTimestamp = Date()
        let formattedTimestamp = formatDateToISO8601(currentTimestamp)
        
        //let combinedString = "Remote Override\n🚫 Avbryt Override\nInlagt av: \(caregiverName)\nHemlig kod: \(remoteSecretCode)"
        let combinedString = "Remote Override\n🚫 Avbryt Override\nInlagt av: \(caregiverName)\nSecret: \(remoteSecretCode)\nSkickades: \(formattedTimestamp)"

        if UserDefaultsRepository.method == "iOS Shortcuts" {
            guard let encodedString = combinedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                DispatchQueue.main.async {
                    //self.isLoading = false

                    // Play failure sound
                    AudioServicesPlaySystemSound(SystemSoundID(1053))

                    self.statusMessage = "Kan inte koda URL-strängen."
                    self.alertType = .statusFailure
                    self.showAlert = true
                }
                return
            }

            // Define x-callback URLs
            let successCallback = "carbcounter://completed"
            let errorCallback = "carbcounter://error"
            let cancelCallback = "carbcounter://cancel"
            let passcodeCallback = "carbcounter://passcode"

            guard let successEncoded = successCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let errorEncoded = errorCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let cancelEncoded = cancelCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let passcodeEncoded = passcodeCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                DispatchQueue.main.async {
                    //self.isLoading = false

                    // Play failure sound
                    AudioServicesPlaySystemSound(SystemSoundID(1053))

                    self.statusMessage = "Kan inte koda URL-strängen."
                    self.alertType = .statusFailure
                    self.showAlert = true
                }
                return
            }

            let urlString = "shortcuts://x-callback-url/run-shortcut?name=CC%20Override&input=text&text=\(encodedString)&x-success=\(successEncoded)&x-error=\(errorEncoded)&x-cancel=\(cancelEncoded)&x-passcode=\(passcodeEncoded)"
                            
            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if !success {
                        DispatchQueue.main.async {
                            //self.isLoading = false

                            // Play failure sound
                            AudioServicesPlaySystemSound(SystemSoundID(1053))

                            self.statusMessage = "Kan inte öppna genväg."
                            self.alertType = .statusFailure
                            self.showAlert = true
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    //self.isLoading = false

                    // Play failure sound
                    AudioServicesPlaySystemSound(SystemSoundID(1053))

                    self.statusMessage = "Kan inte öppna genväg."
                    self.alertType = .statusFailure
                    self.showAlert = true
                }
            }
        } else if UserDefaultsRepository.method == "Trio APNS" {
            pushNotificationManager.sendCancelOverridePushNotification { success, errorMessage in
                DispatchQueue.main.async {
                    //self.isLoading = false
                    if success {
                        // Play a success sound
                        AudioServicesPlaySystemSound(SystemSoundID(1322))

                        // Show the success view
                        let successView = SuccessView()
                        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                            successView.showInView(keyWindow)
                        }

                        // Dismiss the modal after showing the success view
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.presentationMode.wrappedValue.dismiss()
                        }

                        self.delegate?.didCancelOverride()
                    } else {
                        // Play failure sound
                        AudioServicesPlaySystemSound(SystemSoundID(1053))

                        self.statusMessage = errorMessage ?? "Avbryt override misslyckades."
                        self.alertType = .statusFailure
                        self.showAlert = true
                    }
                }
            }
        } else {
            authenticateUser { authenticated in
                DispatchQueue.main.async {
                    if authenticated {
                        self.twilioRequest(combinedString: combinedString) { result in
                            //self.isLoading = false
                            switch result {
                            case .success:
                                // Play a success sound
                                AudioServicesPlaySystemSound(SystemSoundID(1322))

                                // Show the success view
                                let successView = SuccessView()
                                if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                                    successView.showInView(keyWindow)
                                }

                                // Dismiss the modal after showing the success view
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    self.presentationMode.wrappedValue.dismiss()
                                }

                                self.delegate?.didCancelOverride()
                            case .failure(let error):
                                // Play failure sound
                                AudioServicesPlaySystemSound(SystemSoundID(1053))

                                self.statusMessage = error.localizedDescription
                                self.alertType = .statusFailure
                                self.showAlert = true
                            }
                        }
                    } else {
                        //self.isLoading = false

                        // Play failure sound
                        AudioServicesPlaySystemSound(SystemSoundID(1053))

                        self.statusMessage = "Autentisering misslyckades."
                        self.alertType = .statusFailure
                        self.showAlert = true
                    }
                }
            }
        }
    }
}

class OverrideViewNotificationHandler: NSObject {
    var view: OverrideView?
    
    @objc func handleShortcutSuccess() {
        guard let view = view else { return }
        DispatchQueue.main.async {
            // Stop loading state
            //view.isLoading = false
            
            // Play a success sound
            AudioServicesPlaySystemSound(SystemSoundID(1322))
            
            // Show the success view
            let successView = SuccessView()
            if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                successView.showInView(keyWindow)
            }
            
            // Dismiss the modal after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                view.presentationMode.wrappedValue.dismiss()
            }

            // If an override was selected, activate it
            if let selectedOverride = view.selectedOverride {
                view.delegate?.didActivateOverride(percentage: selectedOverride.percentage ?? 100)
            }
        }
    }
    
    @objc func handleShortcutError() {
        guard let view = view else { return }
        DispatchQueue.main.async {
            //view.isLoading = false
            
            // Play failure sound
            AudioServicesPlaySystemSound(SystemSoundID(1053))
            
            view.statusMessage = "Kunde inte skicka override"
            view.alertType = .statusFailure
            view.showAlert = true
        }
    }
    
    @objc func handleShortcutCancel() {
        guard let view = view else { return }
        DispatchQueue.main.async {
            //view.isLoading = false
            
            // Play failure sound
            AudioServicesPlaySystemSound(SystemSoundID(1053))
            
            view.statusMessage = "Genvägen avbröts"
            view.alertType = .statusFailure
            view.showAlert = true
            
            // Ensure delegate is notified of cancellation
            view.delegate?.didCancelOverride()
        }
    }
    
    @objc func handleShortcutPasscode() {
        guard let view = view else { return }
        DispatchQueue.main.async {
            //view.isLoading = false
            
            // Play failure sound
            AudioServicesPlaySystemSound(SystemSoundID(1053))
            
            view.statusMessage = "Felaktig lösenord"
            view.alertType = .statusFailure
            view.showAlert = true
        }
    }
}

class OverrideViewCoordinator {
    weak var delegate: OverrideViewDelegate?
    var notificationHandler: OverrideViewNotificationHandler?
    
    func setupShortcutObservers(for view: OverrideView) {
        // Create a notification handler if it doesn't exist
        if notificationHandler == nil {
            notificationHandler = OverrideViewNotificationHandler()
            notificationHandler?.view = view
        }
        
        NotificationCenter.default.addObserver(
            notificationHandler!,
            selector: #selector(OverrideViewNotificationHandler.handleShortcutSuccess),
            name: NSNotification.Name("ShortcutSuccess"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            notificationHandler!,
            selector: #selector(OverrideViewNotificationHandler.handleShortcutError),
            name: NSNotification.Name("ShortcutError"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            notificationHandler!,
            selector: #selector(OverrideViewNotificationHandler.handleShortcutCancel),
            name: NSNotification.Name("ShortcutCancel"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            notificationHandler!,
            selector: #selector(OverrideViewNotificationHandler.handleShortcutPasscode),
            name: NSNotification.Name("ShortcutPasscode"),
            object: nil
        )
    }
    
    func removeShortcutObservers() {
            guard let notificationHandler = notificationHandler else { return }
            
            NotificationCenter.default.removeObserver(notificationHandler)
        }
}

// Create a private key for associated object
private var notificationHandlerKey: UInt8 = 0
