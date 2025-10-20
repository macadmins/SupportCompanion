//
//  ApplicationsInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-22.
//

import Foundation

class ApplicationsInfoManager: ObservableObject {
    private var monitorTask: Task<Void, Never>?
    private var updateTimer: Timer?
    private let munkiApps = MunkiApps()
    private let intuneApps = IntuneApps()
    private let profilerApps = SystemProfilerApplications()
    private var appState: AppStateManager

    @Published var applicationInfo: InstalledApp = InstalledApp(
        id: UUID(),
        name: "",
        version: "",
        action: "",
        arch: "",
        isSelfServe: false,
        path: "",
        type: "",
        bundleId: "",
		iconUrl: "",
		actionText: ""
    )

    init(appState: AppStateManager) {
        self.appState = appState
    }

    /// Starts the timer to fetch installed applications periodically
    func startMonitoring(interval: TimeInterval = 60.0) {
        // Stop any ongoing monitoring tasks or timers
        stopMonitoring()
        
        // Start a task to fetch immediately based on the mode
        monitorTask = Task {
            await fetchAppsBasedOnMode()
        }
        
        // Create a timer to periodically fetch applications
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard let self = self else { return }
                await self.fetchAppsBasedOnMode()
            }
        }
    }

    /// Stops the timer and cancels any ongoing tasks
    func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
        monitorTask?.cancel()
        monitorTask = nil
    }

    /// Fetches installed applications based on the current mode
    func fetchAppsBasedOnMode() async {
        switch appState.preferences.mode {
        case Constants.modes.munki:
            await getInstalledMunkiApps()
        case Constants.modes.intune:
            await getInstalledIntuneApps()
        case Constants.modes.systemProfiler:
            await getInstalledProfilerApps()
        case Constants.modes.jamf:
            await getInstalledJamfApps()
        default:
            await getInstalledMunkiApps()
        }
    }

    /// Fetches the list of installed applications
    func getInstalledMunkiApps() async {
        do {
            let apps = await munkiApps.getInstalledAppsList() // [[String: Any]]
            let selfServeApps = await munkiApps.getSelfServeAppsList()

            let installedApps = apps.compactMap { app -> InstalledApp? in
                var isSelfServe: Bool = false
                var command = ""

                guard
                    let installed = app["installed"] as? Bool, installed,
                    let name = app["name"] as? String,
                    let version = app["installed_version"] as? String
                else {
                    return nil
                }

                if selfServeApps.contains(where: { $0.localizedCaseInsensitiveContains(name) }) {
                    var commandName = name
                    isSelfServe = true
                    commandName = commandName.replacingOccurrences(of: " ", with: "%20")
                    command = "open munki://detail-\(commandName)"
                }

                return InstalledApp(
                    id: UUID(),
                    name: name,
                    version: version,
                    action: command,
                    arch: "",
                    isSelfServe: isSelfServe,
                    path: "",
                    type: "",
                    bundleId: "",
					iconUrl: "",
					actionText: ""
                )
            }
            
            let sortedApps = installedApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async {
                self.appState.installedApplications = sortedApps
            }
        }
    }
    
    func getInstalledIntuneApps() async {
        do {
            let apps = await intuneApps.getInstalledAppsListFromLog()
            let installedApps = apps.compactMap { app -> InstalledApp? in
                guard
                    let info = app["Info"] as? [String: Any],
                    let name = info["AppName"] as? String
                else {
                    return nil
                }

                let version = info["Version"] as? String ?? ""
                let type = info["AppType"] as? String ?? ""
                let bundleId = info["BundleID"] as? String ?? ""
                
                return InstalledApp(
                    id: UUID(),
                    name: name,
                    version: version,
                    action: "",
                    arch: "",
                    isSelfServe: false,
                    path: "",
                    type: type,
                    bundleId: bundleId,
					iconUrl: "",
					actionText: ""
                )
            }
            
            let sortedApps = installedApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.appState.installedApplications = sortedApps
            }
        }
    }
	
	func getInstalledJamfApps() async {
        do {
            let apps = await getInstalledJamfAppsFromStore()
            let installedApps = apps.compactMap { (key: AnyHashable, value: Any) -> InstalledApp? in
                guard let dict = value as? [String: Any] else { return nil }
                guard let name = dict["name"] as? String,
                      let version = dict["version"] as? String else {
                    return nil
                }
                let iconUrl = dict["iconUrl"] as? String ?? ""
                let id = dict["id"] as? Int ?? 0
                let command = "open \"selfservicecapability://content?entity=policy&id=\(id)&action=execute\""
                let actionText = (dict["postInstallText"] as? String) ?? ""

                return InstalledApp(
                    id: UUID(),
                    name: name,
                    version: version,
                    action: command,
                    arch: "",
                    isSelfServe: true,
                    path: "",
                    type: "",
                    bundleId: "",
					iconUrl: iconUrl,
					actionText: actionText
                )
            }
            
            let sortedApps = installedApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.appState.installedApplications = sortedApps
            }
        }
    }
    
    func getInstalledProfilerApps() async {
        do {
            let apps = await profilerApps.getInstalledApps()
            
            let installedApps = apps.compactMap { app -> InstalledApp? in
                let archMap: [String: String] = [
                    "arch_arm_i64": "Universal",
                    "arch_arm": "Apple Silicon",
                    "arch_i64": "Intel",
                    "arch_ios": "Apple Silicon",
                    "arch_other": "Other (Not Optimized)"
                ]

                let arch = archMap[app["arch_kind"] as? String ?? ""] ?? "Unknown"
                
                return InstalledApp(
                    id: UUID(),
                    name: app["_name"] as? String ?? "",
                    version: app["version"] as? String ?? "",
                    action: "",
                    arch: arch,
                    isSelfServe: false,
                    path: app["path"] as? String ?? "",
                    type: "",
                    bundleId: "",
					iconUrl: "",
					actionText: ""
                )
            }
            
            let sortedApps = installedApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async {
                self.appState.installedApplications = sortedApps
            }
        }
    }
}

