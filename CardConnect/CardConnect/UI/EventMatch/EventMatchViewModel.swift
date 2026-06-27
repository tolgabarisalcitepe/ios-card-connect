// EventMatchViewModel.swift
// CardConnect

import Combine
import Foundation
import SwiftData

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

    // MARK: - selectEvent

    func selectEvent(
        _ event: CalendarEvent,
        for contactID: UUID,
        modelContext: ModelContext,
        permissionCoordinator: PermissionCoordinator
    ) async -> Bool {
        let descriptor = FetchDescriptor<Contact>(predicate: #Predicate { $0.id == contactID })
        guard let contact = (try? modelContext.fetch(descriptor))?.first else { return false }

        contact.eventId = event.id
        contact.eventName = event.title
        contact.updatedAt = Date()

        // Bug #134: notes üzerine yazma yok — append only
        let eventLine = "[\(event.title)]"
        if !contact.notes.contains(eventLine) {
            let separator = contact.notes.isEmpty ? "" : "\n"
            contact.notes += separator + eventLine
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Kayıt güncellenemedi."
            return false
        }

        // Opsiyonel: henüz rehbere eklenmemişse ve izin varsa ekle
        if contact.deviceContactId == nil,
           await permissionCoordinator.contactsStatus() == .authorized {
            let service = DeviceContactsService()
            if let deviceId = try? await service.add(contact) {
                contact.deviceContactId = deviceId
                try? modelContext.save()
            }
        }

        return true
    }
}
