# MOLE — Build Plan
### The local storage inspector for Flutter — see, edit, and clear everything your app has stored

> **Context for opencode: this package is being forked from an existing package called Ferret** (an HTTP inspector). Ferret's floating overlay architecture, config-gating system, and Material 3 UI patterns are being reused. This is NOT a from-scratch build — it's a rename + adaptation. Read Section 1 fully before touching any code.

---

## 1. This Is a Fork of Ferret — Read This First

The starting codebase is Ferret (an HTTP inspector: floating bubble → dashboard → list/detail view of captured network calls, with a debug/release config gate). We are turning it into **Mole**, a local storage inspector with the same look, feel, and safety model, but inspecting SharedPreferences/Hive/Secure Storage/Isar instead of HTTP calls.

### 1a. Full rename checklist — do this first, before any feature work

Every occurrence of `Ferret` / `ferret` must become `Mole` / `mole`. This includes:

- [ ] Package name in `pubspec.yaml`: `ferret` → `mole`
- [ ] Public API file: `lib/ferret.dart` → `lib/mole.dart`
- [ ] All class names: `Ferret` → `Mole`, `FerretConfig` → `MoleConfig`, `FerretEntry` → `MoleEntry`, `FerretStore` → `MoleStore`, `FerretBubble` → `MoleBubble`, `FerretDashboard` → `MoleDashboard`, `FerretDetailView` → `MoleDetailView`
- [ ] All folder/file names under `lib/src/`: any `ferret_*.dart` → `mole_*.dart`
- [ ] `example/` app: update imports, class references, README references
- [ ] `README.md`, `CHANGELOG.md`: fully rewritten for Mole, not just find-replace (the feature set is different — see Section 3)
- [ ] GitHub repo description, pub.dev description, package description in `pubspec.yaml`
- [ ] Any code comments referencing "HTTP", "request", "response", "network" that no longer apply — replace with storage-appropriate language ("entry", "key", "value", "source")

**Do a full repo-wide search for the literal string "ferret" (case-insensitive) at the end and confirm zero results before considering the rename done.**

### 1b. What stays exactly the same (reuse, don't rebuild)

- The floating bubble UI (draggable, minimizable, resizable) — except the indicator behavior, which changes per §3b (database icon + pulse + threshold badge instead of a persistent count)
- Material 3 dashboard shell, dark/light auto-theme
- The `enabled` / `enableInRelease` / `showReleaseWarning` config gating system and its exact boot logic (see Section 4) — this is Mole's core trust mechanism too, identical to Ferret's
- The release-mode console warning + persistent on-screen "ACTIVE IN RELEASE" tag
- Ring-buffer-style live update pattern (`ChangeNotifier`-based store) for pushing new data into the UI without full rebuilds
- Search bar UI pattern
- The overall phase-by-phase build discipline (don't skip ahead)

### 1c. What's structurally different from Ferret (new work)

| Ferret | Mole |
|---|---|
| Auto-intercepts globally (Dio/http/dart:io hook into one pipeline) | **Cannot auto-intercept.** Developer must register each storage instance once at startup (see Section 5) |
| One flat list of captured HTTP calls | **Grouped by source** — dashboard home is a list of registered storage sources, tap one to see its contents |
| Entries are immutable capture records | **Entries are live, mutable data** — user can edit or delete a stored value directly from Mole |
| No "clear" concept (it's a request log) | **Clear is a core feature** — clear one key, clear one source, or clear everything |
| Redaction only matters at export | **Secure Storage values are masked by default in-app**, not just at export — this is the one place Mole hides data by default, because it's genuinely sensitive at-rest data, not a debug log |

---

## 2. Non-Negotiable Design Principles

Same spirit as Ferret, adapted:

1. **Zero config beyond registering sources.** No manual polling, no custom adapters required for the 3 built-in source types.
2. **Full raw visibility for non-secure sources.** SharedPreferences, Hive, Isar values shown exactly as stored, no masking.
3. **Secure Storage is the one exception** — masked by default in-app (tap to reveal), because these are real secrets (tokens, credentials) sitting at rest on a real device.
4. **Off by default in release builds.** Same `enableInRelease` gate as Ferret, identical warning behavior.
5. **Lightweight, fast, stable — this is a hard requirement, not a nice-to-have.** Mole must never cause jank, memory bloat, or slow down the host app. Specifics in Section 6.

---

## 3. Feature Set

### MVP (v0.1 — ship this first)
- `Mole.install(config:, sources:)` — one-line install, developer passes already-created storage instances
- Built-in source adapters: `MoleSharedPrefsSource`, `MoleHiveSource`, `MoleSecureStorageSource`, `MoleCacheSource`
- `MoleValueRenderer` — one shared value renderer used by every source's list + detail view (see below)
- **Mole bubble**: database icon + pulse-on-write + cache-threshold badge (see 3b)
- Floating draggable/minimizable bubble (reused from Ferret)
- Dashboard home: list of registered sources with entry counts
- Tap a source → table/list view of all keys + values in that source, live-updating
- Tap an entry → detail view with **Edit** and **Delete** actions
- Clear all data in a single source (with confirmation dialog — this is destructive, needs a guard)
- Search/filter by key name within a source
- Debug/release gating identical to Ferret (Section 4 below)
- Material 3 UI, auto dark/light

### V1.1 (fast follow)
- `MoleIsarSource` adapter
- Export a source (or everything) to JSON file
- Share exported file (same share-sheet pattern as Ferret's session export)
- Global "clear everything across all sources" with a stronger, double-confirm guard

### V2 (later)
- Type-aware value editing (edit a `bool`/`int`/`List` properly instead of raw string, where the source supports it)
- Diff/history — see what a key's value was before the last edit (session-only, not persisted)

### One shared value renderer — MoleValueRenderer (MVP, not V2)

Every source can hold different data types. Instead of separate rendering
logic per source, Mole builds **one shared component**, `MoleValueRenderer`,
used by `mole_source_view.dart` and `mole_detail_view.dart`.

Data types per source:

| Source | Data types |
|---|---|
| SharedPreferences | Only primitives: `String`, `int`, `double`, `bool`, `List<String>` — never binary |
| Secure Storage | Only `String` (binary is base64-encoded into a string by the dev if used at all) |
| Hive | Anything — primitives, `Map`, `List`, custom TypeAdapter objects, raw `Uint8List` bytes (this is where images/binary actually appear) |
| Cache | Real files — images, JSON, PDFs, any binary |

Renderer behavior:

- **Primitive** (`String`/`int`/`bool`/`double`) → plain text, inline editable
- **Map / List** → formatted, expandable JSON tree — not a raw text dump
- **Uint8List / raw bytes (Hive only)** → attempt image decode; if it decodes, show a thumbnail + byte size; if not, show `"Binary data — N bytes"` with a short hex preview — never crash on unrecognized bytes
- **Cache files** → if the extension/mime is an image, show a thumbnail; otherwise a file-type icon + size + last-modified date

**Editing rule (set once, do not violate):** only primitives and JSON-safe
`Map`/`List` values are editable. Binary/image values (Hive bytes, cache
files) are **view + delete only**. Never build an edit UI for raw bytes.

### 3b. Mole bubble behavior — the floating indicator

Unlike Ferret's bubble (which shows a live API call count, since network
calls are a constant stream), Mole's bubble does **NOT** show a persistent
number. Storage writes are occasional, not a stream, so a static count would
just be meaningless noise most of the time.

Implement instead:

- **Default state: a database icon** — a database/cylinder icon (not a
  magnifying glass, not a folder icon). A database/cylinder icon reads as more
  professional and immediately signals "this inspects storage".
- **Pulse-on-write**: briefly flash/glow the bubble (~500ms animation)
  whenever any registered source changes — lightweight feedback that something
  happened. No number, just a visual pulse.
- **Optional warning badge**: a small red dot appears **only if** total cache
  size crosses a configurable threshold (default `50MB`). This is the one case
  a badge is actually useful signal, not decoration.
- **Keep this lightweight**: the pulse is a simple opacity/scale animation on
  the bubble, NOT a heavy widget rebuild of the dashboard or source views. It
  must not affect the "near-zero overhead" requirement from Section 6.

---

## 4. Config System (identical pattern to Ferret)

```dart
class MoleConfig {
  final bool enabled;
  final bool enableInRelease;
  final bool showReleaseWarning;
  final bool startMinimized;
  final int cacheSizeWarningThresholdMB; // default: 50

  const MoleConfig({
    this.enabled = true,
    this.enableInRelease = false,
    this.showReleaseWarning = true,
    this.startMinimized = true,
    this.cacheSizeWarningThresholdMB = 50,
  });
}
```

Boot logic, warning format, and on-screen "ACTIVE IN RELEASE" tag: **identical to Ferret's Section 4 spec.** Copy that logic over, only rename identifiers.

---

## 5. Source Registration (the new concept vs. Ferret)

```dart
abstract class MoleSource {
  String get name;                          // display name, e.g. "SharedPreferences"
  Stream<List<MoleDataEntry>> watch();       // live entries for this source
  Future<void> setValue(String key, dynamic value);
  Future<void> deleteValue(String key);
  Future<void> clearAll();
}
```

Each built-in adapter wraps an existing instance the developer already created — Mole never creates or owns storage instances itself:

```dart
Mole.install(
  config: const MoleConfig(),
  sources: [
    MoleSharedPrefsSource(prefs),
    MoleHiveSource(box: myBox),
    MoleSecureStorageSource(secureStorage),
  ],
);
```

`MoleDataEntry`:
```dart
class MoleDataEntry {
  final String key;
  final dynamic value;
  final String sourceType; // 'prefs' | 'hive' | 'secure' | 'isar'
  final bool isSensitive;  // true for secure storage — controls default masking
}
```

### 5a. Cache is the 4th source type — a different shape from the others

**Cache is NOT a key-value store** like Hive/Prefs/Secure Storage. It's real
files sitting in the OS temp directory (`getTemporaryDirectory()` from
`path_provider`), written there by things like `flutter_cache_manager`,
`cached_network_image`, or custom download code.

- Adds `MoleCacheSource`:
  - **Auto-reads** the app's temp directory — no instance needed from the
    developer, unlike the other 3 sources (which wrap existing instances).
  - Registration: `MoleCacheSource()` — zero config, just add it to the
    `sources: [...]` list:
    ```dart
    Mole.install(
      config: const MoleConfig(),
      sources: [
        MoleSharedPrefsSource(prefs),
        MoleHiveSource(box: myBox),
        MoleSecureStorageSource(secureStorage),
        MoleCacheSource(),
      ],
    );
    ```
  - Lists **files**, not key/value pairs: name, size, last-modified, file type.
  - Actions: **delete a single file**, **clear the entire cache directory**
    (with confirmation — this is destructive). No **edit** action for cache —
    files are view/delete only, never editable.

---

## 6. Performance & Stability Requirements (hard constraints)

Mole sits inside a real app, potentially with thousands of stored keys (large Hive boxes especially). These are not optional:

- **Lazy list rendering** — use `ListView.builder`, never render all entries eagerly for large sources
- **Debounce live updates** — if a source is written to rapidly (e.g. tight loop), batch UI refreshes (e.g. 150–250ms debounce), never rebuild on every single write
- **No polling** — sources must push updates via `Stream`/listener, not be polled on a timer
- **Bounded memory** — if a source has a huge number of entries, paginate the detail table rather than holding everything in a widget tree at once
- **Isolate-safe** — Mole's internal work (search filtering, JSON serialization for export) should never block the UI thread for large datasets; use `compute()` for export serialization if a source is large
- **True no-op when disabled** — identical requirement to Ferret: if `enabled: false` or release-mode-gated off, zero listeners attached, zero overhead
- **No heavy dependencies** — Mole's own `pubspec.yaml` should only depend on what's needed for the UI + core; SharedPreferences/Hive/Isar/SecureStorage packages are peer dependencies, not bundled

---

## 7. File Structure (renamed from Ferret)

```
mole/
├── lib/
│   ├── mole.dart                       // public API surface
│   └── src/
│       ├── config/
│       │   └── mole_config.dart
│       ├── core/
│       │   ├── mole_engine.dart
│       │   ├── mole_entry.dart         // MoleDataEntry
│       │   └── mole_store.dart
│       ├── sources/
│       │   ├── mole_source.dart        // abstract base
│       │   ├── shared_prefs_source.dart
│       │   ├── hive_source.dart
│       │   ├── secure_storage_source.dart
│       │   ├── cache_source.dart       // file-listing, no instance needed
│       │   └── isar_source.dart        // v1.1
│       ├── ui/
│       │   ├── mole_bubble.dart
│       │   ├── mole_dashboard.dart     // list of sources
│       │   ├── mole_source_view.dart   // table/list of entries in one source
│       │   ├── mole_detail_view.dart   // single entry, edit/delete
│       │   └── mole_value_renderer.dart // shared renderer (all sources)
│       └── export/
│           └── json_exporter.dart      // v1.1
├── example/
│   ├── lib/main.dart               // single form-based demo screen exercising all 4 sources (see §10)
│   ├── lib/services/storage_service.dart // initializes prefs/hive/secure/cache instances
│   └── assets/profile.png          // small bundled image → stored as raw Uint8List in Hive
├── test/
├── CHANGELOG.md
├── README.md
└── pubspec.yaml
```

---

## 8. Build Phases for opencode (execute in order)

**Phase 0 — Rename pass**
- Execute the full checklist in Section 1a
- Confirm the renamed package still compiles as a no-op shell (no new features yet)

**Phase 1 — Core skeleton**
- `MoleConfig`, `MoleDataEntry`, `MoleStore`, abstract `MoleSource`
- No UI, no real sources yet — unit test the store with a fake in-memory source

**Phase 2 — Source adapters**
- `MoleSharedPrefsSource` first (simplest)
- `MoleHiveSource` second
- `MoleSecureStorageSource` third (remember: masked by default)
- `MoleCacheSource` fourth — file-listing based, reuses `path_provider`, no instance needed; test it against a directory with mixed image + non-image files
- Test each in `example/` against real data

**Phase 3 — Debug/release gating**
- Port Ferret's exact gating logic, renamed
- Verify all 3 states: debug (active), release default (inert), release + `enableInRelease: true` (active + warning + tag)

**Phase 4 — UI: Bubble + Dashboard + Source view**
- Build **`MoleValueRenderer` as a shared component FIRST**, then wire both
  `mole_source_view.dart` and `mole_detail_view.dart` to use it — do not build
  per-source rendering logic that duplicates this
- Build the bubble per §3b: database icon, pulse-on-write (~500ms), cache-size
  warning badge; do **not** reuse Ferret's call-count badge
- Dashboard: list of sources with entry counts
- Source view (uses `MoleValueRenderer`): lazy-loaded table/list of entries, live-updating

**Phase 5 — Edit, delete, clear**
- Detail view with edit (raw string edit for MVP) and delete
- Clear-all-in-source with confirmation dialog

**Phase 6 — Search + performance pass**
- Search/filter within a source
- Verify Section 6 performance requirements against a source with 5,000+ fake entries — this is a mandatory stress test before Phase 7
- Stress test must include: a Hive box with at least a few large `Uint8List` entries, and a cache directory with 50+ mixed files — confirm thumbnail generation and lazy loading do not cause jank

**Phase 7 — Polish for pub.dev**
- New README (not a find-replace of Ferret's — different feature set, different quickstart)
- CHANGELOG starting fresh at 0.1.0
- `flutter pub publish --dry-run`, fix all warnings
- Target: 130+ pub points, 0 warnings

---

## 9. Definition of Done (MVP)

- [ ] Full rename complete — zero "ferret" references anywhere in the repo
- [ ] `Mole.install(config:, sources: [...])` works with the 3 built-in source types
- [ ] Fully inert in release by default, verified with a real release build
- [ ] Loud, unmissable warning when forced on in release (identical to Ferret's)
- [ ] SharedPreferences/Hive values shown raw and unmasked; Secure Storage masked by default, tap-to-reveal
- [ ] Edit and delete work per entry; clear-all works per source with confirmation
- [ ] Stress-tested against 5,000+ entries with no jank, no dropped frames on scroll
- [ ] Published to pub.dev with 0 warnings, working example app
- [ ] `MoleCacheSource` lists real files from the app's temp directory correctly
- [ ] `MoleValueRenderer` correctly renders primitives, JSON, images (from Hive bytes and cache files), and unrecognized binary without crashing
- [ ] Editing is blocked/hidden for binary and cache-file entries — view/delete only
- [ ] Clearing the cache directory works with a confirmation dialog
- [ ] Edit-writes-through verified in the example app: editing a SharedPreferences value in Mole is reflected in the host app after reload (see §10, step 2) — mandatory before publishing

---

## 10. Example App — Live Window Into Storage (two-way test flow)

`example/lib/main.dart` is built as **one single form-based screen** that
exercises all 4 registered sources. It is the core proof of Mole's value — a
live window into storage, not a snapshot. Register the demo source instances
in `example/lib/services/storage_service.dart` and wire this screen to
`Mole.install(...)`.

### 10a. The four sections (each wired to a real source)

- **SharedPreferences section** — a text field (name), and two toggles (dark
  mode, notifications). A **Save** button writes each as a **separate pref
  key**.
- **Secure Storage section** — a **Login** button that writes a fake
  `auth_token` string. Demonstrates Mole's masked / tap-to-reveal display for
  secure values.
- **Hive section** — a **Save Profile** button that writes a **nested Map**
  object into a Hive box, PLUS a separate entry storing **raw `Uint8List`
  bytes**. Bundle a small sample image as a Flutter asset, read its bytes, and
  store them in Hive — this proves the image-thumbnail rendering path in
  `MoleValueRenderer` works on real binary data.
- **Cache section** — a button that caches a sample network image (via
  `cached_network_image` or a manual write to `getTemporaryDirectory()`), to
  populate `MoleCacheSource` with a real, inspectable/deletable file.

### 10b. Documented two-way test flow (in the example app's README/comments)

1. Fill the form, tap each Save/Login/Cache button → open the Mole bubble →
   confirm all 4 sources show the new data.
2. **Edit-writes-through (do not ship without passing this)**: in Mole, edit
   one SharedPreferences value directly → return to the app screen and reload
   → the app must show the edited value. This proves Mole writes through to
   real storage.
3. Repeat the edit check for the Hive entry (non-binary field) and confirm it
   also writes through.
4. Delete a key from Mole (in each of Prefs, Secure Storage, Hive) → confirm
   the app reflects the default/empty state on next read.
5. Delete the cached image file from Mole → confirm it's gone from disk, or the
   app re-downloads it if reloaded.
