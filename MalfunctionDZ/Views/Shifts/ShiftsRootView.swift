// File: MalfunctionDZ/Views/Shifts/ShiftsRootView.swift
// Dedicated Shifts page with per-day view. Pulled out from Calendar.

import SwiftUI
import MalfunctionDZCore

struct ShiftsRootView: View {
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                ShiftsView()
            }
            .navigationTitle("Shifts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
