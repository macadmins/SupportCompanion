//
//  InstallerFileTypes.swift
//  SupportCompanion
//

import Foundation

/// The installers this app knows how to open.
///
/// Declaring these in `CFBundleDocumentTypes` is what puts Support Companion in Finder's **Open With**
/// menu for a `.pkg` or a `.dmg`, and what lets the Services item appear for them. It is deliberately
/// all this app does about file types.
///
/// It used to also make itself the *default* handler, so that a plain double-click came here first.
/// That is the only way macOS offers to decide per application before Installer.app asks for an
/// administrator password — but setting a default handler raises a consent dialog per type that
/// cannot be suppressed from code, and there is no way to be the handler for only some packages, so
/// every installer on the Mac would have carried this app's icon. Neither is acceptable to put in
/// front of someone at install time, so the user opens an installer here when they mean to, and
/// everything else behaves exactly as it did before this app was on the Mac.
enum InstallerFileTypes {

    /// Declared in `CFBundleDocumentTypes` and in the Services item's `NSSendFileTypes`.
    ///
    /// `CFBundleDocumentTypes` declares the matching file extensions as well as these identifiers.
    /// Binding by identifier alone is enough for a disk image but is not enough for a package: the
    /// apps that do show up under **Open With** for a `.pkg`, such as Suspicious Package, bind `.pkg`
    /// and `.mpkg` by extension, and doing only one of the two leaves the menu item missing.
    static let contentTypes = [
        "com.apple.installer-package-archive",       // a flat .pkg, which is nearly all of them
        "com.apple.installer-distribution-package",  // one built by productbuild
        "com.apple.installer-package",               // the older bundle-shaped .pkg
        "com.apple.installer-meta-package",          // an .mpkg
        "com.apple.disk-image-udif",                 // a .dmg
    ]

    static let fileExtensions: Set<String> = ["pkg", "mpkg", "dmg"]

    // The Services item in `NSServices` also declares `NSRequiredContext`, scoping it to Finder.
    // Without a required context the item does not appear in Finder's contextual menu at all — every
    // third-party service that does show up there declares one, whether it is Suspicious Package
    // naming `com.apple.finder` or kitty naming `NSTextContent: FilePath`.
    //
    // Open With is a different matter and is closed to us for packages: Launch Services offers only
    // Installer.app for a .pkg, whatever an app claims, which is why the Services item carries the
    // whole right-click story for packages while a disk image also appears under Open With.
}
