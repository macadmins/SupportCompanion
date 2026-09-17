//
//  FleetInstallDetailsSheet.swift
//  SupportCompanion
//
//  Output of a title's last failed install or uninstall, as reported by Fleet.
//

import SwiftUI

struct FleetInstallDetailsSheet: View {
    let title: FleetSoftwareTitle

    @Environment(AppStateManager.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var output: String?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.status == .failedUninstall ? Constants.Fleet.uninstallDetailsTitle : Constants.Fleet.installDetailsTitle)
                .font(.title2.weight(.semibold))
            Text(title.title)
                .foregroundStyle(.secondary)

            Group {
                if let error {
                    Label("\(Constants.Fleet.couldNotLoadDetails): \(error)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if let output {
                    ScrollView {
                        Text(output.isEmpty ? Constants.Fleet.noOutput : output)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(10)
                    }
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                Spacer()
                Button(Constants.Fleet.close) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560, height: 420)
        .task {
            do {
                output = try await appState.fleetSoftwareManager.failureOutput(for: title)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
