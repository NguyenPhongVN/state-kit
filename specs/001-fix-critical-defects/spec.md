# Feature Specification: Fix Critical Defects Found in Code Review

**Feature Branch**: `fix-critical-defects`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "Fix critical defects found in code review of StateKit: (1) memory leak in TimeToLiveCache, SlidingWindowTTLCache and EventTracker — background cleanup/auto-flush tasks capture self strongly in an infinite loop and are only cancelled in deinit, so deinit never runs; (2) KeychainStateProvider.deleteAll(matching:) ignores its pattern parameter and deletes ALL generic-password keychain items (data loss risk); (3) KeychainAccessibility raw values are invalid for kSecAttrAccessible — store fails or mis-sets the attribute on device; plus medium fixes: djb2Hash maps all non-ASCII characters to 0 causing A/B bucket skew, EventTracker.events grows unbounded, README says 47 public macros but actual count is 48."

## Clarifications

### Session 2026-09-24

- Q: Khi gọi deleteAll(matching:) trên KeychainBatch, pattern nên khớp key theo kiểu nào? → A: Prefix match — key bắt đầu bằng pattern được xóa; nil/empty pattern = tất cả item của batch.
- Q: EventTracker nên giới hạn lịch sử events giữ trong memory (in-session) ở mức bao nhiêu events làm mặc định? → A: Không cap — giữ hành vi hiện tại (lịch sử đầy đủ); việc giới hạn memory là trách nhiệm của host app và nằm ngoài scope feature này.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Scoped keychain deletion stops wiping unrelated secrets (Priority: P1)

An app developer uses the keychain batch helper to clean up temporary cache entries they stored (keys like `cache_avatar_…`). Today, calling the batch delete — even when passing a narrowing pattern — silently erases **every** generic-password item the app owns in the keychain, including authentication tokens and stored credentials. After the fix, a pattern-scoped delete touches only the items that match, and a full batch delete touches only items this helper previously stored. A developer can run cleanup routines without risking users' login state.

**Why this priority**: Irreversible data loss affecting real users' credentials is the highest-severity defect in the set; everything else is correctness or resource hygiene.

**Independent Test**: Store a mix of batch items (`cache_*`) and non-batch secret items, run a pattern-scoped delete, then verify the non-matching items still exist and the matching ones are gone. Delivers: cleanup without collateral destruction.

**Acceptance Scenarios**:

1. **Given** a batch holding three keys prefixed `cache_` and one key `auth_token`, **When** the caller deletes with pattern `cache_`, **Then** the three cache entries are removed and `auth_token` still retrieves successfully.
2. **Given** keychain items that were NOT created through the batch helper, **When** any batch delete runs (with or without a pattern), **Then** those foreign items are untouched.
3. **Given** a batch with items whose keys do not match the provided pattern, **When** the pattern-scoped delete runs, **Then** no items are removed and the operation completes without error.

---

### User Story 2 - Keychain values persist with a valid protection level (Priority: P1)

An app stores an auth token through the keychain-backed state provider with a chosen accessibility level (for example, "available after first unlock"). Today the protection attribute is written using an invented attribute string the platform does not recognize, so saving fails on device or the item ends up with an unintended protection level — breaking login persistence in the field. After the fix, every accessibility level the API exposes maps to the platform's corresponding official protection constant, and a store/retrieve/delete round-trip succeeds for each of them.

**Why this priority**: The primary purpose of this module — securely persisting sensitive state — does not work reliably on real devices, which makes every downstream feature built on it untrustworthy.

**Independent Test**: For each exposed accessibility level, perform a store → retrieve → delete round-trip and verify the value survives and the item carries the corresponding official protection attribute. Delivers: trustworthy persistence of sensitive state.

**Acceptance Scenarios**:

1. **Given** any of the five exposed accessibility levels, **When** a value is stored and then retrieved, **Then** the retrieved value equals the stored value.
2. **Given** a stored item, **When** it is inspected, **Then** its protection attribute equals the platform constant corresponding to the level the caller chose (never an unrecognized string).
3. **Given** an item already exists for a key, **When** the caller stores a new value for that key, **Then** the update succeeds and preserves the chosen accessibility level.

---

### User Story 3 - Cache and tracker instances actually deallocate (Priority: P1)

An app creates short-lived caches or an analytics tracker per screen/session and expects them to be released when done. Today each instance starts an internal repeating housekeeping loop that holds on to the instance forever: the instance is never released, and the loop keeps waking the CPU for the rest of the process lifetime — once per created instance. After the fix, releasing the last reference to an instance also stops its housekeeping loop, so memory returns to the system and no orphan wakeups remain.

**Why this priority**: Silent unbounded resource growth in long-running apps; every user of the affected types leaks, whether they know it or not.

**Independent Test**: Create many instances of each affected type in a scoped block, let the block end, and assert that all instances have been released and their loops stopped. Delivers: predictable memory and energy behavior for all consumers.

**Acceptance Scenarios**:

1. **Given** 100 TTL-cache instances created and then abandoned, **When** the run loop settles, **Then** all 100 have been deallocated.
2. **Given** a tracker instance abandoned after tracking events, **When** the run loop settles, **Then** the instance is deallocated and no further automatic flushes occur.
3. **Given** an instance that is actively being used (strongly referenced), **When** its housekeeping interval elapses, **Then** the housekeeping work still runs normally (fix must not break the live-instance behavior).

---

### User Story 4 - Rollout bucketing is fair for international user IDs (Priority: P2)

A product team rolls a feature out to 10% of users, identified by IDs containing non-Latin characters (e.g., Vietnamese display names/emails). Today every non-ASCII character contributes nothing to the bucketing value, so many distinct international IDs collapse onto the same bucket — the effective rollout percentage deviates wildly from the configured one for those users, and A/B experiments become skewed. After the fix, bucketing uses the full character content of the ID regardless of script, distinct IDs distribute across buckets, and each individual user's assignment stays stable over time.

**Why this priority**: Correctness of experimentation/rollout for a large share of the world's users, but no data loss and no crash.

**Independent Test**: Bucket a large set of distinct non-ASCII IDs at a given percentage and verify the enabled share is within a small tolerance of the configured percentage, then re-run and verify each ID keeps its original assignment. Delivers: trustworthy gradual rollouts worldwide.

**Acceptance Scenarios**:

1. **Given** 10,000 distinct user IDs containing non-ASCII characters and a 10% rollout, **When** eligibility is evaluated, **Then** between roughly 9% and 11% of the IDs are enabled.
2. **Given** a specific user ID, **When** eligibility is evaluated repeatedly across sessions, **Then** the answer never changes for the same rollout configuration.
3. **Given** two different user IDs, **When** both are evaluated, **Then** they are not systematically forced into the same bucket merely because their characters are non-ASCII.

---

### User Story 5 - Documentation matches the shipped API surface (Priority: P3)

A new adopter reads the project README to evaluate the toolkit and sees an exact count of public macros. The count is off by one versus what the package actually exposes, undermining trust in the docs. After the fix, every stated count matches reality.

**Why this priority**: Small credibility fix, zero runtime impact.

**Independent Test**: Count the public macro declarations in the package and compare with the number stated in the README — they must be equal.

**Acceptance Scenarios**:

1. **Given** the README's stated macro count, **When** the actual public macro declarations are counted, **Then** the two numbers are identical.

### Edge Cases

- What happens when the keychain delete pattern is an empty string or nil? (Must be well-defined: nil/empty means "all items belonging to this batch", never "everything in the keychain".)
- What happens when the keychain store is called twice with different accessibility levels for the same key? (The last write wins and the item ends up with the latest chosen level.)
- What happens when a cache's TTL is extremely small (sub-millisecond) or extremely large (hours)? (Housekeeping interval derivation must remain valid, never zero/negative, and must not busy-loop.)
- What happens when an instance's housekeeping loop is stopped mid-sleep during release? (No crash, no orphan continuation, no post-deinit callbacks.)
- What happens when the same user ID is hashed but the rollout percentage changes from 5% to 50%? (Users already enabled at 5% must remain enabled at 50% — monotonic bucketing.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-01**: Releasing the last reference to any cache or tracker instance that runs an internal housekeeping loop MUST terminate that loop; after release the instance MUST be deallocated and MUST NOT continue waking the process.
- **FR-02**: Housekeeping behavior for a live (strongly referenced) instance MUST be unchanged: cleanup/flush still runs at the configured interval.
- **FR-03**: Pattern-scoped keychain batch deletion MUST remove only items whose keys match the pattern (prefix match) AND belong to the batch; all other items MUST remain untouched.
- **FR-04**: A batch delete without a pattern MUST remove only items belonging to that batch — it MUST NEVER delete keychain items the batch did not store.
- **FR-05**: Every exposed keychain accessibility level MUST map to the corresponding official platform protection constant, and store/update operations MUST apply that constant.
- **FR-06**: Storing a value for an existing key MUST succeed (update path) and MUST preserve/reapply the caller-chosen accessibility level.
- **FR-07**: Rollout bucketing MUST derive the bucket from the complete user ID content (all characters, any script), MUST be deterministic (same ID + same configuration ⇒ same result), and MUST be monotonic with respect to percentage (enabled at X% ⇒ enabled at any Y% > X%).
- **FR-08**: Distinct user IDs MUST NOT be forced into identical buckets due solely to containing non-ASCII characters.
- **FR-09**: All stated documentation counts (public macros) MUST equal the actual counts in the shipped package.
- **FR-10**: All existing public APIs MUST keep their current signatures (fixes are behavior-level; no breaking signature changes). Changing the keychain accessibility raw values is accepted as a bug fix, documented in the changelog.

### Key Entities *(include if feature involves data)*

- **KeychainAccessibility**: Exposed protection levels for keychain items; each maps 1:1 to an official platform protection constant.
- **KeychainBatch**: An in-memory collection of key→value items destined for the keychain; the scope boundary for batch deletes.
- **TimeToLiveCache / SlidingWindowTTLCache**: Cache instances owning a periodic expiry-cleanup loop whose lifetime is tied to the instance.
- **EventTracker**: Analytics event collector owning a periodic auto-flush loop; retains full in-session history by explicit product decision (see Clarifications) — memory management is the host's responsibility.
- **Rollout bucket value**: The deterministic per-user derived value that decides eligibility; must reflect the full user ID.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-01**: Creating and abandoning 1,000 instances of each affected cache/tracker type leaves 0 live instances afterward (verified by release assertions in automated tests).
- **SC-02**: After the last affected instance is released, the module contributes 0 periodic wakeups to the process (verified by housekeeping-loop termination tests).
- **SC-03**: Pattern-scoped keychain delete affects exactly the matching batch items — 0 non-matching or foreign items touched (verified by before/after keychain content checks in tests).
- **SC-04**: A store→retrieve round-trip succeeds for 5/5 exposed accessibility levels, and the stored item's protection attribute equals the corresponding official constant in each case.
- **SC-05**: Bucketing 10,000 distinct non-ASCII user IDs at a 10% rollout enables between 9% and 11% of them; re-evaluation is 100% stable per ID; users enabled at 5% remain enabled at 50% (100% monotonic).
- **SC-06**: Stated macro count in the README equals the actual public macro count; the full automated test suite passes with no regressions.

## Assumptions

- Pattern matching in keychain batch delete is a **prefix** match on the stored key (matches the motivating example `cache_`); nil or empty pattern means "all items belonging to this batch".
- "Foreign" keychain items (created outside the batch helper) are out of deletion scope by definition of the fix; no attempt is made to enumerate or protect items by other heuristics.
- Changing `KeychainAccessibility` raw values is acceptable: items written by previous builds either failed to store (on strict platforms) or used unintended protection, so there is no meaningful migration path; the change is documented as a behavior fix.
- Bucket assignments under the fixed hashing WILL change for some users compared to the biased scheme; this is accepted as part of the bug fix (one-time re-bucketing), documented in the changelog.
- Out of scope (decided in clarification session 2026-09-24): bounding the analytics tracker's in-session history. The tracker keeps full history; hosts needing bounded memory must use the existing explicit clear/flush APIs themselves.
- README macro count is updated to the verified number (48 today); if macros are added later the count must be re-verified as part of the docs workflow.
- Automated tests run on the host (macOS) where keychain access is available in the test runner; on-device protection-attribute verification is covered by the constant mapping being direct.
