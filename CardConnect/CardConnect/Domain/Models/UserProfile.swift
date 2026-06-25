// UserProfile.swift
// CardConnect
// Keychain'de saklanır — SwiftData'ya kaydedilmez.

import Foundation

struct UserProfile: Codable {
    var firstName: String = ""
    var lastName: String = ""
    var company: String = ""
    var title: String = ""
    var phone: String = ""
    var email: String = ""
    var linkedin: String = ""
    var website: String = ""
    var avatarPath: String = ""
    var frontCardPath: String = ""
    var backCardPath: String = ""

    var fullName: String {
        [firstName, lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var initials: String {
        let parts = [firstName.prefix(1), lastName.prefix(1)]
        return parts.joined()
    }
}
