//
//  Twilio.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-23.
//

import Foundation

protocol TwilioRequestable {
    func twilioRequest(combinedString: String, completion: @escaping (Result<Void, Error>) -> Void)
}

extension TwilioRequestable {
    func twilioRequest(combinedString: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let twilioSID = UserDefaultsRepository.twilioSIDString
        let twilioSecret = UserDefaultsRepository.twilioSecretString
        let fromNumber = UserDefaultsRepository.twilioFromNumberString
        let toNumber = UserDefaultsRepository.twilioToNumberString
        let message = combinedString

        // Debug logging
        //print("Twilio SID: \(twilioSID)")
        //print("Twilio Secret: \(twilioSecret)")
        //print("From Number: \(fromNumber)")
        //print("To Number: \(toNumber)")
        //print("Message: \(message)")
        
        // Build the request
        let urlString = "https://\(twilioSID):\(twilioSecret)@api.twilio.com/2010-04-01/Accounts/\(twilioSID)/Messages"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion(.failure(NetworkError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "From=\(fromNumber)&To=\(toNumber)&Body=\(message)".data(using: .utf8)
        
        // Debug logging
        //print("Request URL: \(urlString)")
        //print("Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "nil")")
        
        // Build the completion block and send the request
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("Request failed with error: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Response Status Code: \(httpResponse.statusCode)")
                    if (200..<300).contains(httpResponse.statusCode) {
                        print("Request succeeded")
                        completion(.success(()))
                    } else {
                        let message = "HTTP Status Code: \(httpResponse.statusCode)"
                        print("Request failed with status code: \(httpResponse.statusCode)")
                        if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                            print("Response Body: \(responseBody)")
                        }
                        let error = NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                        completion(.failure(error))
                    }
                } else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response from server"])
                    print("Request failed with unexpected server response")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

enum NetworkError: Error {
    case invalidURL
}

/*
 func sendMealRequest(combinedString: String) {
     // Retrieve the method value from UserDefaultsRepository
     let method = UserDefaultsRepository.method.value
     
     if method != "SMS API" {
         // URL encode combinedString
         guard let encodedString = combinedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
             print("Failed to encode URL string")
             return
         }
         let urlString = "shortcuts://run-shortcut?name=Remote%20Meal&input=text&text=\(encodedString)"
         if let url = URL(string: urlString) {
             UIApplication.shared.open(url, options: [:], completionHandler: nil)
         }
         dismiss(animated: true, completion: nil)
     } else {
         // If method is "SMS API", proceed with sending the request
         twilioRequest(combinedString: combinedString) { result in
             switch result {
             case .success:
                 // Play success sound
                 AudioServicesPlaySystemSound(SystemSoundID(1322))
                 
                 // Show success alert
                 let alertController = UIAlertController(title: "Lyckades!", message: "Meddelandet levererades", preferredStyle: .alert)
                 alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                     // Dismiss the current view controller
                     self.dismiss(animated: true, completion: nil)
                 }))
                 self.present(alertController, animated: true, completion: nil)
             case .failure(let error):
                 // Play failure sound
                 AudioServicesPlaySystemSound(SystemSoundID(1053))
                 
                 // Show error alert
                 let alertController = UIAlertController(title: "Fel", message: error.localizedDescription, preferredStyle: .alert)
                 alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                 self.present(alertController, animated: true, completion: nil)
             }
         }
     }
 }

 
//USER SETTINGS
 +++ Section(header: "Select remote commands method", footer: "")
 <<< SegmentedRow<String>("method") { row in
     row.title = ""
     row.options = ["iOS Shortcuts", "SMS API"]
     row.value = UserDefaultsRepository.method.value
 }.onChange { row in
     guard let value = row.value else { return }
     UserDefaultsRepository.method.value = value
 }
 <<< TextRow("twilioSID"){ row in
     row.title = "Twilio SID"
     row.cell.textField.placeholder = "EnterSID"
     if (UserDefaultsRepository.twilioSIDString.value != "") {
         let maskedSecret = String(repeating: "*", count: UserDefaultsRepository.twilioSIDString.value.count)
         row.value = maskedSecret
     }
 }.onChange { row in
     UserDefaultsRepository.twilioSIDString.value = row.value ?? ""
 }
 <<< TextRow("twilioSecret"){ row in
     row.title = "Twilio Secret"
     row.cell.textField.placeholder = "EnterSecret"
     if (UserDefaultsRepository.twilioSecretString.value != "") {
         let maskedSecret = String(repeating: "*", count: UserDefaultsRepository.twilioSecretString.value.count)
         row.value = maskedSecret
     }
 }.onChange { row in
     UserDefaultsRepository.twilioSecretString.value = row.value ?? ""
     
 }
 <<< TextRow("twilioFromNumberString"){ row in
     row.title = "Twilio from Number"
     row.cell.textField.placeholder = "EnterFromNumber"
     row.cell.textField.keyboardType = UIKeyboardType.phonePad
     if (UserDefaultsRepository.twilioFromNumberString.value != "") {
         row.value = UserDefaultsRepository.twilioFromNumberString.value
     }
 }.onChange { row in
     UserDefaultsRepository.twilioFromNumberString.value =  row.value ?? ""
 }
 
 <<< TextRow("twilioToNumberString"){ row in
     row.title = "Twilio to Number"
     row.cell.textField.placeholder = "EnterToNumber"
     row.cell.textField.keyboardType = UIKeyboardType.phonePad
     if (UserDefaultsRepository.twilioToNumberString.value != "") {
         row.value = UserDefaultsRepository.twilioToNumberString.value
     }
 }.onChange { row in
     UserDefaultsRepository.twilioToNumberString.value =  row.value ?? ""
 }
 
 <<< NameRow("caregivername"){ row in
     row.title = "Caregiver Name"
     row.value = UserDefaultsRepository.caregiverName.value
     row.cell.textField.placeholder = "Enter your name"
 }.onChange { row in
     guard let value = row.value else { return }
     UserDefaultsRepository.caregiverName.value = value
 }
 
 <<< TextRow("secretcode"){ row in
     row.title = "Secret Code"
     row.value = UserDefaultsRepository.remoteSecretCode.value
     row.cell.textField.placeholder = "Enter a secret code"
 }.onChange { row in
     guard let value = row.value else { return }
     let truncatedValue = String(value.prefix(10)) // Limiting to 10 characters
     row.value = truncatedValue
     UserDefaultsRepository.remoteSecretCode.value = truncatedValue
 }
 
 
 // API settings
 static let method = UserDefaultsValue<String>(key: "method", default: "SMS API")
 
 static let twilioSIDString = UserDefaultsValue<String>(key: "twilioSIDString", default: "")
 static let twilioSecretString = UserDefaultsValue<String>(key: "twilioSecretString", default: "")
 static let twilioFromNumberString = UserDefaultsValue<String>(key: "twilioFromNumberString", default: "")
 static let twilioToNumberString = UserDefaultsValue<String>(key: "twilioToNumberString", default: "")
 
 static let caregiverName = UserDefaultsValue<String>(key: "caregiverName", default: "")
 static let remoteSecretCode = UserDefaultsValue<String>(key: "remoteSecretCode", default: "")
 
 */
