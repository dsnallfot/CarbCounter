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

        //Debug logging
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
