// File: MalfunctionDZ/Views/Calendar/TodosView.swift
// Placeholder for Todos tab (no todos API yet).

import SwiftUI

struct TodosView: View {
    var body: some View {
        EmptyStateView(
            icon: "checklist",
            title: "Todos",
            subtitle: "To-dos are managed in Ops on the web. Calendar todos integration coming soon."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
