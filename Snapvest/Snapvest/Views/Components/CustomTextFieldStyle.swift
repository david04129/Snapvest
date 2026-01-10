//
//  CustomTextFieldStyle.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.secondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondaryText.opacity(0.2), lineWidth: 1)
            )
    }
}

