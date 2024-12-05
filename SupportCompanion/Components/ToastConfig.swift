//
//  ToastConfig.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-18.
//

import Foundation
import AlertToast

struct ToastConfig {
    var isShowing: Bool = false
    var type: AlertToast.AlertType = .complete(.green)
    var title: String = ""
    var subTitle: String? = nil
}
