---
name: flutter-code-hygiene
description: Use when the user wants to clean up a Flutter project — find dead code, unused imports, unused assets, duplicate widgets, or reduce app size. Triggers on "find dead code", "clean unused assets", "audit widget reuse", "reduce app size", "code hygiene check", "find duplication", "what can I delete", or any cleanup-focused request. Always presents findings as approvable lists; never deletes without explicit user approval.
---

# Flutter Code Hygiene

Detects three classes of waste in a Flutter codebase: **dead code**, **unused assets**, and **duplicate widget structures**. Always read-only by default. Deletion happens only after explicit user approval, item by item or in batches.

## Scope (Three Independent Modes)

User picks which audit to run. Don't run all three by default — outputs get overwhelming.

### Mode 1: Dead Code Detection
### Mode 2: Unused Asset Detection
### Mode 3: Widget Duplication Audit

If user says "clean everything," ask: "Run them in this order — dead code first, then assets, then widgets? Each generates a separate report."

---

## Mode 1: Dead Code Detection

### What counts as "dead code"

In order of detection confidence (high → low):

1. **Unused imports** — `dart analyze` catches these. Auto-fixable.
2. **Unused private members** (`_field`, `_method`) — analyzer catches most.
3. **Commented-out code blocks** (>5 consecutive comment lines that look like code).
4. **Files referenced by nothing** — no `import` statement anywhere in `lib/` or `test/`.
5. **Public symbols (classes, top-level functions) with zero usages** — flag for review only, don't auto-delete.

### Workflow

**Step 1: Run static analysis**
```bash
flutter analyze
dart fix --dry-run
```

**Step 2: Search for orphan files**
For each `.dart` file in `lib/`:
- Grep the project for `import` statements referencing it
- If zero matches → candidate orphan

Exclude: `main.dart`, `*.g.dart`, `*.freezed.dart`, `*.config.dart`, generated files, `firebase_options*.dart`.

**Step 3: Detect commented-out blocks**
Find any contiguous block of 5+ lines where each line starts with `//` and contains `;`, `{`, `}`, `=`, or `(` — strong indicators it's commented-out code, not documentation.

**Step 4: Find unused public symbols**
For each public class/function in `lib/`:
- Grep for usages outside the declaring file
- Zero usages → flag (but don't auto-delete, it may be used by tests/reflection/DI generation)

### Output Format

```markdown
# Dead Code Report

## Auto-Fixable (safe to apply via `dart fix --apply`)
- N unused imports across M files
- K unused private members

Run: `dart fix --apply` — then `flutter analyze` to confirm

## Orphan Files (no imports point to them)
- lib/features/x/something_old.dart — 47 lines
- lib/util/legacy_helper.dart — 123 lines

⚠️ Verify these aren't used by *.g.dart files or DI generation before deleting.

## Commented-Out Code Blocks
- lib/features/x/x_view.dart:45-89 (44 lines) — appears to be old implementation
- lib/features/y/y_provider.dart:12-23 (11 lines)

## Unused Public Symbols (flag for review — don't auto-delete)
- class OldXService in lib/features/x/data/x_service.dart — 0 usages
- function _buildLegacyHeader in lib/features/y/y_view.dart — 0 usages

Are these intentional (used by reflection, tests, or planned features)?

## Recommended Deletion Order
1. Run `dart fix --apply` for auto-fixable items (zero risk)
2. Review and approve orphan files (low risk)
3. Review commented-out blocks individually (zero risk if confirmed dead)
4. Verify unused public symbols with the user (medium risk)
```

End with: *"Which items should I delete? Reply with numbers or 'all auto-fixable', 'all orphans', etc."*

### Deletion Workflow

For each approved deletion:
1. Delete the file or remove the block
2. Run `flutter analyze` — must stay clean
3. Run `flutter test` — must still pass
4. Report results

If any test fails or analyzer warns, **stop and revert** that change.

---

## Mode 2: Unused Asset Detection

### What's an asset?

Files in `assets/` referenced via `pubspec.yaml` — images, fonts, JSON configs, Lottie files, etc.

### Why this is tricky

Assets are referenced as strings, often **interpolated at runtime**:

```dart
final iconPath = 'assets/icons/${type.name}.svg';  // grep can't catch this
```

Naive "no exact string match → unused" gives false positives. Be conservative.

### Workflow

**Step 1: Enumerate assets**
```bash
find assets -type f
```

Also check `pubspec.yaml`'s `flutter.assets:` section for declared paths.

**Step 2: Check `lib/gen/assets.gen.dart`** (if `flutter_gen` is used)
Any asset not in this generated file is potentially unused.

**Step 3: Grep for direct references**
For each asset path, search `lib/` for:
- Exact path string match
- The filename (without folder prefix)
- The basename without extension

**Step 4: Detect interpolation patterns**
Search for patterns like:
- `'assets/icons/$`
- `'assets/${`
- `Assets.icons.` (flutter_gen pattern)

If a folder has any interpolation reference, mark ALL assets in that folder as "possibly referenced via interpolation — manual review needed".

### Output Format

```markdown
# Unused Assets Report

## Definitely Unused (zero references, no interpolation in folder)
- assets/legacy/old_logo.png — 47 KB
- assets/temp/test_image.jpg — 122 KB

Total: 2 files, 169 KB

## Possibly Unused (interpolation exists in folder — verify manually)
- assets/icons/calendar_old.svg — folder uses 'assets/icons/${type}.svg'
- assets/icons/refresh_v2.svg — same folder

Do you reference these by name string anywhere? If not, safe to delete.

## Asset Folders with Interpolation
- assets/icons/ — referenced via `'assets/icons/${type.name}.svg'` in x_view.dart:34
- assets/illustrations/ — referenced via `'assets/illustrations/$key.svg'` in y_provider.dart:12

## Total Potential Savings
- Confirmed: 169 KB
- Possible (after verification): 540 KB
- Combined: ~709 KB
```

End with: *"Which to delete? I'll only act on Definitely Unused unless you confirm specific Possibly Unused items."*

### After deletion

1. Update `pubspec.yaml` if specific paths were listed
2. Run `flutter pub get`
3. Run `flutter run --debug` once to confirm no asset-not-found at runtime (or warn user to test manually)

---

## Mode 3: Widget Duplication Audit

### What we're looking for

Widget structures repeated 3+ times across the codebase that could be extracted into a reusable widget.

### What we're NOT looking for

- Generic patterns (`Padding`, `Row` with 2 children) — these are normal, not duplication
- Same `Text(...)` call across files — that's not a widget, just a usage
- Widgets that look similar but have different responsibilities — extracting reduces clarity, not increases it

The bar: if extracting would save ≥10 lines per usage site AND the extraction has a clean, narrow interface, it's worth flagging.

### Workflow

**Step 1: Identify candidate patterns**
Look in `lib/features/**/presentation/views/` and `lib/features/**/presentation/widgets/` for:
- Repeated `Container` configurations (decoration + padding + child structure)
- Repeated form field patterns (label + input + error display)
- Repeated card layouts (image + title + subtitle + action button)
- Repeated empty/error/loading state widgets

**Step 2: Compare across features**
For each candidate pattern, search for similar structures in other features. Look for:
- Same widget tree shape (Container → Padding → Row → Icon + Text)
- Similar (not identical) styling — same colors, similar sizes

**Step 3: Score the extraction value**
For each duplication:
- Number of occurrences (need 3+)
- Lines saved per occurrence
- Parameter count of the extracted widget (lower = better)

### Output Format

```markdown
# Widget Duplication Report

## High-Value Extractions

### 1. Status Badge (5 occurrences across 4 features)
Files:
- lib/features/dashcams/.../alert_card.dart:78-93
- lib/features/goals/.../goal_tile.dart:45-60
- lib/features/courses/.../course_status.dart:22-37
- lib/features/notifications/.../notif_item.dart:55-70
- lib/features/orders/.../order_row.dart:34-49

Common shape: 16-line Container with rounded corners, colored background, icon + text.
Proposed extraction:
```dart
class StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  // 12 lines of build method
}
```

Estimated savings: 5 × 16 = 80 lines reduced to 5 × 1 = 5 lines.

### 2. Empty State Card (3 occurrences in home, courses, notifications)
[... similar format ...]

## Low-Value (flagging only — extraction may not improve clarity)
- Pull-to-refresh wrapping — already trivial, extraction adds little
- AppBar configurations — slightly different per feature, leave alone

## Existing Reusable Widgets to Promote
- common/widgets/rounded_container_widget.dart — only used in 2 places; if it fits the patterns above, expand usage

## Recommended Order
1. Extract Status Badge → common/widgets/shared/status_badge.dart
2. Extract Empty State Card → common/widgets/shared/empty_state_card.dart
3. Replace usages one feature at a time
4. Run flutter analyze + flutter test after each replacement
```

End with: *"Want me to extract widget #1? I'll propose the extraction first, get your approval, then refactor one usage at a time."*

---

## Mandatory Rules (all modes)

1. **Read-only by default.** Always produce a report first. Never delete on the same turn as detection.
2. **Per-batch approval.** User can approve "all auto-fixable" but must explicitly approve each public symbol or asset for deletion.
3. **Run tests after each change.** `flutter analyze` + `flutter test` after every deletion/refactor.
4. **Stop at the first failure.** If a deletion breaks analyzer or tests, revert that one change and continue with others.
5. **Never touch `lib/features/auth/`**, `lib/util/di/`, `android/`, `ios/`, `pubspec.yaml`, or CI configs without explicit per-file approval.
6. **`.g.dart` / `.freezed.dart` files** are auto-generated — never delete them directly. Delete the source file and re-run `build_runner`.

## When in Doubt

- If unsure whether a symbol is used by reflection (rare in Flutter, but exists for `injectable`, `riverpod` codegen): keep it.
- If a file looks dead but has a recent commit: ask the user. May be in-flight work.
- If unsure about an asset, default to KEEP. App size reduction isn't worth a runtime crash.
