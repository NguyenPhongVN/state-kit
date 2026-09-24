import SwiftUI

/// Establishes the hook runtime for its content: every `use*` hook inside the
/// builder claims its slot in this scope's context, in call order.
public struct StateScope<Content: View>: View {

    @State private var context = StateContext()

    let content: @MainActor () -> Content

    @Environment(\.self) private var environment

    /// - Parameter content: The view builder whose hooks belong to this scope.
    public init(@ViewBuilder content: @escaping @MainActor () -> Content) {
        self.content = content
    }

    @ViewBuilder
    /// Runs the builder inside the hook runtime and renders the result.
    public var body: some View {
        StateRuntime
            .stateRun(context: context, environment: environment, body: content)
    }
}
