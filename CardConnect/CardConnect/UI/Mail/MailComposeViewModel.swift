// MailComposeViewModel.swift
// CardConnect

import Foundation

@MainActor final class MailComposeViewModel: ObservableObject {

    @Published var dayEvents: [CalendarEvent] = []
    @Published var isLoadingEvents = false

    // MARK: - Calendar

    func loadEventsForDay(_ date: Date, calendarService: CalendarService) async {
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        dayEvents = await calendarService.getEventsForDay(date)
    }

    /// meetingDate + 1 saat aralığıyla çakışan etkinlikler.
    func conflictingEvents(for meetingDate: Date) -> [CalendarEvent] {
        let meetingEnd = meetingDate.addingTimeInterval(3600)
        return dayEvents.filter { event in
            event.startDate < meetingEnd && event.endDate > meetingDate
        }
    }
}
