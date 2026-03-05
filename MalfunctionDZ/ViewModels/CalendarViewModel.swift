// File: MalfunctionDZ/ViewModels/CalendarViewModel.swift
// View model for Events and Shifts screens.

import Foundation
import SwiftUI

@MainActor
final class CalendarViewModel: ObservableObject {
    // Events
    @Published var events: [CalendarEvent] = []
    @Published var eventsLoading = false
    @Published var eventsError: String?

    // Shifts
    @Published var shifts: [StaffShift] = []
    @Published var shiftsLoading = false
    @Published var shiftsError: String?
    @Published var selectedShiftDate = Date()
    @Published var feedbackMessage: String?
    @Published var feedbackIsError = false

    private let calendar = Calendar.current

    /// Date range for events (current month ± 1)
    var eventsDateRange: (Date, Date) {
        let start = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let end = calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        return (start, end)
    }

    var eventsDateRangeText: String {
        let (start, end) = eventsDateRange
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    // MARK: - Events
    func loadEvents() async {
        eventsLoading = true
        eventsError = nil
        defer { eventsLoading = false }

        let (start, end) = eventsDateRange
        do {
            events = try await CalendarAPIService.shared.fetchEvents(from: start, to: end)
        } catch {
            eventsError = error.localizedDescription
            events = []
        }
    }

    // MARK: - Shifts (loads week containing selected date)
    var shiftDateRange: (Date, Date) {
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedShiftDate)) else {
            let fallback = calendar.date(byAdding: .day, value: -7, to: selectedShiftDate) ?? selectedShiftDate
            return (fallback, calendar.date(byAdding: .day, value: 14, to: selectedShiftDate) ?? selectedShiftDate)
        }
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let start = calendar.date(byAdding: .day, value: -1, to: weekStart) ?? weekStart
        let end = calendar.date(byAdding: .day, value: 1, to: weekEnd) ?? weekEnd
        return (start, end)
    }

    func loadShifts() async {
        shiftsLoading = true
        shiftsError = nil
        defer { shiftsLoading = false }

        let (from, to) = shiftDateRange
        do {
            shifts = try await CalendarAPIService.shared.fetchShifts(from: from, to: to)
        } catch {
            shiftsError = error.localizedDescription
            shifts = []
        }
    }

    func shiftsForDate(_ date: Date) -> [StaffShift] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        let dateStr = df.string(from: date)
        return shifts.filter { $0.shiftDate == dateStr }
    }

    func shiftsGroupedByDate() -> [(String, [StaffShift])] {
        let grouped = Dictionary(grouping: shifts) { $0.shiftDate }
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    func claimShift(_ shift: StaffShift, userId: Int?) async {
        guard userId != nil else { return }
        feedbackMessage = nil
        do {
            let msg = try await CalendarAPIService.shared.claimShift(shiftId: shift.id)
            showFeedback(msg, isError: false)
            await loadShifts()
        } catch {
            showFeedback(error.localizedDescription, isError: true)
        }
    }

    func requestRelease(_ shift: StaffShift, userId: Int?) async {
        guard userId != nil else { return }
        feedbackMessage = nil
        do {
            let msg = try await CalendarAPIService.shared.requestRelease(shiftId: shift.id)
            showFeedback(msg, isError: false)
            await loadShifts()
        } catch {
            showFeedback(error.localizedDescription, isError: true)
        }
    }

    private func showFeedback(_ message: String, isError: Bool) {
        feedbackMessage = message
        feedbackIsError = isError
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if feedbackMessage == message { feedbackMessage = nil }
        }
    }
}
