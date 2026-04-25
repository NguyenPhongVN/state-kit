import SwiftUI
@_exported import StateKit
@_exported import StateKitUI
@_exported import StateKitSupport

@main
struct CaseStudiesApp: App {
    var body: some Scene {
        WindowGroup {
            SKAtomRoot {
                NavigationStack {
                    ContentView()
                }
            }
        }
    }
}
