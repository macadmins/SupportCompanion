//
//  FleetModelsTests.swift
//  SupportCompanionTests
//

import Foundation
import Testing
@testable import SupportCompanion

@Suite("Fleet models")
struct FleetModelsTests {

    private func decodeSoftware(_ json: String) throws -> FleetSoftwareListResponse {
        try JSONDecoder.fleet.decode(FleetSoftwareListResponse.self, from: Data(json.utf8))
    }

    @Test("Decodes the example response from Fleet's REST API docs")
    func decodesDocsExample() throws {
        let response = try decodeSoftware(Fixtures.docsSoftwareList)
        #expect(response.software.count == 1)
        #expect(response.meta?.hasNextResults == false)

        let chrome = try #require(response.software.first)
        #expect(chrome.id == 936)
        #expect(chrome.title == "Google Chrome") // empty display_name falls back to name
        #expect(chrome.status == nil)
        #expect(chrome.installedVersion == "149.0.7827.54")
        #expect(chrome.availableVersion == "149.0.7827.54")
        #expect(chrome.categories == ["Browsers"])
        #expect(chrome.isInstalled)
        #expect(!chrome.isUpdateAvailable)
        #expect(chrome.canUninstall)
        #expect(chrome.primaryAction == nil)
    }

    @Test("Installed title with a newer package offers an update")
    func updateAvailable() throws {
        let slack = try #require(try decodeSoftware(Fixtures.edgeCases).software.first { $0.id == 10 })
        #expect(slack.title == "Slack for Work")
        #expect(slack.installedVersion == "4.41.105") // highest of the installed versions
        #expect(slack.availableVersion == "4.42.1")
        #expect(slack.isUpdateAvailable)
        #expect(slack.primaryAction == .update)
        #expect(slack.installer?.lastInstall?.installUuid == "abc-123")
        #expect(slack.installer?.lastInstall?.installedAt != nil) // fractional-second timestamp
    }

    @Test("Pending install offers no action")
    func pendingInstall() throws {
        let request = try #require(try decodeSoftware(Fixtures.edgeCases).software.first { $0.id == 11 })
        #expect(request.status == .pendingInstall)
        #expect(request.isPending)
        #expect(!request.isInstalled)
        #expect(request.primaryAction == nil)
        #expect(!request.canUninstall)
    }

    @Test("Unknown status decodes, and App Store apps can't be uninstalled")
    func unknownStatusAndAppStoreApp() throws {
        let keynote = try #require(try decodeSoftware(Fixtures.edgeCases).software.first { $0.id == 12 })
        #expect(keynote.status == .unknown)
        #expect(keynote.softwarePackage == nil)
        #expect(keynote.appStoreApp?.appStoreId == "409183694")
        #expect(keynote.primaryAction == .install)
        #expect(!keynote.canUninstall)
    }

    @Test("SSO-required error body is recognized")
    func ssoRequiredError() throws {
        let body = #"{"message":"Authentication required","errors":[{"name":"base","reason":"Single sign-on required"}],"uuid":"x","sso_required":true}"#
        let error = try JSONDecoder.fleet.decode(FleetErrorResponse.self, from: Data(body.utf8))
        #expect(error.ssoRequired == true)
        #expect(error.summary == "Single sign-on required")
    }

    @Test("Version comparison is numeric", arguments: [
        ("4.9", "4.10", true),
        ("4.10", "4.9", false),
        ("149.0.7827.54", "149.0.7827.54", false),
        ("4.41.105", "4.42.1", true),
        ("1.0", "1.0.1", true),
    ])
    func versionComparison(lhs: String, rhs: String, older: Bool) {
        #expect(FleetVersion.isOlder(lhs, than: rhs) == older)
    }
}

private enum Fixtures {
    /// `GET /api/v1/fleet/device/:token/software` example from Fleet's REST API docs.
    static let docsSoftwareList = """
    {
      "count": 1,
      "software": [
        {
          "id": 936,
          "name": "Google Chrome",
          "icon_url": null,
          "source": "apps",
          "extension_for": "",
          "status": null,
          "installed_versions": [
            {
              "version": "149.0.7827.54",
              "bundle_identifier": "com.google.Chrome",
              "vulnerabilities": null,
              "installed_paths": ["/Applications/Google Chrome.app"],
              "signature_information": [
                {
                  "installed_path": "/Applications/Google Chrome.app",
                  "team_identifier": "EQHXZ8M8AV",
                  "hash_sha256": "ce484e67c58b18313382e9fe2e225df52fb20b5f",
                  "executable_sha256": null,
                  "executable_path": null
                }
              ],
              "last_opened_at": "2026-06-04T15:22:36Z"
            }
          ],
          "display_name": "",
          "software_package": {
            "name": "GoogleChrome.pkg",
            "automatic_install_policies": null,
            "version": "149.0.7827.54",
            "platform": "darwin",
            "self_service": true,
            "has_uninstall_script": true,
            "last_install": null,
            "last_uninstall": null,
            "package_url": null,
            "categories": ["Browsers"]
          },
          "app_store_app": null
        }
      ],
      "meta": { "has_next_results": false, "has_previous_results": false }
    }
    """

    static let edgeCases = """
    {"count": 3, "software": [
     {"id": 10, "name": "Slack", "display_name": "Slack for Work", "icon_url": null, "source": "apps", "status": "installed",
      "installed_versions": [{"version": "4.41.105", "bundle_identifier": "com.tinyspeck.slackmacgap"}, {"version": "4.9.0"}],
      "software_package": {"name": "Slack.pkg", "version": "4.42.1", "platform": "darwin", "self_service": true, "has_uninstall_script": true,
        "last_install": {"install_uuid": "abc-123", "installed_at": "2026-09-01T10:20:30.123456Z"}, "last_uninstall": null, "categories": ["Communication"]},
      "app_store_app": null},
     {"id": 11, "name": "Request software", "display_name": "", "icon_url": null, "source": "", "status": "pending_install", "installed_versions": null,
      "software_package": {"name": "request.sh", "version": "1.0", "platform": "darwin", "self_service": true,
        "last_install": {"install_uuid": "def-456", "installed_at": "2026-09-17T09:00:00Z"}},
      "app_store_app": null},
     {"id": 12, "name": "Keynote", "display_name": "", "icon_url": null, "source": "apps", "status": "some_future_status", "installed_versions": [],
      "software_package": null,
      "app_store_app": {"app_store_id": "409183694", "name": "Keynote", "version": "14.4", "platform": "darwin", "self_service": true}}
    ], "meta": {"has_next_results": true}}
    """
}
