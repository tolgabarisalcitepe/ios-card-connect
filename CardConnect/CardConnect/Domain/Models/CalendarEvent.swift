// CalendarEvent.swift
// CardConnect

import Foundation

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
}
