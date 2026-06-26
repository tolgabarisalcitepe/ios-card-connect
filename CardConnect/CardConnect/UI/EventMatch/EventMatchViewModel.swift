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
    @Published var canLoadMore = false
    @Published var isLoadingMore = false

    // TODO: Epic 4 #113 — takvim izni + loadEvents
    func loadEvents(calendarService: CalendarService) async {
        state = .empty
    }

    // TODO: Epic 4 #112 — geçmiş etkinlikleri 20'şer yükle
    func loadMore(calendarService: CalendarService) async {
    }

    // TODO: Epic 4 #114 — Contact.eventId/eventName güncelle + notes append
    func selectEvent(_ event: CalendarEvent, for contactID: UUID) async -> Bool {
        return false
    }
}
