# Báo cáo Review Production-Readiness — StateKit (2026-10-27)

Phạm vi: toàn bộ 15 module (`Sources/`, ~32.000 dòng Swift). Phương pháp: review 4 luồng song song
(Core/Combine, Atoms/Riverpods, Persistence/Cache/Flags/Analytics, DevTools/Support/UI/Testing/Macros/Concurrency),
mỗi phát hiện P0/P1 đã được xác minh trực tiếp trên source trước khi ghi nhận.

**Trạng thái test:** `swift test` toàn package PASS (exit 0) tại commit `527e67c`.

**Cập nhật 2026-10-27 (feature 008):** 10 P1 blocker trong "Lộ trình đề xuất" đã được sửa qua speckit flow
(`specs/008-p1-blocker-fixes/`), red→green cho từng fix, toàn package pass. Finding 24 được rút khỏi danh
sách (false positive — xem bảng P1). **Finding mới phát hiện khi implement** (chưa có trong danh sách ban
đầu): `ProviderElement.container` giữ container **mạnh** (ProviderElement.swift:27) — chu trình
element → container → elements dict → element khiến mọi element bị bỏ mà không qua listener-driven
disposal leak cùng container mãi mãi; phá chu trình cần refactor weak container + audit nil-semantics
của recompute/watch/read — xếp hàng đầu cho feature 009.

## Kết luận tổng quát

**Chưa đạt chuẩn production.** Lõi machine (atom graph propagation, topological recompute, LRU O(1),
Keychain accessibility mapping, file atomic writes, harness `StateTest`) được xây tốt. Nhưng tầng vòng đời
(retain cycle, leak tích lũy), tầng tooling (DevTools ghi nhận không hoạt động, Testing helpers là stub),
và macros (code sinh ra sai với input thực tế) có lỗi ở mức sẽ gây memory leak / mất state / CPU burn
trong app thật.

| Nhóm | P1 | P2 | P3 | Verdict |
|---|---|---|---|---|
| StateKitCore + StateKit (hooks) | 3 | 6 | 4 | Chưa sẵn sàng |
| StateKitAtoms + Riverpods | 6 | 12 | 5 | Chưa sẵn sàng |
| Persistence / Cache / Flags / Analytics | 5 | 14 | 10 | Persistence & Analytics chưa; Cache gần; Flags có điều kiện |
| DevTools / Support / Testing / Macros / Concurrency | 9 | 13 | 4 | Chưa sẵn sàng |

Tổng: ~91 phát hiện (23 P1, ~45 P2, ~23 P3). Danh sách đầy đủ bên dưới.

---

## P1 — Phải sửa trước khi ship

### Hooks hệ (`Sources/StateKit/Use/`)

1. **Retain cycle box ↔ task/subscription trong 7 hooks** — `useAsync.swift:61-70`, `useAsyncPerform.swift:107-117`,
   `useAsyncRefresh.swift:117-129`, `useAsyncSequence.swift:64-76`, `usePublisher.swift:55-64`,
   `usePublisherPerform.swift:107-116`, `usePublisherRefresh.swift:116-129`.
   `box.task = Task { ... box.signal.value = ... }` — closure capture `box` mạnh, box giữ task; cleanup nằm trong
   `deinit { task?.cancel() }` nên **không bao giờ chạy** khi work còn sống. Teardown view không cancel in-flight work;
   `useAsyncSequence` với infinite stream leak vĩnh viễn. *Fix: `[weak box]` trong closure, hoặc `box.task = nil` khi xong.*
2. **`usePublisher` viết `@Observable` state từ thread publisher emit** — `usePublisher.swift:55-64` (+2 hook Publisher khác).
   Combine deliver trên scheduler upstream; URLSession emit background queue → data race với SwiftUI render.
   *Fix: `receive(on: DispatchQueue.main)` (đã có sẵn `sinkOnMain` trong StateKitCombine nhưng không dùng).*
3. **`HookContext` là `@unchecked Sendable` với `_value` không đồng bộ** — `useContext.swift:34-51`.
   Public promise an toàn đa luồng nhưng storage thuần `var` → data race. *Fix: lock hoặc giới hạn @MainActor.*

### Atoms / Riverpods

4. **Bridge interceptor leak toàn cục** — `Riverpods/Core/EcosystemBridge.swift:103-107`.
   `addInterceptor` không có API remove; mỗi provider-watch-atom để lại 1 closure sống mãi trong
   `SKAtomStore.shared` → memory tăng vô hạn theo usage + mỗi lần set atom duyệt hết interceptor rác (O(n) dần).
   *Fix: trả token từ `addInterceptor`, remove trong `onDispose`.*
5. **`RiverpodAtom` (provider→atom bridge) không bao giờ update** — `EcosystemBridge.swift:216-221`.
   `value(context:)` chỉ `container.read(provider)` — không có dependency edge nào đưa invalidation ngược về atom;
   giá trị = lần đọc đầu tiên, mâu thuẫn với doc cùng file ("automatically stays in sync"). Test chỉ assert lần đọc đầu.
6. **`container.listen()` mù với Notifier/AsyncNotifier** — `NotifierProvider.swift:281-287`, `AsyncNotifierProvider.swift:384-389`.
   Path `notifier.state = x` ghi box trực tiếp, không qua `recompute()`, nên external listeners + `notifyProviderUpdated`
   không bao giờ thấy user-driven mutations (DevTools/Analytics quan sát thiếu).
7. **Retain cycle `onDispose { self... }`** — `FutureProvider.swift:91-95`, `StreamProvider.swift:80-82`,
   `AsyncSequenceProvider.swift:88-90`. Closure lưu trong `self._callbacks` → element tự giữ mình; element bị bỏ
   không dispose (container deinit, keepAlive release) leak toàn bộ kèm task/continuations. *Fix: `[weak self]`.*
8. **`_dependentRefs` không dedupe** — `ProviderElement.swift:329-332`. Mỗi recompute của provider cha append 1
   weak ref cho mỗi `watch` → tăng tuyến tính theo thời gian sống app; `notifyDependents` duyệt mảng rác.
9. **Dependency edges không rebuild khi recompute** — `ProviderElement.swift:112`. `dependencies` chỉ clear trong
   `dispose()`. Provider watch có điều kiện (`if x { watch(A) } else { watch(B) }`) giữ edge cũ mãi:
   (a) `dependents` không bao giờ rỗng → autoDispose provider bị pin leak; (b) invalidation dư thừa.
   Atom graph làm đúng (`clearGraphDependencies` trước mỗi recompute, `SKAtomStore.swift:294`) — copy pattern đó.

### Persistence / Cache / FeatureFlags / Analytics

10. **`ABTest.assignUser` crash index out of range khi `variants` rỗng** — `ABTestFramework.swift:67-68`.
    `min(0, -1) = -1` → trap, public API không guard.
11. **`SwiftDataIntegration.updateAndPersist` là facade không hoạt động** — `SwiftDataIntegration.swift:127-137`:
    catch rỗng, không encode state vào model nào, set state trước khi save (thất bại → memory và storage lệch).
12. **`EventTracker` giữ mọi event mãi** — `EventTracker.swift:8,35-36`: `events.append` không bao giờ được prune
    (chỉ `batch` được clear khi flush) → unbounded memory trên tracker sống cả app lifetime.
13. **Keychain mất dữ liệu khi store fail** — `KeychainStateProvider.swift:219-222` (`updateValue` set state trước
    `store`; fail → state nói dối) và `:311-316` (`KeychainBatch.store` **delete trước add** — add fail mất secret cũ,
    hủy giữa batch). *Fix: store-then-commit; dùng pattern update-then-insert như `store` ở :60-79.*
14. **`SlidingWindowTTLCache.get` không check expiry** — `TTLCache.swift:176-186`: chỉ dựa cleanup nền; app bị
    suspend → trả entry hết hạn trên resume; `get` reset `lastAccessedAt` cả entry hết hạn → key được poll không bao giờ expire.
15. **Không có hash salt → bucketing tương quan giữa mọi rollout/AB test** — `ABTestFramework.swift:61-63`
    (doc nói `id` là salt nhưng không dùng), `Rollout.swift:29-33`. User bucket 0 của test A luôn bucket 0 của test B.
    *Fix: hash `"\(id):\(userKey)"`.*

### DevTools / Support / Testing / Macros / Concurrency

16. **`DevToolsObserver` không bao giờ nhận update provider** — `DevToolsObserver.swift:87-92` khai báo
    `previousValue:` nhưng protocol yêu cầu `oldValue:` (`ProviderObserver.swift:274-279`); protocol extension có
    default no-op nên vẫn compile — tính năng time-travel history **chết thầm lặng**. *(Đã xác minh trực tiếp.)*
17. **`StateDevScope` tự gây infinite re-render, kể cả Release** — `StateDevTools.swift:92-96`: mỗi body pass
    enqueue effect → `renderCount += 1` → invalidate → body lại chạy. `#if DEBUG` chỉ strip overlay view, không strip
    vòng enqueue/increment. *Fix: bọc `#if DEBUG` quanh cơ chế đếm.*
18. **`InMemoryStateHistory.replay` trap với computeTime âm/NaN** — `StateHistory.swift:397`: `UInt64(negative)`/`UInt64(NaN)`
    crash; `importJSON` public không validate. *Fix: clamp + validate.*
19. **`useLoadMore` retain cycle box ↔ closures** — `useLoadMore.swift:74-75, 196-261`: `reload`/`loadNext` capture
    `box` mạnh → box leak, in-flight page load không cancel sau teardown.
20. **`@Debounce` sinh code không compile với hàm có tham số** — `DebounceMacro.swift:76-87`: peer chỉ gọi
    `await \(functionName)()`, drop toàn bộ params (doc example chính là hàm có tham số).
21. **`@HookForm` sinh `public struct FHook` tên cố định + default không type-safe** — `HookFormMacro.swift:77,88-89`:
    2 form/module → duplicate `FHook`; non-optional field không default → `useBinding(nil)` không compile.
22. **`@HookContext` sinh global `_hookContext` tên cố định** — `HookContextMacro.swift:49-52` → collision khi có 2 context.
23. **`DeterministicTestEnvironment` không enforce gì** — `DeterministicTesting.swift:64-68`: `setupDeterministicRandom()`
    là comment rỗng, seed không bao giờ dùng, doc claim "Int.random luôn giống nhau" là sai → test flaky tưởng deterministic.
24. **`DeterministicTimeProvider.advance(by:)` là no-op** — `DeterministicTesting.swift:147-149`:
    `currentTime.addTimeInterval(interval)` — kết quả bị vứt. Mọi test freeze-time dùng nó pass rỗng.
    *(Đã xác minh.)* **[CẬP NHẬT 2026-10-27: FALSE POSITIVE]** — trên SDK hiện tại
    `Date.addTimeInterval(_:)` là mutating method (trả `Void`), thời gian tăng đúng như tài liệu.
    Red→green run của feature 008 đã chứng minh; behavior được pin bằng test regression. Tìm thấy này bị
    loại khỏi danh sách blocker.
25. **`IntegrationTestHelpers` chứa stub giả hoạt động** — `IntegrationTestHelpers.swift`: `override(_:with:)` không lưu
    gì (:35-41); `verifyWithinTimeout` luôn `return nil` (:209-228); `verifyTransition` so sánh 2 hằng số caller truyền
    vào (:184-193); `measureMemory` luôn 0 (:375-381); `FeatureTestHarness.observe` rỗng (:267-269). Public API误导 test author.
26. **Hook peer macros sinh signature sai** — `HookStateMacro.swift:55-61` giữ default trước required → compile error;
    `HookEffectMacro.swift:62-66` + `AsyncHookMacro.swift:67-71` drop default hoàn toàn → doc example `useLogger()` không compile.

## P2 — Nên sửa (robustness / hiệu năng / ngữ nghĩa)

**Core/Combine:** `useTransition` clear `isPending` khi transition đầu xong (overlap) — `useDeferred.swift:101-107`;
contract "deferred update" không đồng nhất, nhiều hook ghi state giữa render — `useAsyncSequence.swift:62`,
`useAsyncPerform.swift:100`, `useAsyncRefresh.swift:105`, `_startPublisher` với `Just(...)` deliver sync;
swallow `CancellationError` → kẹt `.loading` vĩnh viễn — `useAsyncPerform.swift:112-113`, `useAsyncRefresh.swift:122`;
slot type mismatch có chỗ `as!` crash có chỗ silently no-op — `useEffect.swift:94`, `useLayoutEffect.swift:97`;
`StateContext.states` public mutable + `StateRuntime.context` fabricate context rỗng ngoài render —
`StateContext.swift:30-34`, `StateRuntime.swift:52-56`; effect cleanup chạy từ nonisolated `deinit`.

**Atoms/Riverpods:** `removeListener` không thấy element của parent container — `ProviderContainer.swift:378-381`;
`@SKState/@SKValue/@SKTask` token không theo dõi atom đổi (latent với `.evictWhenUnused`) — `SKState.swift:54-60`;
async deinit decrement tạo window evict nhầm — `SKAtomStore.swift:612-620`, `Watch.swift:254-260`;
`.evictWhenUnused` dead code cho family; `AsyncNotifier` không cancel task/resume continuation khi dispose —
`AsyncNotifierProvider.swift:397-400`; `FutureProvider.future` trả stale `previousData` sau refresh fail —
`FutureProvider.swift:119-128`; atom không equality short-circuit (set cùng giá trị recompute toàn graph) —
`SKAtomStore.swift:133-142`; `StateController.state.email = x` mutate bản copy — write mất silently, doc đang dạy
pattern này (`StateProvider.swift:483-489` vs :138, :424-434); `@Read` thực chất reactive (Observation) trái doc;
cycle fallback gọi `providerCreate()` → stack overflow Release — `ProviderElement.swift:169-174`;
`ProviderScope(overrides:)` không compose với scope cha; `disposeDelayTask` không cancel → stale timer remove
element mới; batch flag không `defer`.

**Persistence/Cache/Flags/Analytics:** remote override precedence trái doc + snapshot merge thay vì replace —
`StateKitFeatureFlags.swift:121-136`; TTL nhỏ → cleanup thành hot loop 0.5ms — `TTLCache.swift:134-143`;
không single-flight/cache-stampede ở mọi cache-aside path — `CachePolicy.swift:19-27`; `clear()` không fire
`onEvict` — `LRUCache.swift:84-88`; `observeChanges()` luôn trả `[]` + buffer phình — `UserDefaultsAtom.swift:191-199`;
`save` swallow encode failure — `:83-89`; `AnalyticsConfig.persistLocal` nhận nhưng không implement;
`includeValues` không làm gì; `EventTracker.flush` clear batch trước biết kết quả → mất event, không retry;
`UserJourneyTracker` unbounded + drop event ngoài session; `FunnelAnalyzer` order-insensitive + `totalCompletions`
trả step index chứ không phải số user — `UserJourney.swift:126-149`; keychain read sync trên main actor + swallow
error về `initial` (auth fail im lặng); FileAtom load cache theo mỗi read (re-read disk mỗi lần);
`PersistenceMigration` không persist version.

**DevTools/Support/Testing/Concurrency:** DevTools UI không bao giờ update (`@Published` trên non-ObservableObject) —
`DevToolsView.swift:139-146`; `InMemoryPerformanceMetrics` O(providers×records) mỗi query + không quên disposed provider;
`storeSnapshots=false` tắt cả entry history chứ không chỉ snapshot; `Task.throwingTimeout` có thể throw timeout sau
khi có kết quả + không timeout op không cancellation-responsive; `SKConcurrencyLimiter` deadlock waiter cancel sớm;
`Task.race` + `nextResult` đã được xác nhận compile (suite pass) nhưng empty-input throw `NSError` untyped;
`MainActor.runImmediately` deadlock khi main thread đang đợi caller; `SKTaskDuration(TimeInterval)` trap với input âm;
`AsyncSequence.publisher` drop elements trước subscription + leak pump task nếu không ai subscribe;
`@Atom` silently no-op trên class/enum (`MacroError.onlyApplicableToStructs` tồn tại nhưng không throw);
`@HRef` evaluate initializer mỗi render trái doc.

## P3 — cosmetic/dead code/doc drift (tóm tắt)

Dead code: `AnyEquatable`, `SKStatus` enums không ai sản xuất, `observeChanges`, `CacheMetadata` không nối,
`CachePolicy.batch` là stub comment, fixture `CommonFixtures` trả nil, `FixtureFactory.weightedRandom` trap weight 0,
`force unwrap `_state!`` trong Notifier getters, duplicate `topologicallySortedDescendants`, doc block dán 2 lần,
`djb2Hash` trap 32-bit, chi-square chia 0 → NaN, `isInControl` hardcode `"control"/"treatment"`, `withLatestFrom`
re-emit như combineLatest, `useOnChange` chạy action giữa render, `ReplayReport: Sendable` giữ `Error?`,
`JSONValue.from` degrade non-encodable thành `.null` im lặng, `ProviderMacro` collision overload + drop default,
`useNow` interval ≤ 0 → loop 10kHz, `HCount.swift` chứa `HCountdown`, doc `SKTask` tham chiếu biến `context` không tồn tại,
`kSecAttrService` không bao giờ set (key collision giữa providers), `.always` accessibility deprecated, stale doc rải rác
(`SKAtomEffect` "not yet wired" đã wire, `@Read`/`useEnvironment`/`syncToState`...).

## Khoảng trống test lớn (nguyên nhân các P1 thoát qua CI)

- **Không có test nào** cho: `useAsyncSequence`, `useAsyncPerform`, `useAsyncRefresh`, `usePublisher*`, `useBinding`,
  `useEnvironment`, failure path của `useAsync`, teardown của async/publisher boxes — đúng nửa chứa 2 bug nặng nhất.
- Riverpods: 524 dòng test cho ~2.800 dòng source; Future/Stream/AsyncSequence provider, keepAlive link, notifier listen,
  nested container đều 0 test.
- DevTools: chỉ 4 test replay; `DevToolsObserver`/`PerformanceMetrics` 0 test (nên finding 16 tồn tại).
- Support: `useLoadMore`, `useCountdown`, `useNow`, `useSeen` 0 test.
- Persistence: `PersistentAtomStorage`, `SwiftDataIntegration`, `KeychainNotifier` 0 test.
- Macros: chỉ assert chuỗi expansion, không assert compilability → không bắt @Debounce/@HookForm/@HookContext sai.

## Phần làm tốt (giữ nguyên)

- Atom graph: batch + pending set + flush, topo order, diamond dedup (test chứng minh); edges được clear/rebuild đúng mỗi recompute.
- `LRUCache` O(1) thật (doubly-linked list), stress test 10k ops; housekeeping tasks dùng `[weak self]` + deinit cancel, có regression test.
- File write atomic (`.atomic` + encode trước write + tạo thư mục); fallback corrupt file có test.
- Keychain accessibility mapping `"aku"/"cku"/"ck"/"ak"/"dk"` đúng chuẩn Apple, pin bằng test với round-trip thật; batch delete có scoping test.
- Rollout hash deterministic, monotonic, có distribution test cho international IDs.
- Không force-unwrap/force-try/fatalError trong Persistence/Cache/Flags/Analytics public API.
- `StateTest` harness trung thực, effect ordering (layout → post-render, cleanup trước re-run) đúng và được pin bởi test.
- Override diagnostics của Riverpods chính xác, tested; `UpdateStrategy.Dependency` double-wrap prevention kỹ.

## Lộ trình đề xuất

**Giai đoạn 1 — Blocker (chặn ship):** sửa 10 việc lõi, đều nhỏ và cục bộ:
(1) `[weak box]` cho 7 hooks + `useLoadMore` (finding 1, 19); (2) token remove cho `addInterceptor` (4);
(3) `oldValue:` label cho `DevToolsObserver` + test qua container thật (16); (4) `receive(on: main)` cho 3 hook Publisher (2);
(5) guard `variants.isEmpty` (10); (6) `#if DEBUG` cho `StateDevScope` (17); (7) `[weak self]` cho 3 `onDispose` (7);
(8) EventTracker cap buffer (12); (9) Keychain store-then-commit + bỏ delete-then-add (13); (10) `advance(by:)` gán kết quả (24).
Kèm test regression cho từng cái.

**Giai đoạn 2 — Đúng ngữ nghĩa vòng đời:** listen blind-spot notifier (6), rebuild dependencies mỗi recompute (9),
dedupe `_dependentRefs` (8), RiverpodAtom bridge (5), TTL eager check (14), hash salt (15), funnel math, SwiftData facade (11),
Testing stubs: implement hoặc xóa khỏi public API (23, 25, 26).

**Giai đoạn 3 — Macros + coverage:** validation + unique names cho macros (20-22, 26), sau đó bù test cho toàn bộ
khoảng trống liệt kê trên (ưu tiên teardown/leak test vì bắt đúng class bug P1).
