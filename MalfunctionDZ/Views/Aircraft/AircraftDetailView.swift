// File: ASC/Views/Aircraft/AircraftDetailView.swift
// Change from previous version: added PAX tab (index 3)
import SwiftUI

struct AircraftDetailView: View {
    let aircraft: Aircraft
    @StateObject private var vm = AircraftDetailViewModel()
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(aircraft.tailNumber)
                            .font(.title.bold().monospaced())
                            .foregroundColor(.mdzText)
                        Spacer()
                        StatusPill(label: aircraft.status.uppercased(), color: aircraft.statusColor)
                    }
                    Text(aircraft.model)
                        .font(.subheadline)
                        .foregroundColor(.mdzMuted)
                    if let annual = aircraft.annualDue {
                        InfoRow(label: "Annual Due", value: annual)
                    }
                    if let next100 = aircraft.next100hrDue {
                        InfoRow(label: "100hr Due", value: next100)
                    }
                    if let oil = aircraft.lastOilChange {
                        InfoRow(label: "Last Oil Change", value: oil)
                    }
                }
                .padding()
                .background(Color.mdzCard)

                // Tab picker — now 4 tabs
                Picker("", selection: $selectedTab) {
                    Text("Squawks").tag(0)
                    Text("Logbook").tag(1)
                    Text("ADs").tag(2)
                    Text("PAX").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.mdzNavyMid)

                // Tab content — frame so all tabs (Squawks, Logbook, ADs, PAX) use full width on iPad
                Group {
                    switch selectedTab {
                    case 0: squawksTab
                    case 1: logbookTab
                    case 2: adsTab
                    case 3: PaxView(aircraft: aircraft)
                    default: squawksTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.mdzBackground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(aircraft.tailNumber)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadDetail(aircraftId: aircraft.id) }
    }

    private var squawksTab: some View {
        Group {
            if vm.isLoading {
                LoadingOverlay(message: "Loading squawks…")
            } else if vm.squawks.isEmpty {
                EmptyStateView(icon: "checkmark.circle", title: "No Squawks", subtitle: "Aircraft is squawk-free.")
            } else {
                List(vm.squawks) { squawk in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(squawk.description)
                                .font(.subheadline)
                                .foregroundColor(.mdzText)
                            Spacer()
                            StatusPill(label: squawk.status.uppercased(), color: squawk.statusColor)
                        }
                        if let by = squawk.reportedBy, let at = squawk.reportedAt {
                            Text("Reported \(at) · \(by)")
                                .font(.caption)
                                .foregroundColor(.mdzMuted)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.mdzCard)
                    .listRowSeparatorTint(Color.mdzBorder)
                }
                .listStyle(.plain)
            }
        }
    }

    private var logbookTab: some View {
        Group {
            if vm.logbook.isEmpty {
                EmptyStateView(icon: "book", title: "No Entries", subtitle: "No logbook entries found.")
            } else {
                List(vm.logbook) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.date).font(.caption).foregroundColor(.mdzMuted)
                            Spacer()
                            if let t = entry.tachTime {
                                Text(String(format: "Tach %.1f", t)).font(.caption2).foregroundColor(.mdzBlue)
                            }
                        }
                        Text(entry.description).font(.subheadline).foregroundColor(.mdzText)
                        if let by = entry.performedBy {
                            Text(by).font(.caption).foregroundColor(.mdzMuted)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.mdzCard)
                    .listRowSeparatorTint(Color.mdzBorder)
                }
                .listStyle(.plain)
            }
        }
    }

    private var adsTab: some View {
        Group {
            if vm.ads.isEmpty {
                EmptyStateView(icon: "doc.text", title: "No ADs", subtitle: "No airworthiness directives found.")
            } else {
                List(vm.ads) { ad in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(ad.adNumber).font(.caption.monospaced()).foregroundColor(.mdzBlue)
                            Spacer()
                            StatusPill(
                                label: ad.status.uppercased(),
                                color: ad.status == "complied" ? .mdzGreen : .mdzAmber
                            )
                        }
                        Text(ad.description).font(.subheadline).foregroundColor(.mdzText)
                        if let due = ad.dueDate {
                            Text("Due: \(due)").font(.caption).foregroundColor(.mdzAmber)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.mdzCard)
                    .listRowSeparatorTint(Color.mdzBorder)
                }
                .listStyle(.plain)
            }
        }
    }
}
