//
//  WebView.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-17.
//

import SwiftUI
import WebKit

struct WebViewWrapper: NSViewRepresentable {
    let webView: WKWebView
    let url: URL
    @Binding var isLoading: Bool

    func makeNSView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self, isLoading: $isLoading)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewWrapper
        @Binding var isLoading: Bool

        init(_ parent: WebViewWrapper, isLoading: Binding<Bool>) {
            self.parent = parent
            self._isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}
