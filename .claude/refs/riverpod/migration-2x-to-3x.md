# Riverpod 2.x → 3.x Migration Playbook

**Target audience:** Apployee project (currently on Riverpod 2.5.1).
**Loaded by:** `flutter-riverpod` skill when migration work is requested.

This playbook walks through the migration in **3 phases**, from safest cleanup to full version upgrade.

---

## Phase 1: Cleanup First (Stay on 2.x)

**Goal:** Convert 5 legacy `StateNotifier` files to `@riverpod` codegen (still 2.x).
**Risk:** 🟢 Low
**Estimated time:** 2–3 hours total
**Why first:** Audit-identified, doesn't touch pubspec, no breaking version change.

### Files to migrate (from audit)

| # | File | Estimated effort |
|---|---|---|
| 1 | `lib/features/support/.../unread_messages_provider.dart` | ✅ Already deleted (dead code) |
| 2 | `lib/features/driving_behavior/.../driving_behavior_provider.dart` | 60 min — complex (race conditions, multiple providers) |
| 3 | `lib/features/driving_behavior/.../driver_behaviour_details_provider.dart` | 45 min |
| 4 | `lib/features/profile/.../profile_provider.dart` | 30 min — anti-pattern (fetch in constructor) |
| 5 | `lib/helpers/socket_helper/...` | Review separately — may not need migration |

### Migration pattern (per file)

**Before (2.x StateNotifier):**

```dart
final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier();
});

class MyNotifier extends StateNotifier<MyState> {
  MyNotifier() : super(MyState.initial());

  Future<void> fetchData() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.fetchData();
      state = state.copyWith(data: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e, isLoading: false);
    }
  }
}
```

**After (2.x @riverpod codegen, AsyncNotifier pattern):**

```dart
@riverpod
class MyData extends _$MyData {
  @override
  Future<DataType> build() async {
    return _fetchData();
  }

  Future<DataType> _fetchData() async {
    final usecase = sl<FetchDataUsecase>();
    final bearer = await ref.read(stmBearerTokenProvider.future);
    final input = FetchDataUsecaseInput(bearerToken: bearer!);
    final output = await usecase(input);
    return output.data;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchData);
  }
}
```

### Per-file workflow

For EACH file in the list:

1. **Read the file** + identify all consumers (widgets/providers using it)
2. **Show migration plan**:
   - What will change in the file
   - What consumers will need updates
   - Risks (e.g., race condition logic preservation in `driving_behavior_provider`)
3. **Get user approval**
4. **Migrate the file**:
   - Replace `StateNotifier` with `@riverpod class` pattern
   - Move state initialization from constructor to `build()`
   - Convert mutation methods to update `state` via `AsyncValue`
   - Add `_fetchX()` private method if data-fetching
5. **Update consumers**:
   - `ref.watch(myStateNotifierProvider)` → `ref.watch(myDataProvider)`
   - Update widgets handling `AsyncValue` if needed
6. **Run code generation**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
7. **Run analyzer**:
   ```bash
   flutter analyze
   ```
8. **Manual smoke test** on the affected screen
9. **Commit**: `refactor: migrate <feature> from StateNotifier to @riverpod codegen`

### Special handling: `driving_behavior_provider.dart`

This file has a `_requestId` race-condition guard. **Preserve this logic exactly.**

In the new `@riverpod` version, the race guard can be simplified using `autoDispose` (default in `@riverpod`) + checking if state is current before assigning:

```dart
Future<void> _fetchData(int requestId) async {
  final result = await api.fetchData();
  // If new request started while this was in flight, ignore stale result
  if (_currentRequestId != requestId) return;
  state = AsyncData(result);
}
```

Or use 3.x `ref.mounted` (but that's Phase 3, not Phase 1).

### Phase 1 success criteria

- [ ] All 4 files (excluding dead `unread_messages`) converted to `@riverpod`
- [ ] `flutter analyze` shows zero new warnings
- [ ] All consumer screens work as before (manual smoke test)
- [ ] No `StateNotifier` imports remaining in `lib/features/`
- [ ] No new test failures (Apployee has zero tests anyway)

---

## Phase 2: Pubspec Version Bump (2.5.1 → 2.6.1)

**Goal:** Get to the last 2.x version before crossing the 3.x boundary.
**Risk:** 🟢 Low
**Estimated time:** 30 min
**Why:** 2.6.1 has bug fixes and deprecation warnings that help prepare for 3.x.

### Steps

1. **Backup pubspec.yaml** (commit it first if not already)
2. **Update pubspec.yaml** (REQUIRES USER APPROVAL — pubspec is gated):
   ```yaml
   dependencies:
     flutter_riverpod: ^2.6.1
     riverpod_annotation: ^2.6.1

   dev_dependencies:
     riverpod_generator: ^2.6.5
     riverpod_lint: ^2.6.5
   ```
3. **Run**:
   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   flutter analyze
   ```
4. **Address deprecation warnings**:
   - `XRef` types are deprecated — change to `Ref` (good prep for 3.x)
   - Other warnings should be minor
5. **Smoke test**

### Phase 2 success criteria

- [ ] `flutter analyze` clean
- [ ] App builds and runs
- [ ] All providers still resolve correctly

---

## Phase 3: Full 3.x Upgrade (When Ready)

**Goal:** Upgrade to Riverpod 3.x.
**Risk:** 🔴 High
**Estimated time:** 5–10 hours (full focused session)
**When:** Wait until Phase 1 + 2 done. Schedule a focused session.

### Pre-upgrade checklist

- [ ] All `StateNotifier` migrated to `@riverpod` (Phase 1 done)
- [ ] On Riverpod 2.6.1 (Phase 2 done)
- [ ] Recent backup / git branch created for rollback
- [ ] No production deploys scheduled for 1 week (allow burn-in)
- [ ] User has time for focused work

### Breaking changes you'll hit in Apployee

| Change | Files affected | Action needed |
|---|---|---|
| `StateNotifierProvider` → legacy import | 0 (Phase 1 done) | ✅ Already migrated |
| `XRef` → `Ref` (unified) | ~15+ files (every `@riverpod` function) | Sed-like rename: `<X>Ref ref` → `Ref ref` |
| `.valueOrNull` → `.value` | Wherever used | Codebase grep + replace |
| `AutoDispose*` → unified | 0 with codegen (handled automatically) | None |
| `FamilyNotifier` → `Notifier` + param | If used | Refactor (Apployee may not have any) |
| `provider.stream` → `ref.listen` | Check support feature | Refactor |
| Errors wrapped in `ProviderException` | Any `try/catch` on provider errors | Update catch clauses |
| Out-of-view providers paused | Background-running providers | Test behavior |
| `ProviderObserver` API change | If any observers exist | Update method signatures |

### Migration steps

1. **Update pubspec.yaml** (REQUIRES APPROVAL):
   ```yaml
   dependencies:
     flutter_riverpod: ^3.3.1
     riverpod_annotation: ^4.0.2

   dev_dependencies:
     riverpod_generator: ^4.0.3
     riverpod_lint: ^3.x  # latest 3.x compatible
   ```

2. **Run**:
   ```bash
   flutter pub get
   ```
   Expect compilation errors — that's normal.

3. **Mass renames** (do these systematically):
   - All `<XXX>Ref ref` parameters → `Ref ref`
   - All `.valueOrNull` → `.value`
   - All `import 'package:flutter_riverpod/flutter_riverpod.dart'` for legacy types → also add `import 'package:flutter_riverpod/legacy.dart'`

4. **Regenerate code**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. **Fix analyzer errors** one by one. Most will be import or type issues.

6. **Run app**, test thoroughly:
   - Login flow (auth is high-risk)
   - Home dashboard (aggregator of many providers)
   - Each major feature
   - Background behaviors (paused providers, retry, etc.)

7. **Update CLAUDE.md**: change `[CURRENT] Riverpod 2.5.1` to `[CURRENT] Riverpod 3.3.1`

8. **Commit incrementally** — don't do one giant PR. Break by feature.

### Phase 3 success criteria

- [ ] `pubspec.yaml` updated to 3.x
- [ ] `flutter analyze` clean
- [ ] Manual smoke test passes for all 18 features
- [ ] Auth flow (highest risk) verified
- [ ] CLAUDE.md updated to reflect new version

---

## Rollback Procedures

### If Phase 1 breaks something

```bash
git revert <commit-hash>
```

Each Phase 1 file should be its own commit. Easy to revert one feature without affecting others.

### If Phase 2 breaks something

```bash
git revert <pubspec-commit>
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### If Phase 3 breaks something

If serious issue mid-migration:

```bash
git checkout main  # or previous stable branch
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Identify root cause, plan smaller migration steps, retry.

---

## Common 3.x Migration Gotchas

1. **`provider.stream` removed**: Replaced by `ref.listen(provider, (_, value) {...})`. Affects any code that did `.stream.listen(...)`.

2. **`AsyncValue.value` returns null on error**: In 2.x it threw. In 3.x it returns null. Old code relying on the throw will silently break. Audit all `.value` (or `.valueOrNull`) usages.

3. **`ProviderException` wrapping**: If your code does `try { ref.watch(p) } on SomeError catch (e)`, in 3.x you need `on ProviderException catch (e) { if (e.exception is SomeError) ... }`.

4. **Providers pause when out of view**: If a provider runs a background task expecting to always be alive, it may now pause. Use `@Riverpod(keepAlive: true)` if truly needed.

5. **Automatic retry default**: Failing providers retry automatically in 3.x. If your error logging counts errors, you may see more entries. Configure retry behavior if needed.

---

## After Migration: Update This Skill

Once Apployee is on 3.x:

1. Update `CLAUDE.md`:
   ```
   - [CURRENT] Riverpod 3.x (3.3.1)
   - [TARGET] Riverpod 3.x
   ```

2. The skill (`flutter-riverpod`) will automatically use 3.x patterns from then on.

3. This migration playbook stays as reference — useful for future Riverpod major version migrations.

---

## Reference Links

- [Migration guide (official)](https://riverpod.dev/docs/migration/from_2_0_to_3_0)
- [What's new in 3.0](https://riverpod.dev/docs/whats_new)
- [Riverpod docs root](https://riverpod.dev/docs)
- pub.dev:
  - `flutter_riverpod`: https://pub.dev/packages/flutter_riverpod
  - `riverpod_annotation`: https://pub.dev/packages/riverpod_annotation
  - `riverpod_generator`: https://pub.dev/packages/riverpod_generator
