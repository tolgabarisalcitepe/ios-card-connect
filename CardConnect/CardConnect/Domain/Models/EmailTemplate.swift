// EmailTemplate.swift
// CardConnect

import Foundation
import SwiftData

@Model
final class EmailTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var subject: String
    var body: String
    var isDefault: Bool
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        subject: String,
        body: String,
        isDefault: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.subject = subject
        self.body = body
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }
}
