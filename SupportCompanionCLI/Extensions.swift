//
//  Extensions.swift
//  SupportCompanionCLI
//
//  Created by Tobias Almén on 2024-12-18.
//

import Foundation

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
