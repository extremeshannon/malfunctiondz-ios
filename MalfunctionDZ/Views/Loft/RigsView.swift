// File: ASC/Views/Loft/RigsView.swift
// Consolidated Rigs for Ops Admin + Manifest: My Rigs + DZ Rigs (read-only). Single "Rigs" tab.
import SwiftUI

struct RigsView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.mdzColors) private var colors
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
        .alert("Error", isPresented: Binding(
            get: { dzRigsVm.error != nil },
            set: { if !$0 { dzRigsVm.error = nil } }
        )) {
            Button("OK", role: .cancel) { dzRigsVm.error = nil }
        } message: { Text(dzRigsVm.error ?? "") }
    }

    private var rigsContent: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                headerSection
                if myRigsVm.isLoading && dzRigsVm.isLoading && myRigsVm.rigs.isEmpty && dzRigsVm.rigs.isEmpty {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.green)).scaleEffect(1.4)
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
                    .foregroundColor(colors.green)
                Text("RIGS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(colors.green)
                    .tracking(2)
                Spacer()
                let total = myRigsVm.rigs.count + dzRigsVm.rigs.count
                Text("\(total) RIG\(total == 1 ? "" : "S")")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(1)
            }
            Text(rigsDateString)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colors.muted)
            Text("Read-only — personal rigs and DZ rigs")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(colors.amber)
            if auth.currentUser?.canAccess25JumpCheck == true {
                NavigationLink {
                    JumpCheckView(vm: dzRigsVm)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.fall")
                            .font(.system(size: 12, weight: .semibold))
                        Text("25 Jump Check")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(colors.amber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(colors.amber.opacity(0.15))
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(colors.navyMid)
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
                    .foregroundColor(colors.green)
                Text("MY RIGS — \(myRigsVm.rigs.count)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.green)
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
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private var dzRigsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(colors.amber)
                Text("DZ RIGS — \(dzRigsVm.rigs.count) (read-only)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(1)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            VStack(spacing: 0) {
                ForEach(dzRigsVm.rigs) { rig in
                    NavigationLink {
                        DzRigDetailView(rigId: rig.id, vm: dzRigsVm)
                    } label: {
                        DzRigRow(rig: rig)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    if rig.id != dzRigsVm.rigs.last?.id {
                        Divider().background(colors.border).padding(.horizontal, 14)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.amber.opacity(0.3), lineWidth: 1))
    }
}
