//
//  ObservationHelpers.swift
//  SupportCompanion
//

import Foundation
import Observation

/// Keeps an observation started by `observeChanges(of:onChange:)` alive. Call `cancel()` to stop it.
@MainActor
final class ObservationToken {
    fileprivate var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}

/// Calls `onChange` whenever the value returned by `value` changes, for code outside SwiftUI views
/// (the replacement for subscribing to `@Published` publishers).
///
/// `withObservationTracking` only reports the first change, so this re-registers after each one.
/// `onChange` runs on the main actor after the change, and only when the value actually differs.
@MainActor
@discardableResult
func observeChanges<Value: Equatable>(
    of value: @escaping @MainActor () -> Value,
    onChange: @escaping @MainActor (Value) -> Void
) -> ObservationToken {
    let token = ObservationToken()
    var lastValue = value()

    func track() {
        withObservationTracking {
            _ = value()
        } onChange: {
            // Fires before the property is updated, so read the new value on the next main actor turn
            Task { @MainActor in
                guard !token.isCancelled else { return }
                let newValue = value()
                if newValue != lastValue {
                    lastValue = newValue
                    onChange(newValue)
                }
                track()
            }
        }
    }

    track()
    return token
}
