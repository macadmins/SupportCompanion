//
//  DeviceInformationCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-19.
//

import Foundation
import SwiftUI

struct DeviceInformationCard: View {
    @ObservedObject var viewModel: CardGridViewModel
    @EnvironmentObject var appState: AppStateManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if viewModel.isCardVisible(Constants.Cards.deviceInfo) {
            let groupedData = groupedDeviceInfoArray() // Precomputed grouped data

            ScCard(
                title: "\(Constants.CardTitle.deviceInfo)",
                titleImageName: "laptopcomputer",
                buttonImageName: "doc.on.doc.fill",
                buttonAction: { viewModel.copyDeviceInfoToClipboard() },
                buttonHelpText: Constants.ToolTips.deviceInfoCopy,
                content: {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(groupedData.enumerated()), id: \.1.0) { index, group in
                            DeviceInfoSection(
                                index: index,
                                group: group,
                                totalGroups: groupedData.count,
                                colorScheme: colorScheme // Pass colorScheme explicitly
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            )
        } else {
            EmptyView()
        }
    }

    private func groupedDeviceInfoArray() -> [(String, [(key: String, display: String, value: InfoValue)])] {
        groupedDeviceInfo()
            .sorted(by: { $0.key < $1.key }) // Sort categories alphabetically
            .map { ($0.key, $0.value) }
    }

    private func groupedDeviceInfo() -> [String: [(key: String, display: String, value: InfoValue)]] {
        guard let deviceInfo = appState.deviceInfoManager.deviceInfo else {
            return [:] // Return empty dictionary if `deviceInfo` is nil
        }

        return Dictionary(
            grouping: deviceInfo.toKeyValuePairs().sorted(by: { $0.key < $1.key }),
            by: { $0.category }
        )
        .mapValues { tuples in
            tuples.map { (key: $0.key, display: $0.display, value: $0.value) }
        }
    }
}

struct DeviceInfoSection: View {
    let index: Int
    let group: (String, [(key: String, display: String, value: InfoValue)])
    let totalGroups: Int
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionHeader(title: group.0) // Category (e.g., Hardware Specifications)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(group.1, id: \.key) { item in
                    if item.key == Constants.DeviceInfo.Keys.lastRestart {
                        LastRestartRow(
                            label: item.display,
                            value: item.value.rawValue as? Int ?? 0,
                            colorScheme: colorScheme // Pass colorScheme explicitly
                        )
                    } else {
                        DeviceInfoRow(label: item.display, value: item.value.displayValue)
                    }
                }
            }

            // Add a divider only if it's not the last group
            if index < totalGroups - 1 {
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.vertical)
            }
        }
        .frame(maxWidth: .infinity) // Ensure parent always fills width
    }
}

struct SectionHeader: View {
    let title: String

    private var image: String {
        switch title {
        case Constants.DeviceInfo.Categories.hardwareSpecs:
            return "cpu.fill"
        case Constants.DeviceInfo.Categories.systemInfo:
            return "info.circle.fill"
        case Constants.DeviceInfo.Categories.networkInfo:
            return "wifi"
        default:
            return "questionmark.circle.fill" // Fallback icon
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: image)
            Text(title)
                .font(.headline)
        }
        .padding(.vertical, 5)
    }
}

struct DeviceInfoRow: View {
    let label: String
    let value: String?

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 14))
                .bold()

            Spacer()

            Text(value ?? "N/A")
                .font(.system(size: 14))
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
    }
}

struct LastRestartRow: View {
    let label: String
    let value: Int // Days since last restart
    let colorScheme: ColorScheme

    var body: some View {
        let color = colorForLastRestart(value: value)

        HStack {
            Text(label)
                .font(.system(size: 14))
                .bold()
                .frame(alignment: .leading)

            Spacer()
            HStack(spacing: 5) {
                Text("\(value) \(Constants.General.days)")
                    .foregroundColor(color)
                Image(systemName: "clock.fill")
                    .foregroundColor(color)
            }
            .font(.system(size: 14))
            .help(Constants.ToolTips.deviceLastRebooted)
        }
    }

    private func colorForLastRestart(value: Int) -> Color {
        switch value {
        case 0...2:
            return .ScGreen
        case 3...7:
            return colorScheme == .light ? .orangeLight : .orange
        default:
            return colorScheme == .light ? .redLight : .red
        }
    }
}
