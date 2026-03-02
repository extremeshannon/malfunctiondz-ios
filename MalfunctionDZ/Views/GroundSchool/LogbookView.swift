// File: ASC/Views/GroundSchool/LogbookView.swift
// Purpose: Skydiver logbook for a course — printable-style layout matching reference.
//          Shows jump entries (Jump, DZ, Altitude, Delay, Date, Aircraft, Equipment,
//          Total Time, Jump Type, Comments, Signature) and Other training / comments.
import SwiftUI

struct LogbookView: View {
    let courseId: Int
    let courseTitle: String

    @StateObject private var vm = LogbookViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()

            if vm.isLoading && vm.entries.isEmpty {
                VStack(spacing: 16) {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber)).scaleEffect(1.2)
                    Text("Loading logbook…").font(.subheadline).foregroundColor(.mdzMuted)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LOGBOOK")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.mdzAmber)
                                .tracking(2)
                            Text(courseTitle)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.mdzText)
                        }

                        if vm.entries.isEmpty {
                            EmptyStateView(
                                icon: "book.closed",
                                title: "No logbook entries yet",
                                subtitle: "Jump sign-offs from this course will appear here. Entries are added when an instructor signs off a jump."
                            )
                            .padding(.vertical, 24)
                        } else {
                            ForEach(vm.entries) { entry in
                                LogbookEntryCard(entry: entry)
                            }
                        }

                        // Other training / comments (from reference)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Other training / comments")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.mdzMuted)
                            Text(vm.otherTrainingNotes.isEmpty ? " " : vm.otherTrainingNotes)
                                .font(.system(size: 14))
                                .foregroundColor(.mdzText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.mdzCard)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.mdzBorder, lineWidth: 1))
                        }
                        .padding(.bottom, 32)
                    }
                    .padding(20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.mdzAmber)
                }
            }
        }
        .task { await vm.load(courseId: courseId) }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }
}

// MARK: - Single entry card (printable-style layout)

struct LogbookEntryCard: View {
    let entry: SkydiverLogbookEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Jump, DZ, Altitude, Delay
            LogbookGridRow(labels: ["Jump", "DZ", "Altitude", "Delay"],
                           values: [String(entry.jumpNumber), entry.dz ?? "", entry.altitude ?? "", entry.delay ?? ""])

            // Row 2: Date, Aircraft, Equipment, Total Time
            LogbookGridRow(labels: ["Date", "Aircraft", "Equipment", "Total Time"],
                           values: [entry.date ?? "", entry.aircraft ?? "", entry.equipment ?? "", entry.totalTime ?? ""])

            // Jump Type
            LogbookFieldRow(label: "Jump Type", value: entry.jumpType ?? "")

            // Comments (large box)
            VStack(alignment: .leading, spacing: 6) {
                Text("Comments")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.mdzMuted)
                Text(entry.comments?.isEmpty == false ? entry.comments! : " ")
                    .font(.system(size: 14))
                    .foregroundColor(.mdzText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 60)
                    .padding(10)
                    .background(Color.mdzCard2)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.mdzBorder, lineWidth: 1))
            }

            // Result (pass/repeat)
            if entry.result != nil {
                HStack(spacing: 6) {
                    Text("Result")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.mdzMuted)
                    Text(entry.resultDisplay)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(entry.result?.lowercased() == "pass" ? .mdzGreen : .mdzAmber)
                }
            }

            // Signature
            HStack(spacing: 8) {
                Text("Signature")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.mdzMuted)
                if entry.isSigned, let signedBy = entry.signedBy, !signedBy.isEmpty {
                    Text(signedBy)
                        .font(.system(size: 13))
                        .foregroundColor(.mdzText)
                    if let lic = entry.instructorLicenseNumber, !lic.isEmpty {
                        Text("(\(lic))")
                            .font(.system(size: 11))
                            .foregroundColor(.mdzMuted)
                    }
                    if let at = entry.signedAt {
                        Text("· \(at)")
                            .font(.system(size: 11))
                            .foregroundColor(.mdzMuted)
                    }
                } else {
                    Text(" ")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .background(Color.mdzCard2)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.mdzBorder, lineWidth: 1))
                }
            }
        }
        .padding(14)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

// MARK: - Grid row (4 columns like reference)

struct LogbookGridRow: View {
    let labels: [String]
    let values: [String]

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { i in
                    Text(labels[i].uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.mdzMuted)
                        .tracking(0.5)
                    if i < 3 { Spacer(minLength: 4) }
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.offset) { i in
                    Text(values[i].isEmpty ? " " : values[i])
                        .font(.system(size: 13))
                        .foregroundColor(.mdzText)
                    if i < 3 { Spacer(minLength: 4) }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.mdzCard2)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.mdzBorder, lineWidth: 1))
        }
    }
}

struct LogbookFieldRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(0.5)
            Text(value.isEmpty ? " " : value)
                .font(.system(size: 13))
                .foregroundColor(.mdzText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.mdzCard2)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.mdzBorder, lineWidth: 1))
        }
    }
}
