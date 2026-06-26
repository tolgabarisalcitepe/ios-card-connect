// EventMatchViewModel.swift
// CardConnect

import Foundation

enum EventMatchState {
    case loading
    case active([CalendarEvent])   // bugün aktif etkinlikler
    case list([CalendarEvent])     // geçmiş etkinlik listesi
    case empty                     // etkinlik yok / izin yok
}

@MainActor
final class EventMatchViewModel: ObservableObject {
    @Published var state: EventMatchState = .loading

    // TODO: Epic 4 #113 — takvim izni + loadEvents
    func loadEvents(calendarService: CalendarService) async {
        state = .empty
    }

    // TODO: Epic 4 #114 — Contact.eventId/eventName güncelle + notes append
    func selectEvent(_ event: CalendarEvent, for contactID: UUID) async -> Bool {
        return false
    }
}
