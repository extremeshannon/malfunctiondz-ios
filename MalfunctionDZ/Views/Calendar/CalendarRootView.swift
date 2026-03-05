// File: MalfunctionDZ/Views/Calendar/CalendarRootView.swift
// Root view for Calendar (Shifts | Todos | Events) with segmented control.

import SwiftUI

struct CalendarRootView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    CalendarSegmentPicker(selectedTab: $selectedTab)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .background(Color.mdzBackground)

                    Group {
                        if selectedTab == 0 {
                            ShiftsView()
                        } else if selectedTab == 1 {
                            TodosView()
                        } else {
                            EventsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
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

// MARK: - Segmented control: Shifts | Todos | Events
struct CalendarSegmentPicker: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            segmentButton(title: "Shifts", tag: 0)
            segmentButton(title: "Todos", tag: 1)
            segmentButton(title: "Events", tag: 2)
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
