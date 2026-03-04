// File: MalfunctionDZ/Views/Calendar/EventsView.swift
// Public calendar events list.

import SwiftUI

struct EventsView: View {
    @StateObject private var vm = CalendarViewModel()
    @State private var selectedEvent: CalendarEvent?

    var body: some View {
        Group {
            if vm.eventsLoading && vm.events.isEmpty {
                LoadingOverlay(message: "Loading events…")
            } else if let err = vm.eventsError {
                errorView(err)
            } else if vm.events.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.exclamationmark",
                    title: "No Events",
                    subtitle: "No public events in this date range."
                )
            } else {
                eventList
            }
        }
        .refreshable { await vm.loadEvents() }
        .task { await vm.loadEvents() }
        .sheet(item: $selectedEvent) { event in
            EventDetailSheet(event: event)
        }
    }

    private var eventList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(vm.events.sorted { $0.eventDate < $1.eventDate }) { event in
                    Button {
                        selectedEvent = event
                    } label: {
                        EventRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.mdzAmber)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.mdzText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                Task { await vm.loadEvents() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.mdzRed)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.formattedDate)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.mdzBlue)
                    .tracking(1)
                if !event.timeRange.isEmpty {
                    Text(event.timeRange)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.mdzMuted)
                }
            }
            .frame(width: 90, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.mdzText)
                if let loc = event.location, !loc.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 10))
                        Text(loc)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.mdzMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.mdzMuted)
        }
        .padding(16)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

struct EventDetailSheet: View {
    let event: CalendarEvent

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.formattedDate)
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.mdzBlue)
                                .tracking(1)
                            if !event.timeRange.isEmpty {
                                Text(event.timeRange)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.mdzMuted)
                            }
                        }

                        if let loc = event.location, !loc.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.mdzRed)
                                Text(loc)
                                    .font(.system(size: 14))
                                    .foregroundColor(.mdzText)
                            }
                        }

                        if let desc = event.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 14))
                                .foregroundColor(.mdzText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
