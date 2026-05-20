# Riverpod 3.x New Features Reference

**Loaded by:** `flutter-riverpod` skill when the project is on 3.x AND a specific 3.x feature is requested.
**Source:** https://riverpod.dev/docs/whats_new (verified Feb 2026 — latest stable 3.3.1)

This is a focused reference for 3.x-only features. Do not use these patterns on 2.x projects.

---

## 1. Mutations (Experimental)

**Purpose:** UI-friendly side effect status tracking. Replaces ad-hoc loading/error state in providers for actions like form submissions.

> ⚠️ Experimental — API may change without major version bump.

### Defining a mutation

```dart
// Global or static final variable
final addTodoMutation = Mutation<Todo>();
```

### Triggering it

```dart
addTodoMutation.run(ref, (tsx) async {
  final notifier = tsx.get(todoListProvider.notifier);
  return await notifier.addTodo('New Todo');
});
```

### Listening in UI

```dart
final addTodoState = ref.watch(addTodoMutation);

return switch (addTodoState) {
  MutationIdle() => ElevatedButton(
    onPressed: () => addTodoMutation.run(ref, (tsx) async {...}),
    child: const Text('Submit'),
  ),
  MutationPending() => const CircularProgressIndicator(),
  MutationError() => ElevatedButton(
    onPressed: () => addTodoMutation.run(ref, (tsx) async {...}),
    child: const Text('Retry'),
  ),
  MutationSuccess() => const Text('Done!'),
};
```

### When to use

- Form submissions
- Action buttons that should show loading/error UI
- Side effects that need user feedback

### When NOT to use

- Read operations (use regular providers)
- Internal state changes (use notifier methods)

### Resetting

Mutations auto-reset to `MutationIdle` when:
- All listeners removed
- Manually: `addTodoMutation.reset(ref)`

---

## 2. Offline Persistence (Experimental)

**Purpose:** Cache notifier state to disk, restore on app restart.

> ⚠️ Experimental — API may change.

### Requirements

- A `Storage` implementation (e.g., `riverpod_sqflite`)
- Use only with `Notifier`/`AsyncNotifier`

### Setup

```bash
dart pub add riverpod_sqflite sqflite
```

### Provider for Storage

```dart
@riverpod
Future<Storage<String, String>> storage(Ref ref) async {
  return JsonSqFliteStorage.open(
    join(await getDatabasesPath(), 'riverpod.db'),
  );
}
```

### Persisting a notifier

```dart
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    persist(
      ref.watch(storageProvider.future),
      key: 'todo_list',  // Unique across entire app
      encode: (todos) => todos.map((t) => t.toJson()).toList(),
      decode: (json) => (json as List).map((t) => Todo.fromJson(t)).toList(),
    );

    return fetchTodosFromServer();
  }
}
```

### With `@JsonPersist` (simpler, requires `freezed` + `json_serializable`)

```dart
@riverpod
@JsonPersist()
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    persist(ref.watch(storageProvider.future));
    return fetchTodosFromServer();
  }
}
```

### Cache duration

Default: 2 days. Override:

```dart
persist(
  ref.watch(storageProvider.future),
  options: const StorageOptions(
    cacheTime: StorageCacheTime.unsafe_forever,  // Forever
  ),
);
```

### Data migration

Use `destroyKey` to invalidate old data on app version bumps:

```dart
options: const StorageOptions(destroyKey: 'v1.0'),
```

When `destroyKey` changes, old data is wiped.

---

## 3. Automatic Retry

**Purpose:** Failing providers automatically retry with exponential backoff.

### Default behavior

- Up to 10 retries
- Exponential backoff: 200ms → 6.4s
- Skips `Error` and `ProviderException` types

### Custom retry per provider

```dart
Duration? myRetry(int retryCount, Object error) {
  if (retryCount >= 5) return null;
  if (error is ProviderException) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}

@Riverpod(retry: myRetry)
class TodoList extends _$TodoList {
  @override
  List<Todo> build() => [];
}
```

### Custom retry globally

```dart
ProviderScope(
  retry: (retryCount, error) {
    if (error is SomeSpecificError) return null;
    if (retryCount > 5) return null;
    return Duration(seconds: retryCount * 2);
  },
  child: MyApp(),
);
```

### Disable retry globally

```dart
ProviderScope(
  retry: (retryCount, error) => null,
  child: MyApp(),
);
```

### Watching during retry

```dart
final value = await ref.watch(provider.future);
// Future waits for either: all retries exhausted, or success
```

---

## 4. Ref.mounted

**Purpose:** Check if provider still alive after async operation (similar to `BuildContext.mounted`).

### Use case

```dart
@riverpod
class TodoList extends _$TodoList {
  @override
  List<Todo> build() => [];

  Future<void> addTodo(String title) async {
    final newTodo = await api.addTodo(title);
    if (!ref.mounted) return;  // Provider was disposed during await
    state = [...state, newTodo];
  }
}
```

### Why needed

In 3.x, providers can be disposed mid-operation (especially with `autoDispose`). Without `ref.mounted` check, you'd hit "ref used after dispose" errors.

---

## 5. Paused Providers

**Behavior change in 3.x:** Out-of-view providers automatically pause.

### What this means

- If a widget showing provider A is not visible (e.g., on different route)
- Provider A's `ref.listen` callbacks are paused
- Streams attached to it pause
- This saves resources

### Concrete example

Home page listens to a websocket via `wsProvider`. User opens Settings page. Home page still in tree but not visible.

In 2.x: websocket stays active, consuming data
In 3.x: websocket paused until home becomes visible again

### Controlling pause behavior

Use `TickerMode` to override:

```dart
TickerMode(
  enabled: true,  // Force-resume listeners
  child: Consumer(
    builder: (context, ref, _) {
      final value = ref.watch(myProvider);
      return Text(value.toString());
    },
  ),
);
```

### When this matters for Apployee

- Support chat (`SocketService`) — verify it still works when user navigates away and back
- Background data refreshes — may pause more aggressively than before
- Test thoroughly after 3.x upgrade

---

## 6. Weak Listeners

**Purpose:** Listen to a provider without keeping it alive.

```dart
ref.listen(
  anotherProvider,
  weak: true,  // Provider can still auto-dispose
  (previous, next) {...},
);
```

### Use case

You want to react to changes in provider A from provider B, but don't want B to keep A alive. Useful for cross-feature event propagation.

---

## 7. Generic Providers (Codegen-only)

```dart
@riverpod
T multiply<T extends num>(Ref ref, T a, T b) {
  return a * b;
}

// Usage:
int integer = ref.watch(multiplyProvider<int>(2, 3));
double decimal = ref.watch(multiplyProvider<double>(2.5, 3.5));
```

---

## 8. New Testing Utilities

### `ProviderContainer.test()`

Auto-disposes after the test. Replaces manual `addTearDown(container.dispose)`:

```dart
test('Some test', () {
  final container = ProviderContainer.test(
    overrides: [
      myProvider.overrideWithValue(42),
    ],
  );
  // No manual cleanup needed
});
```

### `NotifierProvider.overrideWithBuild`

Mock only the `build` method, keep notifier's other methods working:

```dart
final container = ProviderContainer.test(
  overrides: [
    myProvider.overrideWithBuild((ref, self) => 42),
    // .increment() etc. still work normally
  ],
);
```

### `Future/StreamProvider.overrideWithValue` (back!)

```dart
overrides: [
  myFutureProvider.overrideWithValue(AsyncValue.data(42)),
]
```

### `WidgetTester.container`

```dart
testWidgets('test', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: MyWidget()));
  ProviderContainer container = tester.container();
  // Use container to interact with providers
});
```

---

## 9. AsyncValue Changes

### `.value` now nullable

```dart
// 2.x — threw on error
final value = ref.watch(provider).value;  // throws if error

// 3.x — returns null on error
final value = ref.watch(provider).value;  // null if loading/error
if (value != null) { ... }
```

### `AsyncValue.requireValue` for definite values

```dart
// Throws clearly if not data — use when you've already handled loading/error
final value = ref.watch(provider).requireValue;
```

### `AsyncValue.isFromCache`

Set when value loaded from offline persistence (vs server).

### `AsyncValue.retrying`

True when an automatic retry is scheduled or in progress.

### `AsyncLoading.progress`

Optional progress (0.0–1.0) for custom progress UI:

```dart
state = AsyncLoading(progress: 0.5);
```

### Pattern matching (sealed)

```dart
switch (asyncValue) {
  case AsyncData(:final value): ...
  case AsyncError(:final error): ...
  case AsyncLoading(): ...
  // No default needed — sealed
}
```

---

## 10. ProviderException Wrapping

In 3.x, all provider errors are wrapped in `ProviderException`:

```dart
try {
  await ref.read(myProvider.future);
} on ProviderException catch (e) {
  if (e.exception is NotFoundException) {
    // Handle NotFoundException
  }
} catch (e) {
  // Other errors
}
```

**Note:** `AsyncValue.error`, `ref.listen(..., onError: ...)`, and `ProviderObservers` receive the original error, not the wrapper.

---

## 11. ProviderObserver Changes

The interface changed. Methods now take `ProviderObserverContext`:

```dart
class MyObserver extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderObserverContext context,  // was: ProviderBase provider, Object? value, ProviderContainer container
    Object? value,
  ) {
    // context.container, context.provider, context.mutation all available
  }
}
```

---

## When to Use 3.x Features

| Feature | Recommended When |
|---|---|
| Mutations | Forms, buttons with side effects, UI needs loading/error |
| Offline persistence | Truly need offline mode (chat, drafts, settings cache) |
| Automatic retry | Network-heavy apps (Apployee qualifies) |
| Ref.mounted | All providers with async work + autoDispose |
| Weak listeners | Cross-feature event propagation |
| Generic providers | Truly generic data structures (rare) |
| ProviderContainer.test | All tests (replaces createContainer pattern) |

## When NOT to Use 3.x Features

- For 2.x projects (obviously)
- For simple read-only data flows (regular `@riverpod` is enough)
- For experimental features in critical paths (Mutations, Offline) — wait for stable releases

---

## Verification Before Using

Before using any 3.x feature, verify against latest docs:
- https://riverpod.dev/docs/whats_new
- https://riverpod.dev/docs (specific feature page)

API may change in 3.x dev releases. Stable APIs are clearly marked in docs.
