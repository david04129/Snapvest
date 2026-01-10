//
//  Decimal+String.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

extension Decimal {
    init?(string: String) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        
        guard let number = formatter.number(from: string) else {
            return nil
        }
        
        self = number.decimalValue
    }
}

