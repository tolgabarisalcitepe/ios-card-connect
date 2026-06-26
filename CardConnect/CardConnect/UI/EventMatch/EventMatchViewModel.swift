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
    @Published var errorMessage: String?

    private var pageLimit = 20

    // MARK: - loadEvents

    func loadEvents(calendarService: CalendarService, onPermissionDenied: @escaping () -> Void) async {
        if await !calendarService.isAuthorized {
            let granted = await calendarService.requestAccess()
            if !granted {
                state = .empty
                errorMessage = "Takvim erişimi reddedildi."
                onPermissionDenied()
                return
            }
        }

        let today = await calendarService.getEventsForDay(Date())
        if !today.isEmpty {
            state = .active(today)
            return
        }

        let past = await calendarService.getEventsBefore(limit: pageLimit)
        if past.isEmpty {
            state = .empty
        } else {
            canLoadMore = past.count == pageLimit
            state = .list(past)
        }
    }

    // MARK: - loadMore

    func loadMore(calendarService: CalendarService) async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        pageLimit += 20
        let events = await calendarService.getEventsBefore(limit: pageLimit)
        canLoadMore = events.count == pageLimit
        state = .list(events)
    }

    // TODO: Epic 4 #114 — Contact.eventId/eventName güncelle + notes append
    func selectEvent(_ event: CalendarEvent, for contactID: UUID) async -> Bool {
        return false
    }
}
