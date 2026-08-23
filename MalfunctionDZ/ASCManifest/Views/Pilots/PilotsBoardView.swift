import SwiftUI

struct PilotsBoardView: View {
    @EnvironmentObject private var store: ManifestStore
    @State private var assignPilot: ManifestPilotCard?
    @State private var showInactive = false

    private var activePilots: [ManifestPilotCard] {
        store.pilots.filter { $0.is_active == true }
    }

    private var inactivePilots: [ManifestPilotCard] {
        store.pilots.filter { $0.is_active != true }
    }

  private let columns = [
        GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            if let error = store.pilotsErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(NightOps.danger)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NightOps.surface.ignoresSafeArea())
        .navigationTitle("Pilots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Task { await store.loadPilots() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isLoadingPilots)
            }
        }
        .sheet(item: $assignPilot) { pilot in
            AssignPilotToLoadSheet(pilot: pilot)
        }
        .onAppear {
            store.pilotsBoardActive = true
            Task { await store.loadPilots() }
        }
        .onDisappear {
            store.pilotsBoardActive = false
        }
        .refreshable {
            await store.loadPilots()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(NightOps.gradientBar)
                .frame(height: 6)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pilots")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Document status, check-in, and today's load assignments.")
                        .font(.footnote)
                        .foregroundStyle(NightOps.textMuted)
                }
                Spacer()
                if let counts = store.pilotCounts {
                    HStack(spacing: 10) {
                        summaryChip(label: "Total", value: counts.total ?? 0)
                        summaryChip(label: "Ready", value: counts.ok ?? 0, tint: NightOps.success)
                        summaryChip(label: "Attention", value: (counts.warn ?? 0) + (counts.bad ?? 0), tint: NightOps.accent)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(NightOps.navy)
    }

    private func summaryChip(label: String, value: Int, tint: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(NightOps.textMuted)
        }
    }

  @ViewBuilder
    private var content: some View {
        if store.isLoadingPilots && store.pilots.isEmpty {
            ProgressView("Loading pilots…")
                .tint(NightOps.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.pilots.isEmpty {
            VStack(spacing: 8) {
                Text("No pilots on file.")
                    .foregroundStyle(.white)
                Text("Add pilots on the web Aircraft → Pilots page.")
                    .font(.footnote)
                    .foregroundStyle(NightOps.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !activePilots.isEmpty {
                        Text("Active pilots (\(activePilots.count))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NightOps.textMuted)
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(activePilots) { pilot in
                                PilotCardView(
                                    pilot: pilot,
                                    onAssign: { assignPilot = pilot },
                                    onRemoveAssignment: { assignment in
                                        Task {
                                            await store.removePilotFromLoad(
                                                loadID: assignment.load_id,
                                                role: assignment.role
                                            )
                                        }
                                    }
                                )
                            }
                        }
                    }
                    if !inactivePilots.isEmpty {
                        Button {
                            showInactive.toggle()
                        } label: {
                            Text("Inactive pilots (\(inactivePilots.count))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NightOps.textMuted)
                        }
                        .buttonStyle(.plain)
                        if showInactive {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(inactivePilots) { pilot in
                                    PilotCardView(
                                        pilot: pilot,
                                        onAssign: { assignPilot = pilot },
                                        onRemoveAssignment: { assignment in
                                            Task {
                                                await store.removePilotFromLoad(
                                                    loadID: assignment.load_id,
                                                    role: assignment.role
                                                )
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}
