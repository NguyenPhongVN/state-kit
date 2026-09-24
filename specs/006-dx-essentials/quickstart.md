# Quickstart: Verify DX Essentials

Feature: specs/006-dx-essentials · Date: 2026-09-25

## 1. Gates

```bash
swift build && swift test && (cd Examples && swift build)
```

## 2. focusAtom (SC-02)

Tests in `Tests/StateKitAtomsTests/SKFocusAtomTests.swift`:
- write through focus → base updated with exactly one field changed;
- base dependents notified (a derived atom over the base recomputes);
- external base change → focus read reflects it; focus box has no stale copy.

## 3. fileAtom (SC-03)

Tests in `Tests/StateKitPersistenceTests/FileAtomTests.swift` (temporary directory):
- save → new storage instance loads the same value;
- missing file → default; corrupt file → default, and save repairs it.

## 4. ErrorBoundary (SC-04)

Tests in `Tests/StateKitUITests/ErrorBoundaryTests.swift`:
- throwing content → fallback rendered with error + onError fired;
- clean content → rendered, onError not fired;
- throwing fallback → error propagates.

## 5. DocC (SC-01)

After push: `docs.yml` runs on main and publishes Pages. Local command (rulebook §8):

```bash
xcodebuild docbuild -scheme StateKit -destination 'generic/platform=macOS' DOCC_HTML_DIR=docs
```
