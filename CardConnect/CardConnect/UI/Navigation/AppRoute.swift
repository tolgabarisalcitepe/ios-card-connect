// AppRoute.swift
// CardConnect
// String route yasaktır — tüm navigation bu enum üzerinden yapılır.

import Foundation

enum AppRoute: Hashable {
    case home
    case camera
    case confirm
    case duplicate(contactID: UUID)
    case eventMatch(contactID: UUID)
    case detail(contactID: UUID)
    case edit(contactID: UUID)
    case mailCompose(contactID: UUID)
    case templateEdit(templateID: UUID)
    case templates
    case profile
    case settings
    case privacyPolicy
}
