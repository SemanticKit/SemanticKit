# Swift 6.4 language reference for SemanticKit

Target: **Swift 6.4** (current patch 6.4.2 per swift.org; pewter's SDK `Swift.swiftinterface` header reads `swiftlang-6.4.2.1.9`, per RDFKit `CLAUDE.md` on wp/step-1), macOS 27. Built on 2026-10-31 from the web only, not from model memory. Every item cites its source. If an item here disagrees with what you remember, this file wins; if it disagrees with the installed toolchain's `.swiftinterface` files, the toolchain wins and this file must be fixed.

## Sources read

- swiftlang/swift `CHANGELOG.md`, sections "Swift 6.4", "Swift 6.3", "Swift 6.2": https://github.com/swiftlang/swift/blob/main/CHANGELOG.md
- swift-evolution proposals, status lines read from https://github.com/swiftlang/swift-evolution/tree/main/proposals
- "Swift 6.4 Released" (Joe Heck, Holly Borla, 2026-09-15): https://www.swift.org/blog/swift-6.4-released/
- The Swift Programming Language, revision history (2026-09-14 "Updated for Swift 6.4"; 2026-03-23 "Updated for Swift 6.3"): https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/RevisionHistory/RevisionHistory.md, rendered at https://docs.swift.org/swift-book/

## Rules for anyone writing Swift here

1. Before writing or changing Swift, read this file. For any API you use, check the 6.4 toolchain's `.swiftinterface` (stdlib, `_Concurrency`, `Containers`, Foundation) on pewter, not memory.
2. Lifetime annotations are still **underscored**: `@_lifetime(...)`. There is no accepted `@lifetime` attribute in 6.4. Stdlib signatures in the proposals below use `@_lifetime`.
3. Do not use features that are only **Accepted** (not Implemented) unless the toolchain proves they exist. See "Not in 6.4" at the end.
4. Swift 6 language mode is the current mode. `NonisolatedNonsendingByDefault` is an *upcoming feature*, so the meaning of a plain `nonisolated async func` depends on the target's settings. Generated code must spell the isolation it wants (`nonisolated(nonsending)` or `@concurrent`) instead of relying on the default.

---

## 1. Concurrency and isolation

### Global and static variables (in force since 5.10 / Swift 6 mode)
- Under strict concurrency (Swift 6 mode) **every global or static variable must be either isolated to a global actor, or be immutable (`let`) and of `Sendable` type.** Top-level variables in `main.swift`/scripts are implicitly `@MainActor`. Opt-out: `nonisolated(unsafe) var`. Lazy initialization of globals is already thread-safe. [SE-0412](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0412-strict-concurrency-for-global-variables.md)
- Consequence for a generator: emitted vocabulary constants must be `static let` of a `Sendable` type, or isolated. A `static var` cache is an error.

### Default actor isolation per module (6.2)
- A module or target can make unannotated code `@MainActor` by default: compiler flag `-default-isolation MainActor`, SwiftPM `swiftSettings: [.defaultIsolation(MainActor.self)]`. Default is still nonisolated unless the target opts in. Imported modules are unaffected. [SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md)
- Consequence: generated code is compiled inside the *consumer's* module. If a consumer sets `MainActor` default isolation, unannotated generated types become `@MainActor`. Library-style generated types that must be usable anywhere should say `nonisolated` explicitly on the type. [SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md), [SE-0449](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0449-nonisolated-for-global-actor-cutoff.md)

### `nonisolated` to stop global-actor inference (6.1)
- `nonisolated` may be written on types and extensions (and stored properties) to prevent global actor inference from conformances/superclasses. [SE-0449](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0449-nonisolated-for-global-actor-cutoff.md)

### nonisolated async functions: `nonisolated(nonsending)` and `@concurrent` (6.2)
- `nonisolated(nonsending)`: the async function runs on the **caller's** actor; arguments and results are not sent across an isolation boundary. `@concurrent`: always switches off the actor (the old SE-0338 behavior).
- Without the upcoming feature `NonisolatedNonsendingByDefault`, a plain `nonisolated async` function is `@concurrent`. With it enabled, the default becomes `nonisolated(nonsending)`. This applies to function values too. [SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)

### Isolated conformances (6.2)
- `@MainActor class T: @MainActor P {}` — a conformance can be isolated to a global actor and is only usable on that actor; using it from nonisolated generic code is an error. [SE-0470](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md)

### Isolated deinit (6.2)
- Actor and global-actor-isolated classes can declare `isolated deinit`, which runs on the actor. [SE-0371](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0371-isolated-synchronous-deinit.md)

### `~Sendable` (6.4)
- `struct/enum/class T: ~Sendable` explicitly suppresses `Sendable` inference and marks the type non-Sendable. Only for type declarations (generic parameters are already non-Sendable unless constrained). A subclass of a `~Sendable` class may declare `@unchecked Sendable`. Purely additive. [SE-0518](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0518-tilde-sendable.md)

### Sendable inference and regions (Swift 6.0, still the rules)
- Region-based isolation: non-Sendable values can be passed across isolation if the compiler proves the region is disconnected. [SE-0414](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md)
- `sending` parameters and results. [SE-0430](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md)
- Methods and key-path literals infer `Sendable`. [SE-0418](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0418-inferring-sendable-for-methods.md)
- `@isolated(any)` function types. [SE-0431](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0431-isolated-any-functions.md)
- Usability of global-actor-isolated types (Sendable inference for them, `nonisolated` stored `let`s). [SE-0434](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0434-global-actor-isolated-types-usability.md)
- Inheritance of caller isolation via `isolated` parameters / `#isolation`. [SE-0420](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md)

### Tasks (6.2–6.4)
- `Task.immediate` and `addImmediateTask`: start synchronously in the caller's context. [SE-0472](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0472-task-start-synchronously-on-caller-context.md)
- Task names: `Task("name") { … }`. [SE-0469](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0469-task-names.md)
- Priority escalation APIs. [SE-0462](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0462-task-priority-escalation-apis.md)
- **6.4:** throwing unstructured task initializers (`Task.init`, `Task.immediate`, `Task.detached`) use typed throws, and an unused throwing `Task { try … }` now warns (`#NoUseUnstructuredThrowingTask`). Silence with `_ = Task { … }`. [SE-0520](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0520-discardableresult-task-initializers.md)
- **6.4:** `withTaskCancellationShield { … }` (sync and `nonisolated(nonsending)` async overloads, typed throws) hides cancellation inside the scope and stops it propagating to child tasks created inside. [SE-0504](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0504-task-cancellation-shields.md)
- **6.4:** `defer { await … }` is allowed in async contexts; the defer body has the isolation of its enclosing scope and is awaited at scope exit. [SE-0493](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0493-defer-async.md)
- **6.4:** `Continuation<Success: ~Copyable, Failure: Error>`, a noncopyable continuation; `resume` is `consuming` (double resume is a compile error), dropping it unresumed traps at runtime. With `withContinuation`. [SE-0528](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0528-noncopyable-continuation.md)
- **6.4:** async overload of `Result.init(catching:)`. [SE-0530](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0530-async-result-support.md)
- **6.4:** `UnownedTaskExecutor: Hashable`. [SE-0523](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0523-hashable-unownedtask-executor.md)

---

## 2. Ownership: `~Copyable`, `~Escapable`, borrowing, consuming

### Base rules (6.0–6.2, still in force)
- Noncopyable generics: generic parameters, protocols and extensions default to `Copyable` and `Escapable`; write `~Copyable` / `~Escapable` to suppress. Extensions that don't restate the suppression assume `Copyable`. [SE-0427](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
- `borrowing`/`consuming` pattern matching (`switch` over noncopyable values). [SE-0432](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md)
- Noncopyable stdlib primitives (`Optional`, `Result`, `MemoryLayout`, unsafe pointers with `~Copyable` pointees). [SE-0437](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md)
- Nonescapable types (`~Escapable`). [SE-0446](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md); stdlib primitives for them [SE-0465](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md).

### 6.4 changes
- **Equatable, Comparable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, TextOutputStream(able)** now refine `~Copyable, ~Escapable`; their requirements take `borrowing Self`. `LosslessStringConvertible` refines `~Copyable` only. `Optional` and `Result` `Equatable`/`Hashable` conformances accept noncopyable payloads. `String(describing:)` and string interpolation accept `borrowing` noncopyable values. Source compatible. [SE-0499](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md)
- **Associated types can suppress `Copyable`/`Escapable`:** `associatedtype Element: ~Copyable`. Defaulting: in a `T: P` constraint or a protocol extension, `Copyable` is re-assumed only for `Self` and for *primary* associated types (those in `<…>`), not for ordinary associated types. Changing an existing ordinary associated type to `~Copyable` is source-breaking for clients. Replaces the experimental `SuppressedAssociatedTypes`, which is now deprecated and incompatible. [SE-0503](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md)
- **`borrow` and `mutate` accessors:** computed properties and subscripts can expose stored storage without a copy and without a coroutine: `var x: T { borrow { return _x } mutate { return &_x } }`. They complement `get`/`set`/`yielding borrow`/`yielding mutate`; they cannot return temporaries. [SE-0507](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0507-borrow-accessors.md)
- **`Ref<Value: ~Copyable>`** (Copyable, ~Escapable; `init(_ target: borrowing Value)`; `value { borrow }`) and **`MutableRef<Value: ~Copyable>`** (~Copyable, ~Escapable; `init(_ target: inout Value)`; `value { borrow; mutate }`). Returning them from your own functions needs `@_lifetime`. [SE-0519](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0519-ref-mutableref-types.md)
- **`Optional.ref` / `.mutableRef`**, noncopyable `map`/`flatMap`/`unsafelyUnwrapped`, `put()`. The 6.4 release post lists this as shipped; the evolution dashboard still reads "Accepted". Confirm in the toolchain before use. [SE-0532](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0532-optional-noncopyable-improvements.md), https://www.swift.org/blog/swift-6.4-released/
- **`UniqueBox<Value: ~Copyable>`**: noncopyable unique heap owner, no reference counting. [SE-0517](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0517-uniquebox.md)
- **`RigidArray` and `UniqueArray`** in the new toolchain module **`Containers`** (`import Containers`): noncopyable, uniquely-owned, contiguous arrays that hold noncopyable elements; `UniqueArray` grows geometrically, `RigidArray` has fixed capacity. [SE-0527](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md)
- **`Iterable`** and **`BorrowingIteratorProtocol`**: iteration without copying. `Iterable<Element, Failure>: ~Copyable, ~Escapable`, `associatedtype Element: ~Copyable`, `Failure: Error = Never`, `makeBorrowingIterator()`; the iterator yields `Span<Element>` via `nextSpan(maxCount:)` and has `skip(by:)`. `for x in iterable` works; `for try x in` for throwing ones. Existing `Sequence` conformers can add `Iterable` by declaring it. [SE-0516](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0516-borrowing-sequence.md)
- **Memberwise initializer change:** the implicit memberwise init no longer includes properties *with initial values* that are less accessible than the most accessible property, up to `internal`. So adding `private var cache = …` no longer makes the memberwise init `private`. A compatibility overload keeps old call sites working; a hand-written `init` in an extension with the new signature now collides. [SE-0502](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0502-exclude-private-from-memberwise-init.md)
- Not in 6.4: mutation/consumption inside noncopyable `deinit` [SE-0544](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0544-mutate-or-consume-in-deinit.md) (Accepted only).

### 6.3
- `weak let` is allowed; explicit `[weak x]` captures are now immutable (source-breaking if you assigned to the capture). [SE-0481](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0481-weak-let.md)

---

## 3. Span, InlineArray and memory safety

- `Span<Element>` / `RawSpan` (6.2): safe, non-escapable views over contiguous memory. [SE-0447](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
- `.span` properties on `Array`, `ContiguousArray`, `String.UTF8View`, `InlineArray`, etc. (6.2). [SE-0456](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md)
- `MutableSpan` / `MutableRawSpan` (6.2). [SE-0467](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0467-MutableSpan.md); `OutputSpan` / `OutputRawSpan` (6.2) [SE-0485](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0485-outputspan.md); `extracting()` slicing (6.2) [SE-0488](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0488-extracting.md); `UTF8Span` (6.2) [SE-0464](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0464-utf8span-safe-utf8-processing.md).
- `InlineArray<let count: Int, Element: ~Copyable>` (6.2), built on integer generic parameters (`let N: Int`) [SE-0453](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md), [SE-0452](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0452-integer-generic-parameters.md). Type sugar **`[N of T]`**, e.g. `[3 of Int]`, `[_ of Int]` with inference (6.2). [SE-0483](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0483-inline-array-sugar.md)
- **6.3:** `Span.bytes`, `MutableSpan.mutableBytes` and the generic `OutputRawSpan.append` are now `@unsafe` (padding bytes may be uninitialized). Safe only for element types with no padding. CHANGELOG 6.3 entry.
- **6.4:** safe byte loading for `RawSpan` and friends via two marker protocols, `ConvertibleToBytes` (no padding; conformance only in the type's own module) and `ConvertibleFromBytes: BitwiseCopyable` (every bit pattern valid; outside the stdlib only `@unchecked`). Replaces the unsafe-flagged loads. [SE-0525](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0525-rawspan-safe-loading-api.md)
- **6.4:** `withTemporaryAllocation(of:capacity:)` yielding `inout OutputSpan`, and `withTemporaryAllocation(byteCount:alignment:)` yielding `inout OutputRawSpan`. [SE-0524](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0524-span-temporary-allocation.md)
- **6.4:** `isTriviallyIdentical(to:)` on concrete stdlib types (fast "must be equal" check). [SE-0494](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0494-add-is-identical-methods.md)
- **6.4:** C++20 `std::span` bridges to `Span`. https://www.swift.org/blog/swift-6.4-released/
- Strict memory safety mode (6.2): `-strict-memory-safety`, `unsafe` expressions, `@unsafe`/`@safe`. [SE-0458](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md)

---

## 4. Generics and types

- **6.4:** `some P?` means `(some P)?`, `any P?` means `(any P)?` (any depth, also `!`). `any (P & Q)?` allowed; `any P & Q?` still an error. `any ~Copyable?` parses as `(any ~Copyable)?`. [SE-0521](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0521-improved-optional-opaque-and-any.md)
- **6.4:** suppressed associated types, see section 2. [SE-0503](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md)
- **6.4:** trailing closures after array/dictionary type literals: `[String] { "a" }`, `[String: Int] { … }`. [SE-0508](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0508-array-expression-trailing-closures.md)
- **6.4:** `Hashable` for `Dictionary.Keys`, `EmptyCollection`; conditional `Equatable`/`Hashable` for `CollectionOfOne`. A redundant conformance you wrote now warns. [SE-0514](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0514-hashable-conformance-for-dictionarykeys-collectionofone-emptycollection.md)
- **6.4:** forward references to local variables are rejected consistently inside closures too; shadowing inside closures now matches outside (`let x: Int = { x }()` refers to `self.x`). CHANGELOG 6.4 entry.
- **6.3:** `@specialized(where T == X)` explicit specialization. [SE-0460](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0460-specialized.md)
- **6.3:** module selectors `Module::Name`, e.g. `SwiftUI::View`, `"…".Foundation::data(using:)`. Lookup starts at the module's top level, so locals and generic parameters can't be selected. 6.4 uses module selectors in `.swiftinterface` files by default under library evolution. [SE-0491](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0491-module-selectors.md), CHANGELOG 6.3/6.4.
- **6.3:** `Swift.Task`, `Swift.Regex` work (the `_Concurrency`/`_StringProcessing` names still work). CHANGELOG 6.3.
- 6.2: raw identifiers `` `with spaces` `` [SE-0451](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0451-escaped-identifiers.md); `enumerated()` is a `Collection` [SE-0459](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0459-enumerated-collection.md); default values in string interpolation `"\(x, default: "none")"` [SE-0477](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0477-default-interpolation-values.md).
- 6.0: typed throws `throws(E)` [SE-0413](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md); access-level imports `internal import M` [SE-0409](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md). 6.1: member import visibility (`MemberImportVisibility` upcoming feature) [SE-0444](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md).

## 5. Attributes, macros and diagnostics

- **6.4:** `@diagnose(Group, as: error|warning|ignored, reason: "…")` controls a warning group within a declaration's lexical scope, relative to its enclosing scope. [SE-0522](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0522-source-warning-control.md)
- **6.4:** `@available(anyAppleOS 26.0, *)` and `#available(anyAppleOS 26.0, *)` cover macOS/iOS/tvOS/watchOS/visionOS 26+; a specific platform listed alongside wins. CHANGELOG 6.4.
- **6.3:** `@c` for C-callable global functions and C enums, `@objc` on global functions, `@c @implementation` (replaces `@_cdecl`). [SE-0495](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0495-cdecl.md)
- **6.3:** `@inline(always)` (errors if a direct reference can't be inlined). [SE-0496](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0496-inline-always.md)
- **6.3:** `@export(interface)` / `@export(implementation)` (subsumes `@_alwaysEmitIntoClient`/`@_neverEmitIntoClient`; not combinable with `@inlinable`/`@usableFromInline`). [SE-0497](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0497-definition-visibility.md)
- **6.3:** `@section("…")` and `@used` on globals with constant initializers. [SE-0492](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0492-section-control.md)
- 6.2: `@abi(...)` [SE-0476](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0476-abi-attr.md).
- Macros: TSPL 6.4 adds documentation for **body macros** in Attributes → attached. https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/RevisionHistory/RevisionHistory.md . A proposal to let macros grant `self` access in property initializers was returned for revision, so it is not available. [SE-0539](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0539-self-access-for-property-initializers.md)

## 6. Standard library and toolchain libraries

- Codable: `EncodingError`/`DecodingError` print readable descriptions with a dotted coding path (6.3). [SE-0489](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0489-codable-error-printing.md)
- Clock epochs on `SuspendingClock` / `ContinuousClock` (6.3). [SE-0473](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0473-clock-epochs.md)
- Observation: `Observations` async sequence (6.2) [SE-0475](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0475-observed.md); 6.4 adds options to `withObservationTracking` and a continuous variant [SE-0506](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0506-advanced-observation-tracking.md).
- `Runtime` module: backtraces (6.2) [SE-0419](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0419-backtrace-api.md); `demangle(_:)` (6.4) [SE-0498](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0498-runtime-demangle.md).
- `Containers` module (6.4), see section 2. [SE-0527](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md)
- Subprocess 1.0; Swift Testing: `XCTAssert` inside Swift Testing and `#expect` inside XCTest (ST-0021), `CustomTestReflectable` (ST-0022), repeat tests (ST-0024). https://www.swift.org/blog/swift-6.4-released/

## 7. SwiftPM and build (6.4)

- Swift Build is SwiftPM's default build system. https://www.swift.org/blog/swift-6.4-released/
- SBOM generation (SPDX / CycloneDX). [SE-0509](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0509-swift-sboms-via-swiftpm.md)
- `swift package add-target-plugin`. [SE-0511](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0511-swiftpm-add-target-plugin.md)
- Per-target warning control `.treatWarning("Group", as: .warning)` (6.2). [SE-0480](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0480-swiftpm-warning-control.md)
- Migration tooling for upcoming features (`swift package migrate`) (6.2). [SE-0486](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0486-adoption-tooling-for-swift-features.md)

---

## Items that matter most to the SemanticKit code generator

1. Emitted constants: `static let` of a `Sendable` type, never `static var`. [SE-0412](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0412-strict-concurrency-for-global-variables.md)
2. Mark library-style generated types `nonisolated` so a consumer's `defaultIsolation(MainActor.self)` doesn't turn them `@MainActor`. [SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md), [SE-0449](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0449-nonisolated-for-global-actor-cutoff.md)
3. Spell async isolation explicitly (`nonisolated(nonsending)` or `@concurrent`); the default depends on `NonisolatedNonsendingByDefault`. [SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)
4. Use `~Sendable` to state an audited non-Sendable type instead of omitting `Sendable`. [SE-0518](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0518-tilde-sendable.md)
5. Implicit memberwise inits now skip less-visible properties that have initial values. Generated `init`s in extensions can collide with the synthesized one. [SE-0502](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0502-exclude-private-from-memberwise-init.md)
6. `Equatable`/`Hashable`/`Comparable`/`CustomStringConvertible` take `borrowing Self` and accept `~Copyable`/`~Escapable` conformers. Generated `==`/`hash(into:)` must match. [SE-0499](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md)
7. Protocols generated from OWL classes can declare `associatedtype X: ~Copyable`; only primary associated types get `Copyable` re-assumed. [SE-0503](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md)
8. Use `borrow`/`mutate` accessors to expose stored values without copies. [SE-0507](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0507-borrow-accessors.md)
9. Iterate generator indexes with `Iterable`/`Span`, not `filter → map → Set` copies; `UniqueArray` (import `Containers`) for noncopyable element storage. [SE-0516](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0516-borrowing-sequence.md), [SE-0527](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md), [SE-0447](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
10. `some P?` / `any P?` without parentheses. [SE-0521](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0521-improved-optional-opaque-and-any.md)
11. Module selectors `RDFKit::Thing` when a generated name collides with an imported one, e.g. a vocabulary term named like a stdlib or Foundation type. [SE-0491](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0491-module-selectors.md)
12. Lifetimes are `@_lifetime`, still experimental. Don't generate public API that needs them.

## Not in 6.4 (Accepted or in review, don't use without toolchain proof)

- Same-file memberwise initializer extensions. [SE-0546](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0546-memberwise-init-extensions.md) (Accepted)
- Mutation and consumption in noncopyable `deinit`s. [SE-0544](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0544-mutate-or-consume-in-deinit.md) (Accepted)
- `reduce` producing noncopyable results. [SE-0515](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0515-noncopyable-reduce.md) (Accepted)
- `Span` over a single value. [SE-0551](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0551-span-of-one.md) (Accepted; listed under CHANGELOG "Swift (next)")
- `FilePath` in the stdlib. [SE-0529](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0529-filepath-in-stdlib.md) (Accepted with modifications)
- Literal expressions. [SE-0531](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0531-literal-expressions.md) (Accepted)
- `Disconnected`. [SE-0538](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0538-disconnected.md) (Accepted)
- Task identity. [SE-0553](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0553-task-identity.md) (Accepted)
- Macros granting `self` access for property initializers. [SE-0539](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0539-self-access-for-property-initializers.md) (Returned for revision)
- `@dynamicMemberLookup` extra arguments [SE-0484](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0484-allow-additional-args-to-dynamicmemberlookup-subscripts.md), `InlineArray: Hashable` [SE-0543](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0543-inline-array-hashable.md): "Implemented (Swift Next)", i.e. after 6.4.
