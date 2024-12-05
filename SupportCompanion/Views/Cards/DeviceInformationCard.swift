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

    var body: some View {
        if viewModel.isCardVisible("DeviceInformation") {
            CustomCard(
                title: "\(Constants.CardTitle.deviceInfo)",
                titleImageName: "laptopcomputer",
                buttonImageName: "doc.on.doc.fill",
                buttonAction: { viewModel.copyDeviceInfoToClipboard() },
                buttonHelpText: Constants.ToolTips.deviceInfoCopy,
                content: {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(groupedDeviceInfoArray().enumerated()), id: \.1.0) { index, group in
                            SectionHeader(title: group.0) // Category (e.g., Hardware Specifications)
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(group.1, id: \.key) { item in
                                    if item.key == Constants.DeviceInfo.Keys.lastRestart {
                                        LastRestartRow(
                                            label: item.display,
                                            value: item.value.rawValue as? Int ?? 0
                                        )
                                    } else {
                                        DeviceInfoRow(label: item.display, value: item.value.displayValue)
                                    }
                                }
                            }

                            // Add a divider only if it's not the last group
                            if index < groupedDeviceInfoArray().count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.2))
                            }
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

struct SectionHeader: View {
    let title: String

    // Computed property for the image name
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
        HStack {
            Text(label)
                .font(.system(size: 14))
                .bold()
                //.frame(width: 150, alignment: .leading) // Set fixed width for labels

            Spacer()
            Text(value ?? "N/A")
                .font(.system(size: 14))
                //.multilineTextAlignment(.trailing) // Ensure values align properly

        }
    }
}

struct LastRestartRow: View {
    let label: String
    let value: Int // Days since last restart

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .bold()
                .frame(width: 150, alignment: .leading) // Fixed width for labels

            Spacer()
            HStack(spacing: 5) {
                Text("\(value) \(Constants.General.days)")
                    .foregroundColor(colorForLastRestart(value: value))
                Image(systemName: "clock.fill")
                    .foregroundColor(colorForLastRestart(value: value))
            }
            .font(.system(size: 14))
            .help(Constants.ToolTips.deviceLastRebooted)
        }
    }

    /// Determine the color based on the number of days since the last restart
    private func colorForLastRestart(value: Int) -> Color {
        switch value {
        case 0...2:
            return .green
        case 3...7:
            return .orange
        default:
            return .red
        }
    }
}
