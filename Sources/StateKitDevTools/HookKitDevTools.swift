import SwiftUI
@_exported import StateKitCore
// MARK: - Public DevTools namespace
public enum HookDevTools {
    /// Mô tả ngắn gọn một slot state trong HookContext.
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

    /// Chuyển giá trị thành chuỗi đọc được.
    public static func valueString(_ value: Any) -> String {
        // Ưu tiên một số kiểu phổ biến
        if let s = value as? String { return "\"\(s)\"" }
        if let d = value as? Double { return String(d) }
        if let i = value as? Int { return String(i) }
        if let b = value as? Bool { return String(b) }
        return String(describing: value)
    }
}

// MARK: - HookDevScope: Scope thay thế có overlay DevTools
@MainActor
public struct HookDevScope<Content: View>: View {

    @State private var context = StateContext()
    @State private var renderCount: Int = 0

    public let showOverlay: Bool
    public let overlayAlignment: Alignment

    let content: () -> Content

    public init(
        showOverlay: Bool = true,
        overlayAlignment: Alignment = .topLeading,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showOverlay = showOverlay
        self.overlayAlignment = overlayAlignment
        self.content = content
    }

    public var body: some View {
        StateRuntime.begin(context)
        let view = content()
        StateRuntime.end()

        // Tăng bộ đếm mỗi lần body được tính lại (debug-only, chấp nhận dùng async tick)
        DispatchQueue.main.async {
            self.renderCount += 1
        }

        return view.modifier(HookDevOverlayModifier(
            show: showOverlay,
            alignment: overlayAlignment,
            renderCount: renderCount,
            statesProvider: { context.states }
        ))
    }
}

// MARK: - Overlay modifier + overlay view
private struct HookDevOverlayModifier: ViewModifier {
    let show: Bool
    let alignment: Alignment
    let renderCount: Int
    let statesProvider: () -> [Any]

    func body(content: Content) -> some View {
        #if DEBUG
        if show {
            content.overlay(alignment: alignment) {
                HookDevOverlay(renderCount: renderCount, states: statesProvider())
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct HookDevOverlay: View {
    let renderCount: Int
    let states: [Any]

    var body: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 4) {
            Text("Hook DevTools").font(.caption2).bold()
            Text("Renders: \(renderCount)").font(.caption2).monospaced()
            Text("Slots: \(states.count)").font(.caption2).monospaced()
            if !states.isEmpty {
                Divider().opacity(0.2)
            }
            ForEach(Array(states.enumerated()), id: \.0) { idx, any in
                Text("[\(idx)] \(HookDevTools.describe(any))")
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

// MARK: - HookDevView: thay thế nhanh cho HookView khi cần debug
public protocol HookDevView: View {
    associatedtype HookBody: View
    @ViewBuilder @MainActor var hookBody: Self.HookBody { get }
}

public extension HookDevView {
    var body: some View {
        HookDevScope {
            hookBody
        }
    }
}

