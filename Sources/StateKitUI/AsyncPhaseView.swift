import SwiftUI
import StateKit

// MARK: - AsyncPhaseView

/// A view that renders different content for each phase of an `AsyncPhase`.
///
/// ```swift
/// AsyncPhaseView(phase) { value in
///     Text(value)
/// }
/// ```
///
/// Custom overrides for any phase:
///
/// ```swift
/// AsyncPhaseView(phase) { value in
///     Text(value)
/// } idle: {
///     Text("Tap to load")
/// } loading: {
///     ProgressView()
/// } failure: { error in
///     Text(error.localizedDescription)
/// }
/// ```
public struct AsyncPhaseView<Value, Success: View, Idle: View, Loading: View, Failure: View>: View {

    private let phase: AsyncPhase<Value>
    private let success: (Value) -> Success
    private let idle: () -> Idle
    private let loading: () -> Loading
    private let failure: (Error) -> Failure

    public init(
        _ phase: AsyncPhase<Value>,
        @ViewBuilder success: @escaping (Value) -> Success,
        @ViewBuilder idle: @escaping () -> Idle,
        @ViewBuilder loading: @escaping () -> Loading,
        @ViewBuilder failure: @escaping (Error) -> Failure
    ) {
        self.phase = phase
        self.success = success
        self.idle = idle
        self.loading = loading
        self.failure = failure
    }

    public var body: some View {
        switch phase {
        case .idle:
            idle()
        case .loading:
            loading()
        case .success(let value):
            success(value)
        case .failure(let error):
            failure(error)
        }
    }
}

// MARK: - Default idle + loading + failure

public extension AsyncPhaseView
where Idle == EmptyView, Loading == _DefaultLoadingView, Failure == _DefaultFailureView {

    /// Convenience init with default idle (empty), loading (spinner), and failure (error message) views.
    init(
        _ phase: AsyncPhase<Value>,
        @ViewBuilder success: @escaping (Value) -> Success
    ) {
        self.init(
            phase,
            success: success,
            idle: { EmptyView() },
            loading: { _DefaultLoadingView() },
            failure: { error in _DefaultFailureView(error: error) }
        )
    }
}

// MARK: - Default loading + failure (custom idle)

public extension AsyncPhaseView
where Loading == _DefaultLoadingView, Failure == _DefaultFailureView {

    /// Convenience init with a custom idle view and default loading/failure views.
    init(
        _ phase: AsyncPhase<Value>,
        @ViewBuilder success: @escaping (Value) -> Success,
        @ViewBuilder idle: @escaping () -> Idle
    ) {
        self.init(
            phase,
            success: success,
            idle: idle,
            loading: { _DefaultLoadingView() },
            failure: { error in _DefaultFailureView(error: error) }
        )
    }
}

// MARK: - Default idle + failure (custom loading)

public extension AsyncPhaseView
where Idle == EmptyView, Failure == _DefaultFailureView {

    /// Convenience init with a custom loading view and default idle/failure views.
    init(
        _ phase: AsyncPhase<Value>,
        @ViewBuilder success: @escaping (Value) -> Success,
        @ViewBuilder loading: @escaping () -> Loading
    ) {
        self.init(
            phase,
            success: success,
            idle: { EmptyView() },
            loading: loading,
            failure: { error in _DefaultFailureView(error: error) }
        )
    }
}

// MARK: - Default idle + loading (custom failure)

public extension AsyncPhaseView
where Idle == EmptyView, Loading == _DefaultLoadingView {

    /// Convenience init with a custom failure view and default idle/loading views.
    init(
        _ phase: AsyncPhase<Value>,
        @ViewBuilder success: @escaping (Value) -> Success,
        @ViewBuilder failure: @escaping (Error) -> Failure
    ) {
        self.init(
            phase,
            success: success,
            idle: { EmptyView() },
            loading: { _DefaultLoadingView() },
            failure: failure
        )
    }
}

// MARK: - Default Subviews

public struct _DefaultLoadingView: View {
    public var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct _DefaultFailureView: View {
    let error: Error

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
