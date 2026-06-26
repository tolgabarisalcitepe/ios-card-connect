// CalendarService.swift
// CardConnect

import EventKit
import Foundation

actor CalendarService {

    private let store = EKEventStore()

    // MARK: - Authorization

    var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    @discardableResult
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await store.requestFullAccessToEvents()) ?? false
        }
        return await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Queries

    /// O güne ait etkinlikleri DTSTART ASC sıralı döner. İzin yoksa [].
    func getEventsForDay(_ date: Date) async -> [CalendarEvent] {
        guard isAuthorized else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return fetchEvents(from: start, to: end)
    }

    /// En fazla `limit` adet geçmiş etkinliği DTSTART ASC sıralı döner. İzin yoksa [].
    func getEventsBefore(limit: Int) async -> [CalendarEvent] {
        guard isAuthorized else { return [] }
        let now = Date()
        let past = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        let events = fetchEvents(from: past, to: now)
        return Array(events.suffix(limit))
    }

    // MARK: - Private

    private func fetchEvents(from start: Date, to end: Date) -> [CalendarEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                CalendarEvent(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title ?? "",
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    location: $0.location
                )
            }
    }
}
