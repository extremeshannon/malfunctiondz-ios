// File: MalfunctionDZ/Views/Calendar/ShiftsView.swift
// Staff shifts with per-day view: week picker + day rows.

import SwiftUI
import MalfunctionDZCore

struct ShiftsView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.mdzColors) private var colors
    @StateObject private var vm = CalendarViewModel()
    @State private var showDatePicker = false

    private var weekDays: [Date] {
        let cal = Calendar.current
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: vm.selectedShiftDate)) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekRangeText: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return "\(f.string(from: first)) – \(f.string(from: last))"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let msg = vm.feedbackMessage {
                HStack(spacing: 8) {
                    Image(systemName: vm.feedbackIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(vm.feedbackIsError ? colors.danger : colors.green)
                    Text(msg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colors.text)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background((vm.feedbackIsError ? colors.danger : colors.green).opacity(0.15))
            }

            weekPickerHeader

            if vm.shiftsLoading && vm.shifts.isEmpty {
                LoadingOverlay(message: "Loading shifts…")
            } else if let err = vm.shiftsError {
                shiftsErrorView(err)
            } else {
                perDayList
            }
        }
        .refreshable { await vm.loadShifts() }
        .task { await vm.loadShifts() }
        .onChange(of: vm.selectedShiftDate) { _, _ in
            Task { await vm.loadShifts() }
        }
    }

    private var weekPickerHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    if let first = weekDays.first {
                        vm.selectedShiftDate = Calendar.current.date(byAdding: .day, value: -7, to: first) ?? vm.selectedShiftDate
                    }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(colors.primary)
                }
                .buttonStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(weekDays, id: \.timeIntervalSince1970) { day in
                            dayButton(day)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity)

                Button {
                    if let last = weekDays.last {
                        vm.selectedShiftDate = Calendar.current.date(byAdding: .day, value: 1, to: last) ?? vm.selectedShiftDate
                    }
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(colors.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 12)
            .background(colors.card)

            Button {
                showDatePicker = true
            } label: {
                HStack(spacing: 8) {
                    Text(weekRangeText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colors.muted)
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(colors.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(colors.card)
            .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(colors.border, lineWidth: 0.5))
        }
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: vm.selectedShiftDate)
        let dayNum = cal.component(.day, from: day)

        return Button {
            vm.selectedShiftDate = day
        } label: {
            Text("\(dayNum)")
                .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? colors.background : colors.text)
                .frame(width: 36, height: 36)
                .background(isSelected ? colors.accent : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                DatePicker(
                    "Select date",
                    selection: Binding(
                        get: { vm.selectedShiftDate },
                        set: { vm.selectedShiftDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(colors.accent)
                .padding()
            }
            .preferredColorScheme(.light)
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showDatePicker = false
                    }
                    .foregroundColor(colors.accent)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var perDayList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(weekDays, id: \.timeIntervalSince1970) { day in
                    ShiftDayRow(
                        date: day,
                        shifts: vm.shiftsForDate(day),
                        currentUserId: auth.currentUser?.id,
                        canPick: { shift in
                            auth.currentUser?.canPickShiftForPosition(shift.positionKey) ?? false
                        },
                        onClaim: { shift in
                            Task { await vm.claimShift(shift, userId: auth.currentUser?.id) }
                        },
                        onRequestRelease: { shift in
                            Task { await vm.requestRelease(shift, userId: auth.currentUser?.id) }
                        }
                    )
                }
            }
            .padding()
        }
    }

    private func shiftsErrorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(colors.amber)
            Text(message)
                .font(.subheadline)
                .foregroundColor(colors.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                Task { await vm.loadShifts() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(colors.accent)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShiftDayRow: View {
    let date: Date
    let shifts: [StaffShift]
    let currentUserId: Int?
    let canPick: (StaffShift) -> Bool
    let onClaim: (StaffShift) -> Void
    let onRequestRelease: (StaffShift) -> Void
    @Environment(\.mdzColors) private var colors

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "d EEE"
        return f.string(from: date).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(dayLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.text)
                    .frame(width: 70, alignment: .leading)

                if shifts.isEmpty {
                    Text("No shift scheduled.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(colors.muted)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(shifts) { shift in
                            ShiftRow(
                                shift: shift,
                                isCurrentUser: shift.userId == currentUserId,
                                showPick: shift.status == "available" && canPick(shift),
                                showRequestRelease: shift.status == "approved" && shift.userId == currentUserId,
                                onPick: { onClaim(shift) },
                                onRequestRelease: { onRequestRelease(shift) }
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card)
            .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(colors.border, lineWidth: 0.5))
        }
        .padding(.vertical, 4)
    }
}

struct ShiftRow: View {
    let shift: StaffShift
    let isCurrentUser: Bool
    let showPick: Bool
    let showRequestRelease: Bool
    let onPick: () -> Void
    let onRequestRelease: () -> Void
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(shift.positionLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.text)
                Text(shift.slotLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colors.muted)
            }
            .frame(width: 120, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(shift.displayAssignee)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(shift.status == "available" ? colors.green : colors.text)

                if showPick {
                    Button(action: onPick) {
                        Text("Pick")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(colors.green)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                } else if showRequestRelease {
                    Button(action: onRequestRelease) {
                        Text("Request Release")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(colors.background)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(colors.amber)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isCurrentUser {
                Text("You")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(colors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colors.primary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }
}
