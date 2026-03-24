import SwiftUI

public struct StateScope<Content: View>: View {

    @State private var context = StateContext()

    let content: () -> Content
    
    @Environment(\.self) private var environment

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    @ViewBuilder
    public var body: some View {
        StateRuntime
            .stateRun(context: context, body: content)
    }
}
