//
//  ImageUtilities.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-12-11.
//

import Foundation
import SwiftUI

func base64ToImage(_ base64String: String) -> Image? {
    // Decode Base64 string to Data
    guard let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
          let cgImageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
        Logger.shared.logDebug("Failed to decode Base64 string to Image")
        return nil
    }

    // Return a SwiftUI Image
    return Image(decorative: cgImage, scale: 1.0, orientation: .up)
}

func loadLogo(base64Logo: String) -> Bool {
    if base64Logo.isEmpty {
        return false
    } else if let _ = base64ToImage(base64Logo) {
        return true
    } else {
        Logger.shared.logDebug("Invalid Base64 string for brand logo.")
        return false
    }
}
