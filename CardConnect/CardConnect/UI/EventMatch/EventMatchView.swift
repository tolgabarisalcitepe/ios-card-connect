// EventMatchView.swift
// CardConnect

import SwiftUI

struct EventMatchView: View {
    let contactID: UUID
    let onSkip: () -> Void
    let onMatched: () -> Void

    @StateObject private var viewModel = EventMatchViewModel()
    @Environment(\.dependencies) private var dependencies
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Takvim yükleniyor…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .active(let events):
                eventList(events: events, header: "Bugünkü Etkinlikler")

            case .list(let events):
                eventList(
                    events: Array(events.reversed()),
                    header: "Son Etkinlikler",
                    showLoadMore: viewModel.canLoadMore
                )

            case .empty:
                ContentUnavailableView(
                    "Etkinlik Bulunamadı",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Takvimde etkinlik yok veya erişim izni verilmedi.")
                )
            }
        }
        .navigationTitle("Etkinlik Eşleştir")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("event_match_view")
        .safeAreaInset(edge: .bottom) { skipButton }
        .task {
            await viewModel.loadEvents(
                calendarService: dependencies.calendarService,
                onPermissionDenied: onSkip
            )
        }
    }

    // MARK: - Event list

    private func eventList(events: [CalendarEvent], header: String, showLoadMore: Bool = false) -> some View {
        List {
            Section(header: Text(header)) {
                ForEach(events) { event in
                    EventCardView(event: event) {
                        Task {
                            let ok = await viewModel.selectEvent(
                                event,
                                for: contactID,
                                modelContext: modelContext,
                                permissionCoordinator: dependencies.permissionCoordinator
                            )
                            if ok { onMatched() }
                        }
                    }
                }
                if showLoadMore {
                    loadMoreRow
                }
            }
        }
    }

    // MARK: - Load more

    private var loadMoreRow: some View {
        Group {
            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                Button("Daha fazla") {
                    Task {
                        await viewModel.loadMore(calendarService: dependencies.calendarService)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("event_load_more_button")
            }
        }
    }

    // MARK: - Skip

    private var skipButton: some View {
        Button(action: onSkip) {
            Label("Atla", systemImage: "arrow.forward")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding()
        .background(.regularMaterial)
        .accessibilityIdentifier("event_match_skip_button")
    }
}

// MARK: - EventCardView

private struct EventCardView: View {
    let event: CalendarEvent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(event.startDate, style: .date)
                    Text(event.startDate, style: .time)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("event_card")
    }
}
