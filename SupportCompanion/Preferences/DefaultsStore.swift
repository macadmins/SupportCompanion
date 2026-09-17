//
//  DefaultsStore.swift
//  SupportCompanion
//

import Foundation
import Observation

/// Backing store for the preference classes.
///
/// `@AppStorage` only works in SwiftUI views, not in `@Observable` classes, so preferences are plain
/// properties that read and write `UserDefaults` through this store. Every read also reads `revision`,
/// and `revision` is bumped whenever the defaults may have changed, so views showing a preference
/// update when it changes, whether the app, an MDM profile, or `defaults write` changed it.
@MainActor
@Observable
final class DefaultsStore {
    static let shared = DefaultsStore()

    private(set) var revision = 0

    @ObservationIgnored private var observer: NSObjectProtocol?

    private init() {
        // Posted synchronously on the thread that changed the defaults
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: nil
        ) { _ in
            if Thread.isMainThread {
                MainActor.assumeIsolated { DefaultsStore.shared.defaultsChanged() }
            } else {
                Task { @MainActor in DefaultsStore.shared.defaultsChanged() }
            }
        }
    }

    /// Call when defaults may have changed without a `UserDefaults.didChangeNotification`,
    /// e.g. after another process wrote the preferences plist.
    func defaultsChanged() {
        revision &+= 1
    }

    static func value<Value>(forKey key: String, default defaultValue: Value) -> Value {
        _ = shared.revision
        return UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue
    }

    static func optionalValue<Value>(forKey key: String) -> Value? {
        _ = shared.revision
        return UserDefaults.standard.object(forKey: key) as? Value
    }

    static func set<Value>(_ value: Value, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static func setOptional<Value>(_ value: Value?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
