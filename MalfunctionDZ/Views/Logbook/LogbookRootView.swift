// File: ASC/Views/Logbook/LogbookRootView.swift
// Purpose: Root for standalone Logbook tab/sidebar — wraps in NavigationStack for proper chrome.
import SwiftUI
import MalfunctionDZCore

struct LogbookRootView: View {
    var body: some View {
        NavigationStack {
            LogbookView.standalone()
        }
    }
}
