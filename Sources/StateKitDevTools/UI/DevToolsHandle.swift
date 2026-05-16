import SwiftUI

// MARK: - DevTools Handle/Toggle Button

/// A floating button for toggling the DevTools overlay on/off.
///
/// Place this in your app's ZStack to provide easy access to DevTools:
///
/// ```swift
/// ZStack {
///     MyAppView()
///
///     VStack {
///         Spacer()
///         HStack {
///             Spacer()
///             DevToolsHandle(showDevTools: $showDevTools)
///         }
///     }
///     .ignoresSafeArea()
///
///     if showDevTools {
///         StateDevTools(observer: devTools)
///     }
/// }
/// ```
///
/// **Features:**
/// - Floating action button style
/// - Shows current state change count
/// - Smooth animations
/// - Customizable appearance
@MainActor
public struct DevToolsHandle: View {
    /// Whether DevTools overlay is shown.
    @Binding var showDevTools: Bool

    /// The DevTools observer (optional, for showing stats).
    public let observer: DevToolsObserver?

    /// Button size (default: 60).
    public var size: CGFloat = 60

    /// Button colors.
    public var backgroundColor: Color = .blue
    public var foregroundColor: Color = .white

    public init(
        showDevTools: Binding<Bool>,
        observer: DevToolsObserver? = nil,
        size: CGFloat = 60,
        backgroundColor: Color = .blue,
        foregroundColor: Color = .white
    ) {
        self._showDevTools = showDevTools
        self.observer = observer
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    var stateCount: Int {
        observer?.history.entries.count ?? 0
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main button
            Button(action: { withAnimation { showDevTools.toggle() } }) {
                Image(systemName: showDevTools ? "xmark" : "ladybug.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(foregroundColor)
            }
            .frame(width: size, height: size)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(size / 2)
            .shadow(radius: 8)
            .scaleEffect(showDevTools ? 1.1 : 1.0)

            // Badge showing state change count
            if stateCount > 0 {
                VStack {
                    HStack {
                        Text("\(stateCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
                .offset(x: 8, y: -8)
            }
        }
        .padding()
    }
}

// MARK: - Mini Panel

/// A compact mini panel version of DevTools.
///
/// Useful for screens where space is limited.
///
/// ```swift
/// DevToolsMiniPanel(observer: devTools)
///     .frame(height: 100)
/// ```
@MainActor
public struct DevToolsMiniPanel: View {
    @ObservedObject private var observer: ObservedDevToolsObserver
    @State private var expanded = false

    public init(observer: DevToolsObserver) {
        self.observer = ObservedDevToolsObserver(observer: observer)
    }

    var fastestProvider: PerformanceData? {
        observer.observer.metrics.allMetrics.min { $0.averageComputeTime < $1.averageComputeTime }
    }

    var slowestProvider: PerformanceData? {
        observer.observer.metrics.slowestProviders.first
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Image(systemName: "ladybug.fill")
                    .foregroundColor(.blue)
                Text("DevTools")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(observer.observer.history.entries.count)")
                    .font(.caption2)
                    .foregroundColor(.gray)

                Button(action: { expanded.toggle() }) {
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .font(.caption)
                }
            }
            .padding(8)

            // Expanded content
            if expanded {
                VStack(spacing: 8) {
                    // History
                    HStack {
                        Text("History")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(observer.observer.history.currentIndex + 1)/\(observer.observer.history.entries.count)")
                            .font(.caption2)
                    }

                    // Metrics summary
                    if let slowest = slowestProvider {
                        HStack {
                            Text("Slowest")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(slowest.providerName)
                                .font(.caption2)
                                .lineLimit(1)
                            Text(String(format: "%.2f ms", slowest.averageComputeTime))
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }

                    // Controls
                    HStack(spacing: 4) {
                        Button(action: { _ = observer.observer.goBack() }) {
                            Image(systemName: "arrow.left")
                                .font(.caption)
                        }
                        .disabled(!observer.observer.history.canGoBack)

                        Button(action: { _ = observer.observer.goForward() }) {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                        }
                        .disabled(!observer.observer.history.canGoForward)

                        Spacer()

                        Button(action: { observer.observer.clearHistory() }) {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(8)
            }
        }
        .font(.caption)
        .padding(8)
        .background(Color.black.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(8)
        .border(Color.blue.opacity(0.5), width: 1)
    }
}

// MARK: - Quick Stats View

/// Shows quick statistics about current state.
///
/// ```swift
/// DevToolsQuickStats(observer: devTools)
/// ```
@MainActor
public struct DevToolsQuickStats: View {
    @ObservedObject private var observer: ObservedDevToolsObserver

    public init(observer: DevToolsObserver) {
        self.observer = ObservedDevToolsObserver(observer: observer)
    }

    var avgComputeTime: Double {
        guard !observer.observer.metrics.allMetrics.isEmpty else { return 0 }
        let total = observer.observer.metrics.allMetrics
            .map { $0.averageComputeTime }
            .reduce(0, +)
        return total / Double(observer.observer.metrics.allMetrics.count)
    }

    var totalUpdates: Int {
        observer.observer.metrics.allMetrics
            .map { $0.totalCallCount }
            .reduce(0, +)
    }

    public var body: some View {
        HStack(spacing: 20) {
            // History stat
            VStack(spacing: 4) {
                Text("History")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("\(observer.observer.history.entries.count)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            Divider()

            // Performance stat
            VStack(spacing: 4) {
                Text("Avg Time")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(String(format: "%.2f ms", avgComputeTime))
                    .font(.headline)
                    .foregroundColor(avgComputeTime > 50 ? .red : .green)
            }

            Divider()

            // Updates stat
            VStack(spacing: 4) {
                Text("Updates")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("\(totalUpdates)")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DevTools Handle") {
    ZStack {
        Color.gray.ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                DevToolsHandle(
                    showDevTools: .constant(false),
                    observer: DevToolsObserver()
                )
            }
        }
        .ignoresSafeArea()
    }
}

#Preview("Mini Panel") {
    VStack {
        DevToolsMiniPanel(observer: DevToolsObserver())
        Spacer()
    }
    .padding()
    .background(Color.white)
}

#Preview("Quick Stats") {
    DevToolsQuickStats(observer: DevToolsObserver())
        .background(Color.white)
}
#endif
