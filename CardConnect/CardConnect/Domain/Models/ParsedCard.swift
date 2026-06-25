// ParsedCard.swift
// CardConnect
// Geçici model — SwiftData'ya kaydedilmez.

import Foundation

struct ParsedCard {
    var firstName: String = ""
    var lastName: String = ""
    var company: String = ""
    var title: String = ""
    var phones: [String] = []
    var emails: [String] = []
    var address: String = ""
    var linkedin: String = ""
    var notes: String = ""
}
