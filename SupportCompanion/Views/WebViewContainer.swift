//
//  WebViewContainer 2.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-17.
//

import SwiftUI
import WebKit


struct WebViewContainer: View {
    var state: WebViewState

    var body: some View {
        VStack(spacing: 0) {
            WebView(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Always present, hidden rather than removed. Inserting and removing a child as the page
            // loads changes the stack's children in the middle of a layout pass driven by that same
            // load, which is what turned a dependency cycle here into a crash in StackLayout rather
            // than a warning.
            ProgressView(value: state.progress)
                .progressViewStyle(LinearProgressViewStyle())
                .padding()
                .opacity(state.isLoading ? 1 : 0)
                .accessibilityHidden(!state.isLoading)
        }
        .onDisappear {
            state.stopLoading()
        }
    }
}

/// Plain cache, not observable: nothing in the UI reads the dictionary directly.
final class WebViewStateManager {
    // Stored synchronously to avoid the race condition where rapid
    // body re-evaluations would create duplicate WebViewState instances for the
    // same key before the async dispatch had a chance to store the first one.
    // Nothing in the UI observes this dictionary directly — callers use the
    // returned WebViewState (which is @Observable) for reactivity.
    private var webViewStates: [String: WebViewState] = [:]

    func getWebViewState(for id: String, url: URL) -> WebViewState {
        if let existingState = webViewStates[id] {
            return existingState
        }
        let newState = WebViewState(url: url)
        webViewStates[id] = newState
        return newState
    }
}


struct WebView: NSViewRepresentable {
    var state: WebViewState

    /// No coordinator, and no navigation delegate set here.
    ///
    /// `WebViewState` is already the web view's delegate, and its callbacks hop to the main queue
    /// before touching `isLoading` so that a navigation event arriving mid-update cannot write
    /// observable state while SwiftUI is evaluating the view that reads it. A coordinator here would
    /// replace that delegate with one that writes synchronously, which is a dependency cycle:
    /// the write invalidates the body currently being evaluated, and the graph never settles.
    func makeNSView(context: Context) -> WKWebView {
        state.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed as the `WKWebView` instance is persistent
    }

    /// Take the size offered instead of letting SwiftUI ask the web view how big it wants to be.
    ///
    /// Without this, a representable is sized from its `NSView`'s fitting size — and a `WKWebView`'s
    /// fitting size depends on the page it has loaded. The page then reflows to whatever size it is
    /// given, which changes the fitting size again. That loop is a dependency cycle by construction,
    /// and it only shows up on pages that load content, which is why the web pages crash and nothing
    /// else does.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WKWebView, context: Context) -> CGSize? {
        CGSize(
            width: proposal.width ?? nsView.frame.width,
            height: proposal.height ?? nsView.frame.height
        )
    }
}
