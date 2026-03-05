// File: MalfunctionDZ/Views/Shifts/ShiftsRootView.swift
// Dedicated Shifts page with per-day view. Pulled out from Calendar.

import SwiftUI

struct ShiftsRootView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                ShiftsView()
            }
            .navigationTitle("Shifts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
