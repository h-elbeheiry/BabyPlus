//
//  BreastPickerView.swift
//  BabyPlus
//
//  Created by Hussein Elbeheiry on 9/25/23.
//

import Factory
import MabyKit
import SwiftUI
import Foundation
import Combine

struct BreastPicker: View {
    @Binding var breast: NursingEvent.Breast?

    var body: some View {
        HStack {
            Button(action: { breast = .left }) {
                Text("Left")
                    .padding()
                    .foregroundColor(breast == .left ? .white : .black)
                    .background(breast == .left ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }

            Button(action: { breast = .right }) {
                Text("Right")
                    .padding()
                    .foregroundColor(breast == .right ? .white : .black)
                    .background(breast == .right ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }

            Button(action: { breast = .both }) {
                Text("Both")
                    .padding()
                    .foregroundColor(breast == .both ? .white : .black)
                    .background(breast == .both ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }
        }
    }
}
