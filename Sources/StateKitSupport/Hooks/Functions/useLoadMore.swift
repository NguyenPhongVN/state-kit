import Foundation

/// A single page returned by `useLoadMore`.
///
/// The page carries the newly fetched items plus the cursor needed to load
/// the next page. Set `nextCursor` to `nil` when there are no more pages.
public struct LoadMorePage<Item, Cursor>: Sendable where Item: Sendable, Cursor: Sendable {
    public let items: [Item]
    public let nextCursor: Cursor?

    public init(
        items: [Item],
        nextCursor: Cursor?
    ) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

/// The current state and controls returned by `useLoadMore`.
///
/// `phase` represents the current list-level async state:
/// - before the first successful load, it moves through `.idle`, `.loading`,
///   `.success`, and `.failure`
/// - after a successful load, later `reload()` calls keep the last
///   `.success(items)` visible while `isReloading` becomes `true`
///
/// `loadMoreError` is separate from `phase` because loading the next page
/// should not replace already rendered items with a failure phase.
public struct LoadMoreController<Item> {
    public let phase: AsyncPhase<[Item]>
    public let isReloading: Bool
    public let isLoadingMore: Bool
    public let reloadError: Error?
    public let loadMoreError: Error?
    public let hasNextPage: Bool
    public var reload: @MainActor () -> Void
    public var loadNext: @MainActor () -> Void

    /// The currently available items.
    ///
    /// This is empty before the first success. After a success, it stays
    /// populated during later reloads and load-more failures.
    public var items: [Item] {
        phase.value ?? []
    }
}

private final class _HookLoadMoreBox<Item, Cursor> {
    let phaseSignal: StateSignal<AsyncPhase<[Item]>>
    let isReloadingSignal: StateSignal<Bool>
    let isLoadingMoreSignal: StateSignal<Bool>
    let reloadErrorSignal: StateSignal<Error?>
    let loadMoreErrorSignal: StateSignal<Error?>
    let hasNextPageSignal: StateSignal<Bool>
    var updateStrategy: UpdateStrategy?
    var nextCursor: Cursor?
    var task: Task<Void, Never>? {
        didSet { oldValue?.cancel() }
    }
    var reload: (@MainActor () -> Void)?
    var loadNext: (@MainActor () -> Void)?

    init(
        updateStrategy: UpdateStrategy?,
        initialCursor: Cursor
    ) {
        self.phaseSignal = StateSignal(.idle)
        self.isReloadingSignal = StateSignal(false)
        self.isLoadingMoreSignal = StateSignal(false)
        self.reloadErrorSignal = StateSignal(nil)
        self.loadMoreErrorSignal = StateSignal(nil)
        self.hasNextPageSignal = StateSignal(true)
        self.updateStrategy = updateStrategy
        self.nextCursor = initialCursor
    }

    deinit {
        task?.cancel()
    }
}

/// Returns paginated async state plus imperative `reload()` and `loadNext()`
/// actions for building infinite lists and feed-style UIs.
///
/// `useLoadMore` keeps previously loaded items visible while refreshing or
/// appending later pages. This makes it suitable for list screens where
/// losing already rendered content during a background refresh would be
/// undesirable.
///
/// Behavior:
/// - Initial state is `.idle`.
/// - `reload()` starts the first load or refreshes the whole list.
/// - On the first `reload()`, `phase` becomes `.loading`.
/// - Once a page succeeds, `phase` becomes `.success(allItems)`.
/// - Later `reload()` calls keep the last success visible while
///   `isReloading` becomes `true`.
/// - `loadNext()` appends the next page to the existing items.
/// - If `loadNext()` fails, existing items stay visible and the error is
///   exposed through `loadMoreError`.
/// - If `reload()` fails before any success exists, `phase` becomes
///   `.failure(error)`. If it fails after a success already exists, the old
///   items stay visible and the error is exposed through `reloadError`.
///
/// If a new request starts while an older one is still in flight, the older
/// task is cancelled and replaced by the new one.
///
/// - Parameters:
///   - initialCursor: The cursor used for the first page. This can be page
///     number `1`, an API token, or any other pagination marker.
///   - updateStrategy: Controls when the stored loader is replaced.
///   - priority: The priority used for spawned tasks.
///   - loadPage: The async page loader. Return `nextCursor == nil` when
///     there are no more pages.
/// - Returns: A `LoadMoreController` containing state and actions.
///
/// ### Example
/// ```swift
/// struct FeedView: StateView {
///     var stateBody: some View {
///         let feed = useLoadMore(initialCursor: 1) { page in
///             let response = try await api.fetchFeed(page: page)
///             return LoadMorePage(
///                 items: response.items,
///                 nextCursor: response.hasNextPage ? page + 1 : nil
///             )
///         }
///
///         VStack {
///             Button("Reload") { feed.reload() }
///
///             switch feed.phase {
///             case .idle:
///                 Text("Ready")
///             case .loading:
///                 ProgressView()
///             case .success:
///                 List(feed.items, id: \.id) { item in
///                     Text(item.title)
///                 }
///             case .failure(let error):
///                 Text(error.localizedDescription)
///             }
///         }
///     }
/// }
/// ```
@MainActor
public func useLoadMore<Item, Cursor>(
    initialCursor: Cursor,
    updateStrategy: UpdateStrategy? = .once,
    priority: TaskPriority? = nil,
    _ loadPage: @escaping @Sendable (Cursor) async throws -> LoadMorePage<Item, Cursor>
) -> LoadMoreController<Item> {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()
    let box: _HookLoadMoreBox<Item, Cursor>

    if context.states.count <= index {
        box = _HookLoadMoreBox(
            updateStrategy: updateStrategy,
            initialCursor: initialCursor
        )
        context.states.append(box)
    } else {
        box = context.states[index] as! _HookLoadMoreBox<Item, Cursor>
        if box.updateStrategy?.dependency != updateStrategy?.dependency {
            box.task?.cancel()
            box.phaseSignal.value = .idle
            box.isReloadingSignal.value = false
            box.isLoadingMoreSignal.value = false
            box.reloadErrorSignal.value = nil
            box.loadMoreErrorSignal.value = nil
            box.hasNextPageSignal.value = true
            box.nextCursor = initialCursor
            box.updateStrategy = updateStrategy
        }
    }

    box.reload = {
        let previousItems = box.phaseSignal.value.value

        box.isReloadingSignal.value = true
        box.isLoadingMoreSignal.value = false
        box.reloadErrorSignal.value = nil
        box.loadMoreErrorSignal.value = nil

        if previousItems == nil {
            box.phaseSignal.value = .loading
        }

        box.task = Task(priority: priority) { @MainActor in
            do {
                let page = try await loadPage(initialCursor)
                guard !Task.isCancelled else { return }

                box.phaseSignal.value = .success(page.items)
                box.nextCursor = page.nextCursor
                box.hasNextPageSignal.value = page.nextCursor != nil
                box.isReloadingSignal.value = false
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }

                box.isReloadingSignal.value = false
                box.reloadErrorSignal.value = error

                if previousItems == nil {
                    box.phaseSignal.value = .failure(error)
                }
            }
        }
    }

    box.loadNext = {
        guard
            !box.isReloadingSignal.value,
            !box.isLoadingMoreSignal.value,
            let cursor = box.nextCursor,
            let existingItems = box.phaseSignal.value.value
        else {
            return
        }

        box.isLoadingMoreSignal.value = true
        box.loadMoreErrorSignal.value = nil

        box.task = Task(priority: priority) { @MainActor in
            do {
                let page = try await loadPage(cursor)
                guard !Task.isCancelled else { return }

                box.phaseSignal.value = .success(existingItems + page.items)
                box.nextCursor = page.nextCursor
                box.hasNextPageSignal.value = page.nextCursor != nil
                box.isLoadingMoreSignal.value = false
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }

                box.isLoadingMoreSignal.value = false
                box.loadMoreErrorSignal.value = error
            }
        }
    }

    let reload = useCallback(updateStrategy: .once, {
        box.reload?()
    } as @MainActor () -> Void)

    let loadNext = useCallback(updateStrategy: .once, {
        box.loadNext?()
    } as @MainActor () -> Void)

    return LoadMoreController(
        phase: box.phaseSignal.value,
        isReloading: box.isReloadingSignal.value,
        isLoadingMore: box.isLoadingMoreSignal.value,
        reloadError: box.reloadErrorSignal.value,
        loadMoreError: box.loadMoreErrorSignal.value,
        hasNextPage: box.hasNextPageSignal.value,
        reload: reload,
        loadNext: loadNext
    )
}

/// Returns a paginated controller for a non-throwing page loader.
///
/// This overload keeps the same semantics as the throwing version, except
/// that `reloadError` and `loadMoreError` can never be produced by the
/// loader itself.
@MainActor
public func useLoadMore<Item, Cursor>(
    initialCursor: Cursor,
    updateStrategy: UpdateStrategy? = .once,
    priority: TaskPriority? = nil,
    _ loadPage: @escaping @Sendable (Cursor) async -> LoadMorePage<Item, Cursor>
) -> LoadMoreController<Item> {
    let throwingLoader: @Sendable (Cursor) async throws -> LoadMorePage<Item, Cursor> = {
        await loadPage($0)
    }
    return useLoadMore(
        initialCursor: initialCursor,
        updateStrategy: updateStrategy,
        priority: priority,
        throwingLoader
    )
}
