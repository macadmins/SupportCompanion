//
//  SidebarConfig.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-17.
//

import Foundation
import SwiftUI

func generateSidebarItems(preferences: Preferences, stateManager: WebViewStateManager) -> [SidebarItem] {
    var items: [SidebarItem] = [
        SidebarItem(
            label: Constants.Navigation.home,
            systemImage: "house.fill",
            destination: AnyView(
                CardGrid(
                    viewModel: CardGridViewModel(
                        appState: AppStateManager.shared
                    )
                )
            )
        )
    ]

    if preferences.menuShowIdentity {
        items.append(
            SidebarItem(
                label: Constants.Navigation.identity,
                systemImage: "person.fill",
                destination: AnyView(
                    Identity()
                )
            )
        )
    }

    if preferences.menuShowApps {
        items.append(
            SidebarItem(
                label: Constants.Navigation.apps,
                systemImage: "app.fill",
                destination: AnyView(
                    Applications()
                )
            )
        )
    }
    
    if !preferences.actions.isEmpty && preferences.menuShowSelfService {
        items.append(
            SidebarItem(
                label: Constants.Navigation.selfService,
                systemImage: "wrench.and.screwdriver.fill",
                destination: AnyView(
                    SelfService()
                )
            )
        )
    }
    
    // Add "Company Portal" with persistent WebViewState
    if preferences.menuShowCompanyPortal {
        if preferences.mode == Constants.modes.intune || FileManager.default.fileExists(atPath: Constants.AppPaths.companyPortal) {
            let companyPortalState = stateManager.getWebViewState(
                for: "CompanyPortal",
                url: URL(string: "https://portal.manage.microsoft.com/")!
            )
            items.append(
                SidebarItem(
                    label: "Company Portal",
                    systemImage: "briefcase.fill",
                    destination: AnyView(WebViewContainer(state: companyPortalState))
                )
            )
        }
    }

    // Add "Knowledge Base" with persistent WebViewState
    if preferences.menuShowKnowledgeBase && !preferences.knowledgeBaseUrl.isEmpty {
        let knowledgeBaseState = stateManager.getWebViewState(
            for: "KnowledgeBase",
            url: URL(string: preferences.knowledgeBaseUrl)!
        )
        items.append(
            SidebarItem(
                label: Constants.Navigation.knowledgeBase,
                systemImage: "book.fill",
                destination: AnyView(WebViewContainer(state: knowledgeBaseState))
            )
        )
    }
    
    return items
}
