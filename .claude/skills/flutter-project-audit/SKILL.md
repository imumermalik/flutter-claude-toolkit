---
name: flutter-project-audit
description: Use when the user wants to audit, review, or analyze an existing Flutter project for architecture violations, code quality issues, dead code, or migration debt. Triggers on "audit this project", "review architecture", "find violations", "what's wrong with this codebase", "migrate this feature", "convert this to DDP", "modernize this code", or any request for a structured codebase health report. Produces an actionable, prioritized migration plan feature-by-feature.
---

# Flutter Project Audit

Onboards Claude to an unfamiliar (or messy) Flutter codebase. Produces a structured report and prioritized migration plan. Never auto-migrates — always proposes per-feature, gets approval, then executes one feature at a time.

## When to Trigger

- User asks for a code review, audit, or architecture analysis
- User wants to migrate from Riverpod 2.x to 3.x, or any state management migration
- User asks "where should I start refactoring this project?"
- Onboarding to a new (to Claude) codebase before doing real work

## Two-Phase Workflow

### Phase 1: Discovery & Report (no code changes)

Phase 1 is read-only. Produces an audit report. No migrations yet.

### Phase 2: Per-Feature Migration (one at a time, with approval gates)

After the user picks a feature from the report, migrate that one feature, run the verification workflow, then stop and wait for the next instruction.

## Phase 1: Discovery Workflow

### Step 1: Project shape

Inspect (do not modify):

- `pubspec.yaml` — Flutter/Dart versions, dependencies, dev_dependencies
- `lib/` — top-level folder structure
- `lib/features/` (or equivalent) — count and list features
- `lib/helpers/` — existing helper wrappers
- `lib/infrastructure/` — base abstractions (`Usecase`, `Repository`, etc.)
- `lib/util/di/` — DI setup (GetIt, Injectable, etc.)
- CLAUDE.md — project rules (if present)
- `analysis_options.yaml` — lint config

### Step 2: Sample features

Read 3-5 feature folders to understand the established patterns. Compare across them to find inconsistencies.

For each sampled feature, note:
- Layer structure (DDP? something else?)
- State management (Riverpod 2.x? 3.x? mixed? Bloc? Provider?)
- Folder naming (singular? plural?)
- Use of `@freezed`, `@riverpod`, `@injectable`
- Test presence

### Step 3: Detect violations

Run these checks across `lib/`:

**Architecture violations:**
- Direct package imports in `domain/` layer (any `package:` import that isn't on the domain allow-list)
- Direct HTTP/storage/firebase imports outside `lib/helpers/`
- `data/` layer importing `presentation/` (reverse dependency)
- `presentation/` importing `data/` directly (skipping providers/usecases)

**State management debt:**
- Files extending `StateNotifier` (Riverpod 2.x — should be `Notifier` / `AsyncNotifier` in 3.x)
- Manual `Provider<X>((ref) => X())` syntax (should be `@riverpod` codegen)
- `setState` in feature code for app-wide state
- `Provider.of<T>(context)` (Provider package — should be Riverpod)

**Code quality:**
- `dynamic` types in non-I/O code
- Hard-coded strings in UI (should be localized)
- Hard-coded colors not from theme
- Magic numbers in sizing (should use `flutter_screenutil` or constants)
- `setState` for fetched data (should be in a notifier)
- Business logic inside `build()` methods

**Test debt:**
- Features with zero test files
- Domain layer without unit tests

**Naming inconsistencies:**
- Mixed singular/plural folder names across features

### Step 4: Produce the report

Format (use this template literally — keeps reports comparable across projects):

```markdown
# Project Audit Report

## Summary
- Flutter version: X.X.X
- State management: <Riverpod 3.x / 2.x / mixed / other>
- Architecture: <DDP / Clean / MVC / mixed>
- Total features: N
- Features fully conforming: A
- Features with violations: B
- Migration scope estimate: <small / medium / large>

## Conforming Features (no changes needed)
- feature_a
- feature_b
- ...

## Features Needing Work

### Quick Wins (1-2 small violations each, ~30 min per feature)
- **feature_x** — <bullet list of specific issues>
- **feature_y** — <bullet list>

### Medium Effort (multiple violations or refactors needed, ~1-2 hrs per feature)
- **feature_p** — <issues>
- **feature_q** — <issues>

### High Risk (touches auth, DI, or central providers — needs careful planning)
- **feature_m** — <issues + why it's risky>

## Cross-Cutting Issues
- <e.g. "5 features import http directly — need a HttpHelper wrapper">
- <e.g. "No tests exist for any data layer">
- <e.g. "Folder naming inconsistent: 12 features singular, 4 plural">

## Recommended Migration Order
1. <feature> — <reason>
2. <feature> — <reason>
3. ...

## Tooling Gaps
- <e.g. "No CI runs flutter analyze">
- <e.g. "build_runner not in CI">

## Notes / Open Questions for the User
- <e.g. "Feature X uses StateNotifier with a custom mixin — is this intentional?">
- <e.g. "Two features have direct firebase_messaging imports — should we extract a NotificationsHelper?">
```

End the report with: *"Which feature should we migrate first? Or do you want to discuss the cross-cutting issues before picking?"*

## Phase 2: Per-Feature Migration Workflow

After the user picks a feature, follow this exact sequence:

### Step 1: Pre-migration analysis

For the picked feature, list:
- Files that will change
- Files that will be created
- Files that will be deleted (if any)
- External consumers of this feature (who imports from it)
- Risks (anything that could break in other features)

### Step 2: Propose the plan

Show the user:
- Migration steps (numbered)
- Estimated files changed
- Test strategy (what tests to write/update)
- Rollback plan (if something breaks)

**Wait for user approval** before any file edits.

### Step 3: Execute one step at a time

For each migration step:
1. Make the change
2. Run `flutter analyze`
3. Run `flutter test`
4. Report results
5. Get user approval before the next step

If any step fails analyzer/tests, stop and discuss with the user.

### Step 4: Post-migration verification

After all steps complete:
1. `dart run build_runner build --delete-conflicting-outputs`
2. `flutter analyze` — zero warnings
3. `flutter test` — all pass
4. Spot-check at runtime if integration test exists

### Step 5: Stop and report

Show:
- What changed
- What still needs work in this feature (if anything)
- Suggested next feature to migrate

Do NOT auto-continue to the next feature. Wait for user instruction.

## What NOT to Do

- Do not auto-migrate the entire codebase in one pass — high risk, low reviewability
- Do not silently rewrite features without showing the plan first
- Do not modify files in `lib/features/auth/`, `lib/util/di/`, `android/`, `ios/`, `.github/workflows/`, or `pubspec.yaml` without explicit per-file approval
- Do not delete files based on "looks unused" heuristics — use the `flutter-code-hygiene` skill (when available) for that
- Do not change the user's chosen folder naming convention — flag inconsistencies but don't mass-rename without approval

## Common Pitfalls

- **Cross-feature imports:** migrating feature X breaks feature Y because Y imports a non-public type from X. Always check consumers before changing public APIs.
- **DI graph breaks:** removing or renaming a `@LazySingleton` class requires updating every constructor that injects it.
- **`*.g.dart` drift:** after changing `@riverpod` / `@injectable` / `@freezed` annotations, the generated files are stale until `build_runner` runs. Never leave a feature in a half-generated state.
- **Riverpod 2.x → 3.x naming:** `xProvider` (manual) and `xProvider` (generated) collide. Migration must rename or delete the old one cleanly.

## Output Tone

Be direct. The audit report is a working document, not a sales pitch. State problems plainly. If a feature is genuinely well-written, say so — false positives waste user time.
