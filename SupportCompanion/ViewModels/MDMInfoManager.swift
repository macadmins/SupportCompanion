//
//  MDMInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation

class MdmInfoManager: ObservableObject {
    static let shared = MdmInfoManager(
        mdmInfo: MdmInfo(
            id: UUID(),
            abm: "",
            enrolled: "",
            enrolledDate: ""
        )
    )
    
    @Published var mdmInfo: MdmInfo
    
    init(mdmInfo: MdmInfo) {
        self.mdmInfo = mdmInfo
    }
    
    func refresh() {
        updateMdmInfo()
    }
    
    func updateMdmInfo() {
        Task {
            let mdmDetails = await getMDMStatus()
            DispatchQueue.main.async {
                self.mdmInfo = MdmInfo(
                    id: UUID(),
                    abm: mdmDetails["ABM"] ?? "",
                    enrolled: mdmDetails["Enrolled"] ?? "",
                    enrolledDate: mdmDetails["EnrollmentDate"] ?? ""
                )
            }
        }
    }
}
