//
//  WebViewState.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-18.
//

import Foundation
import WebKit

import Foundation
import WebKit

class WebViewState: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var isLoading: Bool = false
    @Published var progress: Double = 0.0
    private var webViewInstance: WKWebView?
    
    var webView: WKWebView {
        if let webView = webViewInstance {
            return webView
        }
        let webView = WKWebView()
        webView.navigationDelegate = self
        observeProgress(for: webView)
        DispatchQueue.main.async { [weak webView, url = self.url] in
            guard let webView = webView else { return }
            webView.load(URLRequest(url: url))
        }
        webViewInstance = webView
        return webView
    }
    
    private let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    private func observeProgress(for webView: WKWebView) {
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    }
    
    /// Aborts any in-flight load when the view disappears. The KVO observer and
    /// navigation delegate are deliberately left in place: this instance is cached by
    /// WebViewStateManager and reused when the user navigates back, and tearing the
    /// observer down here would make deinit remove it a second time.
    func stopLoading() {
        webViewInstance?.stopLoading()
    }

    deinit {
        webViewInstance?.stopLoading()
        webViewInstance?.navigationDelegate = nil
        webViewInstance?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
    
    // Now the `observeValue` method works because WebViewState inherits from `NSObject`
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.estimatedProgress), let webView = object as? WKWebView {
            DispatchQueue.main.async {
                self.progress = webView.estimatedProgress
            }
        }
    }
    
    // WKNavigationDelegate methods
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.isLoading = true
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
}
