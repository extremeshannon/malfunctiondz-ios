import SwiftUI

struct AddLoadSheet: View {
    @EnvironmentObject private var store: ManifestStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAircraftID: Int?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Aircraft (optional)") {
                    Picker("Jump plane", selection: $selectedAircraftID) {
                        Text("Default").tag(Int?.none)
                        ForEach(store.aircraft) { ac in
                            Text(ac.label).tag(Optional(ac.id))
                        }
                    }
                }
            }
            .navigationTitle("New Load")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await create() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func create() async {
        isSaving = true
        defer { isSaving = false }
        if await store.createLoad(aircraftID: selectedAircraftID) {
            dismiss()
        }
    }
}
