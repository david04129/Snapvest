//
//  User.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

struct User: Identifiable, Codable {
    let id: String
    var email: String
    var displayName: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(id: String = UUID().uuidString,
         email: String,
         displayName: String? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

