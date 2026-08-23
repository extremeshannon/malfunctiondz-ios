import SwiftUI

struct ReportsListView: View {
    @EnvironmentObject private var reportsStore: ReportsStore
    var onOpenMenu: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ManifestLeftPaneHeader(title: "Reports", onBack: onOpenMenu) {
                Task { await reportsStore.refresh() }
            }
            if let error = reportsStore.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(NightOps.danger)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
            }
            content
        }
        .background(NightOps.navy)
        .task {
            if reportsStore.reports.isEmpty {
                await reportsStore.refresh()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if reportsStore.isLoading && reportsStore.reports.isEmpty {
            Spacer()
            ProgressView("Loading reports…")
                .tint(NightOps.accent)
            Spacer()
        } else if reportsStore.reports.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .font(.largeTitle)
                    .foregroundStyle(NightOps.textMuted)
                Text("No reports available")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Enable Reports in Config or check your staff role.")
                    .font(.footnote)
                    .foregroundStyle(NightOps.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            Spacer()
        } else {
            List(reportsStore.reports) { report in
                Button {
                    reportsStore.select(report)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(report.description)
                            .font(.caption)
                            .foregroundStyle(NightOps.textMuted)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(
                    reportsStore.selectedReport?.key == report.key
                        ? NightOps.accent.opacity(0.22)
                        : NightOps.navyLight.opacity(0.35)
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}
