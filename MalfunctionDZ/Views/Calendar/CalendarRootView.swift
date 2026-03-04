// File: MalfunctionDZ/Views/Calendar/CalendarRootView.swift
// Root view for Calendar (Events + Shifts) with segmented control.

import SwiftUI

struct CalendarRootView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom segmented control for better visibility on dark background
                    CalendarSegmentPicker(selectedTab: $selectedTab)
                        .padding()
                        .background(Color.mdzBackground)

                    if selectedTab == 0 {
                        EventsView()
                            .transition(.opacity)
                    } else {
                        ShiftsView()
                            .transition(.opacity)
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Bright segmented control (both states clearly visible)
struct CalendarSegmentPicker: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            segmentButton(title: "Events", tag: 0)
            segmentButton(title: "Shifts", tag: 1)
        }
        .padding(4)
        .background(Color.mdzCard)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }

    private func segmentButton(title: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        return Button {
            selectedTab = tag
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? .mdzBackground : .mdzText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.mdzRed : Color.clear)
        )
    }
}
