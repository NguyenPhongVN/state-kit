import SwiftUI

public struct StateScope<Content: View>: View {

    @State private var context = StateContext()

    let content: @MainActor () -> Content

    @Environment(\.self) private var environment

    public init(@ViewBuilder content: @escaping @MainActor () -> Content) {
        self.content = content
    }

    @ViewBuilder
    public var body: some View {
        StateRuntime
            .stateRun(context: context, environment: environment, body: content)
    }
}
