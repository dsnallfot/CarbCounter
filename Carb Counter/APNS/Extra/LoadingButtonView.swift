//
//  LoadingButtonView.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-11-15.
//

import SwiftUI

struct LoadingButtonView: View {
    var buttonText: String
    var progressText: String
    var isLoading: Bool
    var action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Section {
            VStack {
                if isLoading {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 10)
                        Text(progressText)
                    }
                    .padding()
                } else {
                    Button(action: {
                        action()
                    }) {
                        Text(buttonText)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isDisabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowInsets(EdgeInsets())
        }
    }
}
