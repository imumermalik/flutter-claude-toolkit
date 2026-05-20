---
name: flutter-architecture
description: Use whenever Claude writes, edits, or reviews any .dart file in a Flutter project. Enforces DDP (Data/Domain/Presentation) layered architecture, OOP, SOLID, DRY, immutability, and the helper-abstraction rule for external packages. Triggers on every Dart/Flutter code task — adding widgets, modifying notifiers, fixing analyzer warnings, refactoring features, reviewing code.
---

# Flutter DDP Architecture

Authoritative rules. Apply on every Dart/Flutter code task.

## Layer Rules

| Layer | May import | May NOT import |
|-------|-----------|----------------|
| Domain | Pure Dart, `freezed_annotation`, `equatable`, `injectable` | Flutter, Riverpod, HTTP, storage packages, presentation code |
| Data | Domain (same feature), helpers, DTOs, `json_annotation`, `freezed_annotation`, `injectable` | Flutter widgets, Riverpod, presentation layer |
| Presentation | Domain (same feature), `flutter`, `flutter_riverpod`, `riverpod_annotation`, common widgets | Data layer directly (always via providers + usecases) |

If you want to import "up" the layers, the design is wrong. Stop and flag it.

## Folder Convention (project may vary — check existing structure first)

```
lib/features/<feature>/
├── domain/
│   ├── usecases/         # <action>.dart per usecase
│   ├── repository/       # abstract repository (singular folder)
│   ├── data/             # abstract datasource interfaces (project-specific)
│   └── entities/         # domain models (Freezed)
├── data/
│   ├── repository/       # *_repository_imp.dart with @LazySingleton(as: ...)
│   ├── datasource/       # *_remote_datasource_imp.dart
│   └── dto/              # DTOs with json_annotation
└── presentation/
    ├── providers/        # @riverpod notifiers and providers
    ├── views/            # ConsumerWidget screens
    └── widgets/          # feature-specific widgets
```

Always inspect existing features in `lib/features/` before scaffolding. Match their structure exactly.

## Usecase Pattern

Every usecase declares its own `Input` and `Output` classes, extends `Usecase<Input, Output>`, takes a repository via constructor injection, and is `@lazySingleton`. The base classes (`Usecase`, `Input`, `Output`) live in `lib/infrastructure/`.

Example shape:
```dart
class GetXUsecaseInput extends Input { /* fields */ }
class GetXUsecaseOutput extends Output { /* fields */ }

@lazySingleton
class GetXUsecase extends Usecase<GetXUsecaseInput, GetXUsecaseOutput> {
  final XRepository _repository;
  GetXUsecase({required XRepository repository}) : _repository = repository;

  @override
  Future<GetXUsecaseOutput> call(GetXUsecaseInput input) async {
    return await _repository.getX(input);
  }
}
```

## Helper Abstraction Rule (MANDATORY)

Every external package that does I/O, holds state, or talks to OS/network/filesystem MUST be wrapped behind a helper. Non-negotiable.

```
lib/helpers/<capability>/
├── <capability>_helper.dart       # abstract interface — zero package imports
├── <capability>_helper_impl.dart  # @LazySingleton(as: <Capability>Helper)
└── exceptions/                    # if capability-specific exceptions are needed
```

**Exceptions** (may be used directly): Flutter SDK, `flutter_riverpod`, `riverpod_annotation`, `freezed_annotation`, `json_annotation`, `intl`, `equatable`, pure data libs.

## OOP, SOLID, DRY (Mandatory)

- **SRP:** One class, one responsibility. If a class description has "and", split it.
- **OCP:** Extend via new classes, not by modifying stable ones.
- **LSP:** Implementations don't add new exceptions or stricter preconditions than the interface.
- **ISP:** Small focused interfaces. A datasource for X doesn't expose Y methods.
- **DIP:** Domain defines abstractions. Data implements. UI depends on abstractions only.
- **Encapsulation:** Private fields with `_` prefix. No mutable public fields.
- **Immutability:** Models use `@freezed`. Mutate by creating new instances.
- **Composition over inheritance.**
- **Tell, don't ask:** `notifier.toggleX(id)` — not "read state, decide, call different methods".

## Anti-Patterns to Reject

| Anti-pattern | Replace with |
|---|---|
| `setState` for app-wide state | Riverpod notifier |
| Building widgets in private helper methods inside `build()` | Extract to a `const`-able widget class |
| `ref.read(provider)` inside `build()` | `ref.watch(provider)` |
| Direct `http`/`dio`/`firebase_*` import in features | Helper interface from `lib/helpers/` |
| Hard-coded colors or strings in views | Theme colors / localization |
| Magic numbers in UI sizing | `flutter_screenutil` (`.sp`, `.h`, `.w`) |
| `dynamic` in production code | Concrete types |
| Logic in `initState` for data fetching | Call notifier method via `ref.read(provider.notifier).method()` |
| Mutating list/map in place | Create new instance (Riverpod needs new refs to rebuild) |
| Logic inside widget `build()` method | Move to notifier |

## Required Post-Change Workflow

After ANY code change, run in this order. Report results before declaring done:

1. `dart run build_runner build --delete-conflicting-outputs` — if `@riverpod`, `@injectable`, or `@freezed` annotations changed
2. `flutter analyze` — must have zero errors/warnings
3. `flutter test` — all tests must pass

Failures must be fixed before continuing.

## When in Doubt

- Look at neighboring features in `lib/features/` for established patterns
- Check the project's CLAUDE.md for project-specific overrides
- Flag deviations in your response — do not silently invent new patterns
