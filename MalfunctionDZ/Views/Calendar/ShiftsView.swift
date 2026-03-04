// File: MalfunctionDZ/Views/Calendar/ShiftsView.swift
// Staff shifts with date picker and Pick / Request Release actions.

import SwiftUI

struct ShiftsView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var vm = CalendarViewModel()
    @State private var showDatePicker = false

    var body: some View {
        VStack(spacing: 0) {
            if let msg = vm.feedbackMessage {
                HStack(spacing: 8) {
                    Image(systemName: vm.feedbackIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(vm.feedbackIsError ? .mdzDanger : .mdzGreen)
                    Text(msg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.mdzText)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background((vm.feedbackIsError ? Color.mdzDanger : Color.mdzGreen).opacity(0.15))
            }

            dateHeader

            if vm.shiftsLoading && vm.shifts.isEmpty {
                LoadingOverlay(message: "Loading shifts…")
            } else if let err = vm.shiftsError {
                shiftsErrorView(err)
            } else if vm.shifts.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No Shifts",
                    subtitle: "No shifts in this date range."
                )
            } else {
                shiftsList
            }
        }
        .refreshable { await vm.loadShifts() }
        .task { await vm.loadShifts() }
        .onChange(of: vm.selectedShiftDate) { _, _ in
            Task { await vm.loadShifts() }
        }
    }

    private var dateHeader: some View {
        Button {
            showDatePicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 17))
                    .foregroundColor(.mdzBlue)
                Text(dateDisplay)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.mdzText)
                Spacer()
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.mdzBlue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.mdzCard)
            .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(Color.mdzBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
    }

    private var dateDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: vm.selectedShiftDate)
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
                .tint(.mdzRed)
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
                    .foregroundColor(.mdzRed)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var shiftsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(vm.shiftsGroupedByDate(), id: \.0) { dateStr, dayShifts in
                    ShiftDaySection(
                        dateStr: dateStr,
                        shifts: dayShifts,
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
                .foregroundColor(.mdzAmber)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.mdzText)
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
                .background(Color.mdzRed)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShiftDaySection: View {
    let dateStr: String
    let shifts: [StaffShift]
    let currentUserId: Int?
    let canPick: (StaffShift) -> Bool
    let onClaim: (StaffShift) -> Void
    let onRequestRelease: (StaffShift) -> Void

    private var formattedDate: String {
        guard let d = parseDate(dateStr) else { return dateStr }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: d)
    }

    private func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: s)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(formattedDate)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(1.5)

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

struct ShiftRow: View {
    let shift: StaffShift
    let isCurrentUser: Bool
    let showPick: Bool
    let showRequestRelease: Bool
    let onPick: () -> Void
    let onRequestRelease: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(shift.positionLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.mdzText)
                Text(shift.slotLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.mdzMuted)
            }
            .frame(width: 120, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(shift.displayAssignee)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(shift.status == "available" ? .mdzGreen : .mdzText)

                if showPick {
                    Button(action: onPick) {
                        Text("Pick")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.mdzGreen)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                } else if showRequestRelease {
                    Button(action: onRequestRelease) {
                        Text("Request Release")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.mdzBackground)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.mdzAmber)
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
                    .foregroundColor(.mdzBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.mdzBlue.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}
