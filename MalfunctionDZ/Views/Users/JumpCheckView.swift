// File: ASC/Views/Users/JumpCheckView.swift
// 25 Jump Check — Ops view users with jump counts (who has passed 25 for DZ rigs)
import SwiftUI

struct JumpCheckView: View {
    @StateObject private var vm = JumpCheckViewModel()

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "figure.fall")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.mdzAmber)
                        Text("25 JUMP CHECK")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.mdzAmber)
                            .tracking(2)
                    }
                    Text("Users with jump counts — 25+ for DZ rigs access")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.mdzMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.mdzNavyMid)

                TextField("Search username, name", text: $vm.searchQuery)
                    .mdzInputStyle()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.mdzNavyMid)
                    .onSubmit { Task { await vm.load() } }

                if vm.isLoading && vm.users.isEmpty {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber)).scaleEffect(1.4)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.users) { u in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(u.passed25 ? Color.mdzGreen.opacity(0.2) : Color.mdzMuted.opacity(0.2))
                                            .frame(width: 44, height: 44)
                                        Text(String(u.displayName.prefix(2)).uppercased())
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(u.passed25 ? .mdzGreen : .mdzMuted)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(u.displayName)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.mdzText)
                                        Text(u.username)
                                            .font(.system(size: 12))
                                            .foregroundColor(.mdzMuted)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(u.totalJumps)")
                                            .font(.system(size: 18, weight: .black))
                                            .foregroundColor(u.passed25 ? .mdzGreen : .mdzMuted)
                                        Text("jumps")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.mdzMuted)
                                    }
                                    if u.passed25 {
                                        Text("✓")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.mdzGreen)
                                    }
                                }
                                .padding(14)
                                .background(Color.mdzCard)
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("25 Jump Check")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .alert("Error", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }
}
