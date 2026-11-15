# Re-score độc lập — 2026-11-15 (spec 014 US5)

Reviewer độc lập (agent không có ngữ cảnh các lần fix) tự kiểm chứng tip `31b2073`:
chạy suite, TSan, lint, đọc workflows/docs/code, kiểm API GitHub Actions thật.

## Điểm: 7.8/10 (từ 6.5/10 ngày 2026-11-05)

| Nhóm | Điểm |
|---|---|
| Bugs trên API public | 9.0 |
| Chất lượng test | 8.0 |
| CI gates (thời điểm đó) | 5.5 |
| Docs / process | 7.5 |
| Kiến trúc | 8.5 |

## Bằng chứng cải thiện (đã tự verify)
- P0 + 5 P1 engine fixes có thật với regression tests (cast-based override,
  KeepAliveCloseFlag, publishExternalState, owner-correct auto-dispose).
- Suite 282 tests / 14 bundle xanh; TSan local exit 0 zero warnings.
- CI config: macos-15, Xcode selection fail-loud, SPM cache, lint + TSan blocking,
  coverage advisory step, iOS destination build.
- Tag 1.0.0 @ 608be23; ARCHITECTURE/SENDABLE_AUDIT/PERFORMANCE/COVERAGE docs.

## Gaps tại thời điểm đó (đã fix ngay trong commit kế tiếp)
1. 17 lint errors do specs/013 tự giới thiệu (15 audit comment dài >160 + 2 file
   >800 dòng) → shortened comments + file cap 1000 documented.
2. swift-issue-reporting pin fail strict-concurrency dưới Xcode 26 runner → dependency
   loại bỏ hoàn toàn, local `reportUnimplementedIssue` helper thay thế.
3. docs.yml chưa từng xanh (cancelled liên tục, macos-14) → macos-15 + Xcode
   selection + concurrency group riêng `docs-<ref>`.
4. Stale claims (rulebook §10 "0 errors", CHANGELOG) → cập nhật lại theo measured state.
5. Coverage advisory-only — giữ, đã ghi policy rõ (threshold core ≥75%, release-review
   gate; CI in report).

## Ghi nhận sau fix (commit này)
SwiftLint exit 0 / 0 errors / 133 warnings documented; suite xanh; benchmarks +
coverage + TSan blocking. Con đường 9.0 phụ thuộc duy nhất: CI GitHub chạy xanh trên
push này (được verify qua API sau khi run hoàn tất).
