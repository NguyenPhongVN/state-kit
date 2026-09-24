# Data Model: DX Essentials

Feature: specs/006-dx-essentials · Date: 2026-09-25

## SKFocusAtom<Base, Field> (StateKitAtoms)
- Stored: `base: Base`, `keyPath: WritableKeyPath<Base.Value, Field>`. No value copy.
- Read: `value(context:) = context.watch(base)[keyPath: keyPath]` (SKValueAtom).
- Write: `store.setStateValue(fieldValue, for: focus)` → redirected via `SKFocusWriting`
  into `base.value[keyPath:] = fieldValue` + `setStateValue(newBase, for: base)`.
- Identity: hash/== over `(base identity, keyPath)`.

## FileAtomStorage<T> (StateKitPersistence)
- `init(directory: URL, fileName override?)`; file = `directory/T.fileName`.
- `load() -> T`: decode file → value; missing/corrupt → `T.defaultValue`.
- `save(_:)`: encode + write (creating the directory if needed).
- `delete()`, `addObserver(_:)` — mirror `PersistentAtomStorage`.

## ErrorBoundary (StateKitUI)
- `init(onError: ((Error) -> Void)? = nil, content: () throws -> Content, fallback: (Error) -> Fallback)`.
- Body evaluates content per render inside do/catch.

## docs.yml workflow
- push to main → xcodebuild docbuild → upload-pages-artifact → deploy-pages.
