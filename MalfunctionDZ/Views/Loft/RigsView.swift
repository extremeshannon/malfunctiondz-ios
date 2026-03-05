// File: ASC/Views/Loft/RigsView.swift
// Consolidated Rigs for Ops Admin + Manifest: My Rigs + DZ Rigs (read-only). Single "Rigs" tab.
import SwiftUI

struct RigsView: View {
    @StateObject private var myRigsVm = MyRigsViewModel()
    @StateObject private var dzRigsVm = DzRigsViewModel()

    var body: some View {
        NavigationStack {
            rigsContent
        }
        .task {
            await myRigsVm.load()
            await dzRigsVm.load()
        }
        .refreshable {
            await myRigsVm.load()
            await dzRigsVm.load()
        }
        .navigationDestination(for: Int.self) { rigId in
            DzRigDetailView(rigId: rigId, vm: dzRigsVm)
        }
        .alert("Error", isPresented: Binding(
            get: { dzRigsVm.error != nil },
            set: { if !$0 { dzRigsVm.error = nil } }
        )) {
            Button("OK", role: .cancel) { dzRigsVm.error = nil }
        } message: { Text(dzRigsVm.error ?? "") }
    }

    private var rigsContent: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                headerSection
                if myRigsVm.isLoading && dzRigsVm.isLoading && myRigsVm.rigs.isEmpty && dzRigsVm.rigs.isEmpty {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzGreen)).scaleEffect(1.4)
                    Spacer()
                } else if myRigsVm.rigs.isEmpty && dzRigsVm.rigs.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "briefcase.fill", title: "No Rigs", subtitle: "No personal or DZ rigs to display.")
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            if !myRigsVm.rigs.isEmpty {
                                myRigsSection
                            }
                            if !dzRigsVm.rigs.isEmpty {
                                dzRigsSection
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.mdzGreen)
                Text("RIGS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.mdzGreen)
                    .tracking(2)
                Spacer()
                let total = myRigsVm.rigs.count + dzRigsVm.rigs.count
                Text("\(total) RIG\(total == 1 ? "" : "S")")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.mdzMuted)
                    .tracking(1)
            }
            Text(rigsDateString)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.mdzMuted)
            Text("Read-only — personal rigs and DZ rigs")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.mdzAmber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.mdzNavyMid)
    }

    private var rigsDateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private var myRigsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.mdzGreen)
                Text("MY RIGS — \(myRigsVm.rigs.count)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.mdzGreen)
                    .tracking(1)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            VStack(spacing: 8) {
                ForEach(myRigsVm.rigs) { rig in
                    MyRigRow(rig: rig)
                }
            }
            .padding(.bottom, 12)
        }
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }

    private var dzRigsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.mdzAmber)
                Text("DZ RIGS — \(dzRigsVm.rigs.count) (read-only)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.mdzAmber)
                    .tracking(1)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            VStack(spacing: 0) {
                ForEach(dzRigsVm.rigs) { rig in
                    NavigationLink(value: rig.id) {
                        DzRigRow(rig: rig)
                    }
                    .buttonStyle(.plain)
                    if rig.id != dzRigsVm.rigs.last?.id {
                        Divider().background(Color.mdzBorder).padding(.horizontal, 14)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzAmber.opacity(0.3), lineWidth: 1))
    }
}
