//
//  FleetSSOSignInSheet.swift
//  SupportCompanion
//
//  Fleet Desktop SSO sign-in: the identity provider's own page, hosted in the app.
//

import SwiftUI
import WebKit

struct FleetSSOSignInSheet: View {
    var controller: FleetSSOController

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 620, height: 640)
    }

    private var header: some View {
        HStack {
            Label(Constants.Fleet.ssoSheetTitle, systemImage: "person.badge.key")
                .font(.headline)
            Spacer()
            Button(Constants.Fleet.cancel) { controller.cancel() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var content: some View {
        switch controller.phase {
        case .failed(let message):
            status(systemImage: "exclamationmark.triangle", title: Constants.Fleet.ssoCouldNotSignIn, detail: message) {
                ScButton(Constants.Fleet.retry) {
                    await controller.start()
                }
                .frame(maxWidth: 200)
            }
        case .signingIn:
            if let webView = controller.webView {
                // The identity provider's page, not Fleet's: the app never sees what's typed into it.
                // Keyed by instance so a retry shows its new web view rather than the failed one.
                FleetSSOWebView(webView: webView)
                    .id(ObjectIdentifier(webView))
            } else {
                status(systemImage: nil, title: Constants.Fleet.ssoConnecting, detail: nil) {
                    ProgressView()
                }
            }
        default:
            status(systemImage: nil, title: Constants.Fleet.ssoConnecting, detail: nil) {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private func status<Accessory: View>(
        systemImage: String?,
        title: String,
        detail: String?,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            accessory()
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Hosts the web view the controller owns, so its navigation delegate survives SwiftUI re-evaluating
/// this view — see WebViewContainer for why no coordinator sets a delegate here.
private struct FleetSSOWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    /// Take the size offered rather than asking the web view how big the loaded page wants to be,
    /// which is a layout cycle.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WKWebView, context: Context) -> CGSize? {
        CGSize(
            width: proposal.width ?? nsView.frame.width,
            height: proposal.height ?? nsView.frame.height
        )
    }
}
