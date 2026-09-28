//
//  MDMInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation
import Observation

@MainActor
@Observable
class MdmInfoManager {
    static let shared = MdmInfoManager(
        mdmInfo: MdmInfo(
            id: UUID(),
            abm: "",
            enrolled: "",
            enrolledDate: ""
        )
    )
    
    var mdmInfo: MdmInfo
    
    init(mdmInfo: MdmInfo) {
        self.mdmInfo = mdmInfo
    }
    
    func refresh() {
        updateMdmInfo()
    }
    
    func updateMdmInfo() {
        Task {
        let mdmDetails = await getMDMStatus()
            self.mdmInfo = MdmInfo(
                id: UUID(),
                abm: mdmDetails["ABM"] ?? "",
                enrolled: mdmDetails["Enrolled"] ?? "",
                enrolledDate: mdmDetails["EnrollmentDate"] ?? ""
            )
        }
    }
}
