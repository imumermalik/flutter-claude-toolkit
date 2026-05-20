---
name: flutter-riverpod
description: Use whenever Claude works with Riverpod providers, notifiers, ref.watch/read/listen, or state management in Flutter. Triggers on creating new providers, modifying state logic, migrating from Riverpod 2.x StateNotifier to 3.x Notifier, async data fetching with AsyncNotifier, family providers, autoDispose/keepAlive, and provider testing. Enforces @riverpod codegen style and AsyncValue patterns.
---

# Flutter Riverpod Patterns

For Riverpod 3.x with `@riverpod` codegen. Authoritative source: https://riverpod.dev — fetch the docs page when in doubt. If your memory disagrees with the docs, docs win.

## Provider Type Decision

| Need | Use |
|---|---|
| Plain value, no state | `@riverpod` function returning value |
| One-shot Future | `@riverpod` function returning `Future<T>` |
| Stream | `@riverpod` function returning `Stream<T>` |
| Mutable state, sync | `@riverpod class X extends _$X { T build() }` |
| Mutable state, async (fetch on init) | `@riverpod class X extends _$X { Future<T> build() }` |
| Per-parameter cache | Add params to `build()` (auto-becomes family) |

Default to `@riverpod` annotation. Do not write manual `Provider.autoDispose<>` syntax for new code.

## Ref Method Rules

| Method | Use in | Purpose |
|---|---|---|
| `ref.watch(p)` | `build()` only | Rebuild when `p` changes |
| `ref.read(p)` | Action methods (event handlers) | One-time read, no subscription |
| `ref.listen(p, cb)` | `build()` only | Side effects — navigation, dialogs, snackbars |
| `ref.read(p.notifier)` | Action methods | Get notifier to call methods |

**Side effects (navigation, showDialog, snackbar) ALWAYS in `ref.listen`, never in `build()`.**

## Standard AsyncNotifier Pattern (matches existing project style)

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

Key rules:
- Private `_fetchX()` separates fetch logic from `build()`
- Resolve usecases via `sl<>` (GetIt) inside notifier
- Read other providers via `ref.read(p.future)` for async, `ref.read(p)` for sync
- Refresh methods use `AsyncValue.guard` for error handling
- Never mutate state in place — assign new `AsyncValue`

## Riverpod 2.x → 3.x Migration

| 2.x | 3.x |
|---|---|
| `class X extends StateNotifier<T>` | `@riverpod class X extends _$X` |
| `StateNotifierProvider<X, T>` | `xProvider` (auto-generated) |
| `state = newValue` | `state = newValue` (same, but inside generated class) |
| Manual `Provider<X>((ref) => X())` | `@riverpod X x(XRef ref) => X()` |
| `.family` modifier | Add parameters to `build()` |
| `.autoDispose` modifier | Default in `@riverpod`. Use `@Riverpod(keepAlive: true)` to override |

**Migration mode:**
- **`lib/features/auth/`** — refuse to migrate ambiguous cases. Ask user for guidance.
- **Other features** — make reasonable choice, document with `// MIGRATED: ...` comment, get user approval before applying.

## Performance Patterns

- `ref.watch(p.select((s) => s.field))` — rebuild only when `field` changes
- `@Riverpod(keepAlive: true)` — survive across navigation (use sparingly; memory)
- Family providers (params on `build()`) — each unique param creates a separate provider instance. Be aware of memory.

## Common Bugs

- **Infinite rebuild loop:** `ref.watch` in `build()` for a provider you also write to. Use `ref.read` for writes.
- **Stale closure:** capturing `ref` in a callback that outlives the build. Use `ref.read` inside the callback, not captured state.
- **Ref usage after async gap:** `ref` may be invalid after `await`. Check `ref.mounted` first (3.x).
- **Build side effects:** any `Future` call, dialog, snackbar, navigation in `build()` will fire on every rebuild. Move to `ref.listen` or notifier method.

## Testing Providers

```dart
final container = ProviderContainer(
  overrides: [
    xRepositoryProvider.overrideWithValue(MockXRepository()),
  ],
);
addTearDown(container.dispose);

final value = await container.read(xProvider.future);
expect(value, ...);
```

Use `mocktail` for mocking. Always `addTearDown(container.dispose)`.

## When to Verify Against Docs

Before implementing a Riverpod pattern you're unsure about, fetch the relevant page from https://riverpod.dev/docs/ via web_fetch. Cite the URL. Especially for: `keepAlive`, family with multiple params, `ref.mounted`, `notifyListeners` analogs, async lifecycle.
