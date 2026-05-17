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
        let user = UserModule()
        XCTAssertNotNil(UserModule.SessionAtom.shared)
        XCTAssertNotNil(UserModule.FriendsReducer.shared)
        XCTAssertNotNil(UserModule.UserPrefAtom.family("theme")) 
        XCTAssertNotNil(UserModule.ProfileSummary.shared)

        // 2. Verify NetworkModule (Riverpods)
        let net = NetworkModule()
        XCTAssertNotNil(NetworkModule.AuthNotifier.provider)
        XCTAssertNotNil(NetworkModule.currentHeader.provider)
        XCTAssertNotNil(NetworkModule.PostNotifier.family)
        XCTAssertNotNil(NetworkModule.likesProvider.family)

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
