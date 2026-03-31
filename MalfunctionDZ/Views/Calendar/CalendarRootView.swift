// File: MalfunctionDZ/Views/Calendar/CalendarRootView.swift
// Root view for Calendar (Todos | Events). Shifts has its own tab.

import SwiftUI
import MalfunctionDZCore

struct CalendarRootView: View {
    @State private var selectedTab = 0
    @Environment(\.appShell) private var appShell
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    private var isMemberShell: Bool { appShell == .member }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    if !isMemberShell {
                        CalendarSegmentPicker(selectedTab: $selectedTab)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                            .background(colors.background)
                    }

                    Group {
                        if isMemberShell {
                            EventsView()
                        } else if selectedTab == 0 {
                            TodosView()
                        } else {
                            EventsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }
            }
            .navigationTitle(isMemberShell ? "Events" : "Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Segmented control: Todos | Events
struct CalendarSegmentPicker: View {
    @Binding var selectedTab: Int
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            segmentButton(title: "Todos", tag: 0)
            segmentButton(title: "Events", tag: 1)
        }
        .padding(4)
        .background(colors.card)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
    }

    private func segmentButton(title: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        return Button {
            selectedTab = tag
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? colors.background : colors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? colors.accent : Color.clear)
        )
    }
}
