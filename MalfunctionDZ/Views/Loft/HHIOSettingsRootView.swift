import SwiftUI

struct HHIOSettingsRootView: View {
    @EnvironmentObject private var settings: HHIOSettingsStore
    @Environment(\.mdzColors) private var colors

    @State private var loftName = ""
    @State private var invoiceFrom = ""
    @State private var tandemPrice = ""
    @State private var studentPrice = ""
    @State private var pilotRigPrice = ""

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            Form {
                Section {
                    Text("These settings are shared with the website loft config. Changes apply to invoices and the HHIO app for all staff.")
                        .font(.system(size: 13))
                        .foregroundColor(colors.muted)
                }

                if settings.canEdit {
                    Section("Loft & invoices") {
                        TextField("Loft name", text: $loftName)
                        TextField("Invoice from (e.g. HHIO Loft <loft@dz.com>)", text: $invoiceFrom)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        Text("Leave from address blank to use the global dropzone email setting.")
                            .font(.system(size: 12))
                            .foregroundColor(colors.muted)
                    }

                    Section("Pack job prices") {
                        HStack {
                            Text("Tandem")
                            Spacer()
                            TextField("125.00", text: $tandemPrice)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                        }
                        HStack {
                            Text("Sport / Student")
                            Spacer()
                            TextField("100.00", text: $studentPrice)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                        }
                        HStack {
                            Text("Pilot rig")
                            Spacer()
                            TextField("100.00", text: $pilotRigPrice)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                        }
                    }

                    Section {
                        Button {
                            Task { await save() }
                        } label: {
                            Text(settings.saving ? "Saving…" : "Save settings")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(settings.saving || loftName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Section("Loft & invoices") {
                        readOnlyRow("Loft name", loftName)
                        readOnlyRow("Invoice from", invoiceFrom.isEmpty ? "(global email)" : invoiceFrom)
                    }
                    Section("Pack job prices") {
                        readOnlyRow("Tandem", tandemPrice)
                        readOnlyRow("Sport / Student", studentPrice)
                        readOnlyRow("Pilot rig", pilotRigPrice)
                    }
                    Section {
                        Text("Only admin or master rigger can edit these settings on the HHIO app. You can also change them on the website under Config → Loft.")
                            .font(.system(size: 12))
                            .foregroundColor(colors.muted)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("HHIO Config")
        .navigationBarTitleDisplayMode(.inline)
        .task { await settings.load() }
        .refreshable { await settings.load() }
        .onChange(of: settings.loftName) { _, _ in syncFields() }
        .onAppear { syncFields() }
        .overlay {
            if settings.loading && loftName.isEmpty {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.loft))
            }
        }
        .alert("Notice", isPresented: Binding(get: { settings.lastMessage != nil }, set: { if !$0 { settings.lastMessage = nil } })) {
            Button("OK", role: .cancel) { settings.lastMessage = nil }
        } message: { Text(settings.lastMessage ?? "") }
    }

    private func readOnlyRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.isEmpty ? "—" : "$\(value)")
                .foregroundColor(colors.text)
        }
    }

    private func syncFields() {
        loftName = settings.loftName
        invoiceFrom = settings.invoiceFrom
        tandemPrice = String(format: "%.2f", Double(settings.prices.tandemCents) / 100.0)
        studentPrice = String(format: "%.2f", Double(settings.prices.studentCents) / 100.0)
        pilotRigPrice = String(format: "%.2f", Double(settings.prices.pilotRigCents) / 100.0)
    }

    private func save() async {
        _ = await settings.save(
            loftName: loftName,
            invoiceFrom: invoiceFrom,
            tandemText: tandemPrice,
            studentText: studentPrice,
            pilotRigText: pilotRigPrice
        )
    }
}
