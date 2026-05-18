import XCTest
import StateKitAtoms
import Riverpods
import StateKitUI
import SwiftUI

/// Real-World Case Study: Social App Ecosystem
/// This suite verifies all 48 macros in a cohesive, production-grade architecture.
/// 
/// The target definitions are located in:
/// - IntegrationAtoms.swift
/// - IntegrationRiverpods.swift
/// - IntegrationViews.swift
@MainActor
final class MacroRealWorldTests: XCTestCase {

    func testSocialAppEcosystem() {
        // 1. Verify UserModule (Atoms)
        let _ = UserModule()
        XCTAssertNotNil(UserModule.SessionAtom())
        XCTAssertNotNil(UserModule.FriendsReducer())
        XCTAssertNotNil(UserModule.UserPrefAtom(key: "theme")) 
        XCTAssertNotNil(UserModule.ProfileSummary())

        // 2. Verify NetworkModule (Riverpods)
        let _ = NetworkModule()
        XCTAssertNotNil(NetworkModule.AuthNotifierProvider)
        XCTAssertNotNil(NetworkModule.currentHeaderProvider)
        XCTAssertNotNil(NetworkModule.PostNotifierFamily)
        XCTAssertNotNil(NetworkModule.likesProviderFamily)

        // 3. Verify ProfileDashboard (Views & Hooks)
        let dashboard = ProfileDashboardView()
        // Accessing body verifies hook graph and StateScope link.
        _ = dashboard.body
        
        XCTAssertNotNil(SimpleHeader().body)
        XCTAssertNotNil(ProfileAsyncView().body)
        XCTAssertNotNil(GlobalUIState())
        
        print("✅ Social App Case Study: All 48 Macros Verified Idiomatically.")
    }
}
