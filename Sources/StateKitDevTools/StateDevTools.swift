import SwiftUI

// MARK: - StateDevTools

/// Utilities for inspecting hook slots at runtime.
///
/// Used internally by `StateDevScope` to format the overlay. You can also call
/// these methods directly in the Xcode console (via `po`) or in test output.
public enum StateDevTools {

    /// Returns a human-readable description of a single hook slot value.
    ///
    /// Reflects the slot's `value` and `deps` fields when present.
    ///
    /// - Parameter any: A value from `StateContext.states`.
    /// - Returns: A string such as `"StateSignal { value: 42 }"`.
    public static func describe(_ any: Any) -> String {
        let typeName = String(describing: type(of: any))
        let mirror = Mirror(reflecting: any)
        var parts: [String] = []
        for child in mirror.children {
            guard let label = child.label else { continue }
            if label == "value" || label == "deps" {
                parts.append("\(label): \(valueString(child.value))")
            }
        }
        if parts.isEmpty { return typeName }
        return "\(typeName) { \(parts.joined(separator: ", ")) }"
    }

    /// Converts a value to a readable string, with special-casing for common
    /// scalar types (`String`, `Double`, `Int`, `Bool`).
    public static func valueString(_ value: Any) -> String {
        if let s = value as? String { return "\"\(s)\"" }
        if let d = value as? Double { return String(d) }
        if let i = value as? Int    { return String(i) }
        if let b = value as? Bool   { return String(b) }
        return String(describing: value)
    }
}

// MARK: - StateDevScope

/// A drop-in replacement for `StateScope` that renders an optional debug
/// overlay showing render counts and hook slot contents.
///
/// In **Release** builds the overlay is unconditionally stripped; `content`
/// is rendered exactly as `StateScope` would render it.
///
/// ```swift
/// StateDevScope {
///     let (count, setCount) = useState(0)
///     Button("Tap \(count)") { setCount(count + 1) }
/// }
/// ```
///
/// The overlay defaults to `.topLeading`. Pass `overlayAlignment` to move it.
@MainActor
public struct StateDevScope<Content: View>: View {

    @State private var context = StateContext()
    @State private var renderCount: Int = 0

    @Environment(\.self) private var environment

    public let showOverlay: Bool
    public let overlayAlignment: Alignment

    let content: @MainActor () -> Content

    public init(
        showOverlay: Bool = true,
        overlayAlignment: Alignment = .topLeading,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.showOverlay = showOverlay
        self.overlayAlignment = overlayAlignment
        self.content = content
    }

    public var body: some View {
        let view = StateRuntime.stateRun(context: context, environment: environment, body: content)

        // Increment the counter after the current render pass completes.
        // Using Task avoids mutating @State during a view update.
        let _ = Task { @MainActor in renderCount += 1 }

        return view.modifier(StateDevOverlayModifier(
            show: showOverlay,
            alignment: overlayAlignment,
            renderCount: renderCount,
            statesProvider: { context.states }
        ))
    }
}

// MARK: - Overlay modifier

private struct StateDevOverlayModifier: ViewModifier {
    let show: Bool
    let alignment: Alignment
    let renderCount: Int
    let statesProvider: () -> [Any]

    func body(content: Content) -> some View {
        #if DEBUG
        if show {
            content.overlay(alignment: alignment) {
                StateDevOverlay(renderCount: renderCount, states: statesProvider())
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - Overlay view

private struct StateDevOverlay: View {
    let renderCount: Int
    let states: [Any]

    var body: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 4) {
            Text("StateKit DevTools").font(.caption2).bold()
            Text("Renders: \(renderCount)").font(.caption2).monospaced()
            Text("Slots: \(states.count)").font(.caption2).monospaced()
            if !states.isEmpty {
                Divider().opacity(0.2)
            }
            ForEach(Array(states.enumerated()), id: \.0) { idx, any in
                Text("[\(idx)] \(StateDevTools.describe(any))")
                    .font(.caption2)
                    .monospaced()
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(6)
        .opacity(0.95)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        #else
        EmptyView()
        #endif
    }
}

// MARK: - StateDevView

/// A protocol that wraps `stateBody` in a `StateDevScope`, giving you the
/// debug overlay without any extra setup.
///
/// Swap `StateView` → `StateDevView` while debugging and swap back for
/// production. `StateDevView` carries no additional state or stored properties.
///
/// ```swift
/// struct CounterView: StateDevView {
///     var stateBody: some View {
///         let (count, setCount) = useState(0)
///         Button("Count: \(count)") { setCount(count + 1) }
///     }
/// }
/// ```
public protocol StateDevView: View {
    associatedtype StateBody: View
    @ViewBuilder @MainActor var stateBody: Self.StateBody { get }
}

public extension StateDevView {
    var body: some View {
        StateDevScope {
            stateBody
        }
    }
}
