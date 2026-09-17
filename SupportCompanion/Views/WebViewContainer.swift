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
        VStack {
            WebView(state: state)

            if state.isLoading {
                ProgressView(value: state.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()
            }
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

    func makeNSView(context: Context) -> WKWebView {
        let webView = state.webView
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed as the `WKWebView` instance is persistent
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        private let state: WebViewState

        init(state: WebViewState) {
            self.state = state
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            state.isLoading = false
        }
    }
}
