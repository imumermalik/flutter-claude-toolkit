---
name: flutter-riverpod
description: Use whenever Claude works with Riverpod providers, notifiers, ref methods, async state, family providers, or state management migration in Flutter projects. Triggers on creating providers, modifying notifiers, StateNotifier → @riverpod migration, AsyncNotifier work, ref.watch/read/listen/invalidate, AsyncValue patterns, provider testing. Dual-aware — supports both Riverpod 2.x and 3.x patterns based on the project's actual version (check CLAUDE.md or pubspec.yaml).
---

# Flutter Riverpod Patterns

Authoritative source: https://riverpod.dev/docs — fetch the page when in doubt. If memory disagrees with docs, docs win.

## Version Detection (ALWAYS DO FIRST)

Before generating any Riverpod code, detect the project's version:

1. **Check CLAUDE.md** for `[CURRENT] Riverpod 2.x` or `[CURRENT] Riverpod 3.x` markers
2. **Or check `pubspec.yaml`** for the `flutter_riverpod` version

Apply patterns accordingly. **Do not mix 2.x and 3.x patterns in the same file.**

| Project on... | Use patterns from this skill marked... |
|---|---|
| Riverpod 2.x (2.5.x–2.6.x) | `[2.x]` sections |
| Riverpod 3.x (3.0.0+) | `[3.x]` sections |

## Standard Project Pattern (Apployee-style AsyncNotifier)

This is the standard pattern across both versions. Use it for fetching data + refresh capability.

```dart
@riverpod
class GetX extends _$GetX {
  @override
  Future<List<XEntity>> build() async {
    return _fetchX();
  }

  Future<List<XEntity>> _fetchX() async {
    final usecase = sl<GetXUsecase>();
    final bearer = await ref.read(stmBearerTokenProvider.future);
    final input = GetXUsecaseInput(bearerToken: bearer!);
    final output = await usecase(input);
    return output.allX;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchX);
  }
}
```

Rules:
- Private `_fetchX()` separates fetch logic from `build()`
- Resolve usecases via `sl<>` (GetIt)
- Read dependencies via `ref.read(p.future)` for async, `ref.read(p)` for sync
- Refresh uses `AsyncValue.guard` for error handling
- Never mutate state in place — assign new `AsyncValue`

## Provider Type Decision

| Need | Use `@riverpod` codegen |
|---|---|
| Plain value | `T func(Ref ref)` |
| One-shot Future | `Future<T> func(Ref ref) async` |
| Stream | `Stream<T> func(Ref ref) async*` |
| Mutable state, sync | `class X extends _$X { T build() }` |
| Mutable state, async | `class X extends _$X { Future<T> build() async }` |
| Per-parameter cache (family) | Add params to `build()` |

Default to `@riverpod` codegen. **Do not write manual `Provider.autoDispose<>` syntax for new code.**

### `[2.x]` Function signature

```dart
@riverpod
Model x(XRef ref) { ... }  // Uses generated XRef
```

### `[3.x]` Function signature

```dart
@riverpod
Model x(Ref ref) { ... }  // Uses unified Ref
```

The Ref subclass change is the most common 2.x → 3.x adjustment.

## Ref Method Rules (Both Versions)

| Method | Use in | Purpose |
|---|---|---|
| `ref.watch(p)` | `build()` only | Rebuild when `p` changes |
| `ref.read(p)` | Action methods (event handlers, callbacks) | One-time read, no subscription |
| `ref.listen(p, cb)` | `build()` only | Side effects — navigation, dialogs, snackbars |
| `ref.invalidate(p)` | Anywhere | Force provider to recompute next read |
| `ref.refresh(p)` | Anywhere (`@useResult`) | Invalidate + read immediately |

**Side effects (navigation, showDialog, snackbar) ALWAYS in `ref.listen`, never in `build()`.**

### `[3.x]` Additional methods available

- `ref.mounted` — check if provider still alive after `await` (similar to `BuildContext.mounted`)
- `ref.listen(p, cb, weak: true)` — listen without keeping provider alive

## AsyncValue Patterns

### `[2.x]` valueOrNull usage

```dart
final data = ref.watch(provider).valueOrNull;
if (data != null) { ... }
```

### `[3.x]` value behavior changed

```dart
final data = ref.watch(provider).value;  // Returns null on error, not throws
if (data != null) { ... }
```

**Migration note:** In 3.x, `.value` returns null instead of throwing. Old `.valueOrNull` is removed.

### Pattern matching (recommended both versions)

```dart
switch (asyncValue) {
  AsyncData(:final value) => Text('$value'),
  AsyncError(:final error) => Text('Error: $error'),
  _ => const CircularProgressIndicator(),
}
```

### Pull-to-refresh pattern

```dart
RefreshIndicator(
  onRefresh: () => ref.refresh(provider.future),
  child: ...
)
```

Returning `provider.future` keeps the spinner visible until new data arrives.

## Family (Parameters on `build()`)

Both versions support parameters via codegen:

```dart
@riverpod
class GetUser extends _$GetUser {
  @override
  Future<User> build(String userId) async {
    return _fetchUser(userId);
  }
}

// Usage:
final user = ref.watch(getUserProvider('user-123'));
```

**Important:** Family parameters must have stable `==`/`hashCode`. Don't pass `List`/`Map` directly — cache them or use a value type.

## Side Effects (Critical Pattern)

NEVER do side effects in `build()`. ALWAYS use `ref.listen`:

```dart
@override
Future<List<X>> build() async {
  // ✅ Side effect via ref.listen
  ref.listen(authProvider, (previous, next) {
    if (next.isLoggedOut) {
      // Navigation, dialog, snackbar etc.
    }
  });

  return _fetchX();
}
```

In widgets, use `ref.listen` inside `build()`:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.listen<AsyncValue<int>>(counterProvider, (prev, next) {
    next.whenOrNull(error: (e, s) => showErrorSnackBar(context, e));
  });

  final count = ref.watch(counterProvider);
  return Text('$count');
}
```

## `[2.x → 3.x]` Migration Quick Reference

When migrating, the most common changes:

| 2.x | 3.x |
|---|---|
| `class X extends StateNotifier<T>` | `@riverpod class X extends _$X` |
| `StateNotifierProvider<X, T>` | `xProvider` (auto-generated) |
| Function uses `XRef ref` | Function uses `Ref ref` |
| `.valueOrNull` | `.value` (returns null on error in 3.x) |
| `AutoDisposeNotifier<T>` | `Notifier<T>` (interfaces fused) |
| `FamilyNotifier<T, Arg>` | `Notifier<T>` + parameter on `build()` |
| `provider.stream` | `ref.listen(provider, (_, value) {...})` |
| Direct error catching | Wrap in `ProviderException` check (3.x wraps errors) |

**For detailed migration steps**, read `.claude/refs/riverpod/migration-2x-to-3x.md`.

## `[3.x]` New Features (Reference Only)

These are 3.x-only. If project is on 2.x, do not use:

- **`Mutations`** — UI-friendly side effect status (loading/error/success). For form submissions.
- **`Offline persistence`** — `persist()` inside notifiers, requires `riverpod_sqflite`.
- **`Automatic retry`** — failing providers retry with exponential backoff by default.
- **`Ref.mounted`** — check provider alive after async gap.
- **`Paused providers`** — out-of-view providers automatically paused.
- **`Weak listeners`** — `ref.listen(p, cb, weak: true)`.

**For detailed 3.x features**, read `.claude/refs/riverpod/3x-features.md`.

## Performance Patterns

### `select` for fine-grained rebuilds

```dart
final userName = ref.watch(userProvider.select((u) => u.name));
// Only rebuilds when name changes, not other User fields
```

### keepAlive (when auto-dispose unwanted)

```dart
@Riverpod(keepAlive: true)
ServiceX serviceX(Ref ref) => ServiceX();
```

Use sparingly — defeats memory management.

### selectAsync for async providers

```dart
final firstName = await ref.watch(
  userProvider.selectAsync((u) => u.firstName),
);
```

## Testing Patterns

### `[2.x]`

```dart
final container = ProviderContainer(
  overrides: [
    xRepositoryProvider.overrideWithValue(MockXRepository()),
  ],
);
addTearDown(container.dispose);
```

### `[3.x]`

```dart
// New ProviderContainer.test() auto-disposes
final container = ProviderContainer.test(
  overrides: [
    xRepositoryProvider.overrideWithValue(MockXRepository()),
  ],
);
// No addTearDown needed
```

Use `mocktail` for mocks (both versions).

## Common Bugs (Both Versions)

- **Infinite rebuild loop:** `ref.watch` in `build()` for a provider you also write to. Use `ref.read` for writes.
- **Stale closure:** capturing `ref` in callback that outlives the build. Use `ref.read` inside the callback.
- **Build side effects:** any `Future` call, dialog, snackbar, navigation in `build()` fires on every rebuild. Move to `ref.listen` or notifier method.
- **Family param identity:** passing `List`/`Map` to family without stable `==` creates new instances each time.

### `[3.x]` Additional bug

- **Ref usage after async gap:** `ref` may be invalid after `await`. Check `ref.mounted` first (3.x only).

## Anti-Patterns to Reject (Both Versions)

| Anti-pattern | Replace with |
|---|---|
| Initializing providers from widget (e.g. `initState` calling `ref.read(provider).init()`) | Provider initializes itself in `build()` |
| Using providers for ephemeral state (form state, animations, controllers) | Use `flutter_hooks` or `StatefulWidget` local state |
| Side effects in provider build (HTTP write, navigate) | `ref.listen` or notifier method, not `build()` |
| `dynamic` provider types | Concrete types |
| Dynamically created providers in classes | Top-level `final` providers only |
| Mutating list/map in place | Create new instance (Riverpod uses `==` to filter updates) |
| Using `ref.read` to avoid rebuilds | Use `select` instead — `ref.watch(p.select((s) => s.field))` |

## When to Verify Against Docs

Before implementing a pattern you're unsure about, fetch the relevant page from https://riverpod.dev/docs/ via web_fetch. Especially for: `keepAlive`, family with multiple params, Mutations, Offline persistence, retry config, async lifecycle in 3.x.

## When in Doubt

- Check CLAUDE.md `[CURRENT]` markers for project's version
- Look at neighboring conforming features for established patterns
- Match the project's style — don't impose generic Riverpod patterns
- Flag deviations from project conventions in your response
