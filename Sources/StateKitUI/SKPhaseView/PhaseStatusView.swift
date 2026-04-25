import SwiftUI
import StateKit

// MARK: - PhaseStatusView

/// A view that renders different content based on an `AsyncPhase.Status`.
///
/// Use this when you have a status value (no success payload or error) and
/// want to branch on which phase you're in:
///
/// ```swift
/// SKStatusView(phase.status) {
///     Text("Done!")
/// }
/// ```
///
/// Custom overrides for any phase:
///
/// ```swift
/// SKStatusView(phase.status) {
///     Text("Done!")
/// } idle: {
///     Text("Tap to start")
/// } loading: {
///     ProgressView("Loading…")
/// } failure: {
///     Text("Something went wrong")
/// }
/// ```
public struct SKStatusView<Value, Idle: View, Loading: View, Success: View, Failure: View>: View {

    private let status: SKStatus
    private let success: () -> Success
    private let idle: () -> Idle
    private let loading: () -> Loading
    private let failure: () -> Failure

    public init(
        _ status: SKStatus,
        @ViewBuilder success: @escaping () -> Success,
        @ViewBuilder idle: @escaping () -> Idle,
        @ViewBuilder loading: @escaping () -> Loading,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.status = status
        self.success = success
        self.idle = idle
        self.loading = loading
        self.failure = failure
    }

    public var body: some View {
        switch status {
            case .idle:    idle()
            case .loading: loading()
            case .success: success()
            case .failure: failure()
        }
    }
}

/*

// MARK: - Default idle + loading + failure

public extension SKStatusView
where Idle == EmptyView, Loading == _DefaultLoadingView, Failure == _DefaultStatusFailureView {

    /// Convenience init with default idle (empty), loading (spinner), and failure (generic error) views.
    init(
        _ status: SKStatus,
        @ViewBuilder success: @escaping () -> Success
    ) {
        self.init(
            status,
            success: success,
            idle: { EmptyView() },
            loading: { _DefaultLoadingView() },
            failure: { _DefaultStatusFailureView() }
        )
    }
}

// MARK: - Default loading + failure (custom idle)

public extension SKStatusView
where Loading == _DefaultLoadingView, Failure == _DefaultStatusFailureView {

    /// Convenience init with a custom idle view and default loading/failure views.
    init(
        _ status: SKStatus,
        @ViewBuilder success: @escaping () -> Success,
        @ViewBuilder idle: @escaping () -> Idle
    ) {
        self.init(
            status,
            success: success,
            idle: idle,
            loading: { _DefaultLoadingView() },
            failure: { _DefaultStatusFailureView() }
        )
    }
}

// MARK: - Default idle + failure (custom loading)

public extension SKStatusView
where Idle == EmptyView, Failure == _DefaultStatusFailureView {

    /// Convenience init with a custom loading view and default idle/failure views.
    init(
        _ status: SKStatus,
        @ViewBuilder success: @escaping () -> Success,
        @ViewBuilder loading: @escaping () -> Loading
    ) {
        self.init(
            status,
            success: success,
            idle: { EmptyView() },
            loading: loading,
            failure: { _DefaultStatusFailureView() }
        )
    }
}

// MARK: - Default idle + loading (custom failure)

public extension SKStatusView
where Idle == EmptyView, Loading == _DefaultLoadingView {

    /// Convenience init with a custom failure view and default idle/loading views.
    init(
        _ status: SKStatus,
        @ViewBuilder success: @escaping () -> Success,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.init(
            status,
            success: success,
            idle: { EmptyView() },
            loading: { _DefaultLoadingView() },
            failure: failure
        )
    }
}

// MARK: - Default Subview

public struct _DefaultStatusFailureView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Something went wrong")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

*/
