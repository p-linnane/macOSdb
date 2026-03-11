import macOSdbKit
import SwiftUI

struct ReleaseDetailView: View {
    @Environment(AppState.self)
    private var appState

    @State private var sortOrder = [KeyPathComparator(\Component.name)]

    var body: some View {
        if let release = appState.selectedRelease {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    releaseHeader(release)
                    componentTable(release)
                    if !release.kernels.isEmpty {
                        kernelSection(release)
                    }
                    chipSection(release)
                }
                .padding()
            }
            .navigationTitle("macOS \(release.osVersion)")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func releaseHeader(_ release: Release) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(release.displayName)
                .font(.largeTitle)
                .fontWeight(.bold)

            HStack(spacing: 16) {
                Label(release.buildNumber, systemImage: "number")
                if let date = release.releaseDate {
                    Label(date, systemImage: "calendar")
                }
                Label(
                    "\(release.components.count) components",
                    systemImage: "shippingbox"
                )
                Label(
                    "\(release.supportedChips.count) chip families",
                    systemImage: "cpu"
                )
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func componentTable(_ release: Release) -> some View {
        let filtered = filteredComponents(release).sorted(using: sortOrder)

        VStack(alignment: .leading, spacing: 8) {
            Text("Components")
                .font(.title2)
                .fontWeight(.semibold)

            if filtered.isEmpty {
                ContentUnavailableView.search(text: appState.searchText)
            } else {
                Table(filtered, sortOrder: $sortOrder) {
                    TableColumn("Name", value: \.name) { comp in
                        Text(comp.name)
                            .fontWeight(.medium)
                    }
                    .width(min: 120, ideal: 160)

                    TableColumn("Version") { comp in
                        Text(comp.displayVersion)
                    }
                    .width(min: 80, ideal: 120)

                    TableColumn("Path", value: \.path) { comp in
                        Text(comp.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 150, ideal: 250)
                }
                .frame(minHeight: 300)
            }
        }
    }

    // MARK: - Kernel

    @ViewBuilder
    private func kernelSection(_ release: Release) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kernel")
                .font(.title2)
                .fontWeight(.semibold)

            ForEach(release.kernels) { kernel in
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if let deviceChips = kernel.deviceChips,
                               !deviceChips.isEmpty {
                                let uniqueChips = deviceChips
                                    .reduce(into: [String]()) { result, dc in
                                        if !result.contains(dc.chip) { result.append(dc.chip) }
                                    }
                                    .sorted { lhs, rhs in
                                        let lhsChip = ChipFamily.from(chipName: lhs)
                                        let rhsChip = ChipFamily.from(chipName: rhs)
                                        let lhsGen = lhsChip?.generation ?? 0
                                        let rhsGen = rhsChip?.generation ?? 0
                                        // Sort generation 0 (A12Z, Virtual Mac) after real generations
                                        let lhsSortGen = lhsGen == 0 ? Int.max : lhsGen
                                        let rhsSortGen = rhsGen == 0 ? Int.max : rhsGen
                                        if lhsSortGen != rhsSortGen { return lhsSortGen < rhsSortGen }
                                        let lhsTier = lhsChip?.tier ?? .base
                                        let rhsTier = rhsChip?.tier ?? .base
                                        return lhsTier < rhsTier
                                    }
                                Text(uniqueChips.joined(separator: ", "))
                                    .font(.headline)
                            } else {
                                Text(kernel.chip)
                                    .font(.headline)
                            }
                            if kernel.isDevelopment {
                                Text("Development")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Text("Darwin \(kernel.darwinVersion)")
                            .font(.callout)
                        if let xnuVersion = kernel.xnuVersion {
                            Text("XNU \(xnuVersion)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(kernel.arch)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(kernel.devices.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Chips

    @ViewBuilder
    private func chipSection(_ release: Release) -> some View {
        if !release.supportedChips.isEmpty {
            ChipSupportView(kernels: release.kernels, chips: release.supportedChips)
        }
    }

    // MARK: - Helpers

    private func filteredComponents(_ release: Release) -> [Component] {
        let searchText = appState.searchText.trimmingCharacters(in: .whitespaces)
        guard !searchText.isEmpty else { return release.components }

        return release.components.filter { comp in
            comp.name.localizedCaseInsensitiveContains(searchText)
                || comp.displayVersion.localizedCaseInsensitiveContains(searchText)
                || comp.path.localizedCaseInsensitiveContains(searchText)
        }
    }
}
