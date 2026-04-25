//import SwiftUI
//import Observation
//
//public struct SharedStateView<Content: View>: View {
//    let content: Content
//    let container: Container
//    
//    public init(_ parent: Container, @ViewBuilder content: () -> Content) {
//        self.container = Container(parent: parent)
//        self.content = content()
//    }
//    
//    public var body: some View {
//        content
//            .environment(container)
//    }
//}
