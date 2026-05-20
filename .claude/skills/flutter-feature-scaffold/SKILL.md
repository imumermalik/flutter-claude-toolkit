---
name: flutter-feature-scaffold
description: Use when the user wants to create a new Flutter feature from an API. Triggers on "scaffold a feature", "create feature for this API", "build a DDP slice for", a pasted JSON response, a pasted cURL command, an OpenAPI/Swagger spec snippet, or any request that turns a backend endpoint into a working data → domain → presentation layer. Inspects the project for established patterns before generating, then produces all required files following the project's exact conventions.
---

# Flutter Feature Scaffold

Generates a complete DDP slice (data → domain → presentation) from an API specification. Output matches the project's established patterns — not generic textbook patterns.

## Inputs Accepted

Any of:
- **Raw JSON response** — Claude infers field types and nullability
- **cURL command + sample response** — gives request shape too (headers, query params, body)
- **OpenAPI / Swagger snippet** — most structured, best for multi-endpoint features
- **Plain English description** — last resort; will require more clarifying questions

If input is ambiguous, ask ONE targeted question (not a barrage):
- "Is this endpoint authenticated? What token type?"
- "Should this be paginated?"
- "Is the response list filtered server-side or client-side?"

## Pre-Scaffold Discovery (MANDATORY)

Before generating any file, inspect the project. This is non-negotiable — patterns vary across projects and within projects.

### Step 1: Read CLAUDE.md
If `CLAUDE.md` exists at project root, read it. Pay attention to `[CURRENT]` vs `[TARGET]` markers (if present) — generate code matching CURRENT for the existing codebase, TARGET only if explicitly instructed.

### Step 2: Find a similar feature
Pick a conforming feature from `lib/features/` that resembles the one being built (same data shape — list, single object, paginated, streamed). Read 2-3 files from it:
- The repository abstract
- The repository implementation
- One usecase
- The async notifier

### Step 3: Note these specifics
- **Folder naming:** `repository/` vs `repositories/`, `datasource/` vs `source/remote/`, `dto/` vs `rest_model/`
- **File suffix:** `_imp.dart` vs `_impl.dart`
- **Model approach:** hand-written classes vs `@freezed`
- **Provider style:** `@riverpod` codegen vs manual `Provider<>` vs `StateNotifier`
- **Usecase base class:** does it use `Usecase<Input, Output>` from `lib/infrastructure/`? Do Input/Output extend `Input`/`Output` base classes?
- **Autogen markers:** does the project use `////********** START X **********////` comment blocks? Where?
- **DI:** `@LazySingleton(as: ...)` annotation? `sl<>` resolver?
- **Helpers available:** `HttpNetworkCallHelper`, `PersistenceHelper`, `SecureStorageHelper`, etc.

**Match these exactly.** Do not impose generic conventions when the project has its own.

## Generation Order

Generate files in this order. Each layer builds on the previous.

### 1. REST DTO (data layer)
`lib/features/<feature>/data/<rest_model_folder>/rest_<feature>_model.dart`

- Mirrors the API JSON exactly
- `fromJson` / `toJson` if needed
- `toEntity()` mapper returning the domain entity
- Uses project's serialization approach (hand-written, `@JsonSerializable`, or `@freezed`)

### 2. Domain Entity (domain layer)
`lib/features/<feature>/domain/entities/<feature>_entity.dart`

- Pure Dart, no Flutter, no Riverpod
- Immutable (final fields)
- Equality (manual `==`/`hashCode`, `equatable`, or `@freezed`)
- Field names use domain language, not API language (e.g., `isRead` not `is_read`)

### 3. Datasource Abstract (domain layer — per project convention)
Project-specific path. Common locations:
- `domain/data/<feature>_remote_datasource.dart` (Apployee convention)
- `domain/datasources/<feature>_datasource.dart` (some projects)

- Abstract class
- Methods return domain entities (not DTOs)
- Method names match repository methods

### 4. Datasource Implementation (data layer)
`lib/features/<feature>/data/source/remote/<feature>_remote_datasource_imp.dart`
(or `data/datasource/` per project convention)

- `@LazySingleton(as: <Feature>RemoteDataSource)`
- Depends on `HttpNetworkCallHelper` (or project's network helper) — NEVER imports `http` directly
- Parses DTOs, returns entities via `.toEntity()`
- Wraps package exceptions into project exceptions from `lib/util/exceptions/`

### 5. Usecase Input / Output / Class (domain layer)
`lib/features/<feature>/domain/usecases/<verb>_<feature>.dart`

- `<Verb><Feature>UsecaseInput extends Input` — required fields only
- `<Verb><Feature>UsecaseOutput extends Output` — what the usecase returns
- `<Verb><Feature>Usecase extends Usecase<Input, Output>` — `@lazySingleton`, constructor takes repository

### 6. Repository Abstract (domain layer)
`lib/features/<feature>/domain/repository/<feature>_repository.dart`

- Extends project's base `Repository` class if one exists
- Includes autogen markers if project uses them
- Method signatures take Usecase Inputs, return Usecase Outputs
- Doc comments above each method describing Input/Output

### 7. Repository Implementation (data layer)
`lib/features/<feature>/data/repository/<feature>_repository_imp.dart`

- `@LazySingleton(as: <Feature>Repository)`
- Private datasource field with `_` prefix
- Constructor injection via named required params
- Methods delegate to datasource one-to-one
- Includes autogen markers if project uses them

### 8. Riverpod Provider (presentation layer)
`lib/features/<feature>/presentation/providers/<verb>_<feature>/<verb>_<feature>_provider.dart`

- `@riverpod` codegen (preferred) OR project's actual style
- `_fetch<Feature>()` private method separate from `build()`
- Resolves usecase via `sl<>` (GetIt)
- Reads dependencies (e.g., bearer token) via `ref.read(provider.future)` for async
- `refresh()` method using `AsyncValue.guard`

### 9. View (optional — only if design provided)
Default: do NOT generate a view. Stop at the provider.

If a design (image, Figma URL, screenshot) is provided in the same conversation, generate:
- `presentation/views/mobile/mobile_<feature>_view.dart` — `ConsumerWidget`
- `presentation/views/tablet/tablet_<feature>_view.dart` — if project has tablet variants
- Theme-aware (uses project colors), `flutter_screenutil` for sizing, `context.appLocale` for strings

### 10. Routing & Localization (cross-cutting edits)

List as a separate "Files to Edit" section:
- `lib/util/router/paths.dart` — add route constant
- `lib/util/router/router.dart` — register route
- `lib/util/router/tablet_router.dart` — if tablet view created
- `lib/l10n/*.arb` — add localized strings

**These are edits to existing files. Show the user the diff before applying.**

## After Generation

1. Show the user: list of files created, list of files to edit
2. Wait for approval if the change spans more than 3 files (CLAUDE.md approval gate)
3. After approval, run:
   - `dart run build_runner build --delete-conflicting-outputs` (registers DI + generates `*.g.dart`)
   - `flutter analyze` (zero warnings)
4. Report results

## What NOT to Generate

- Tests — that's the `flutter-testing` skill's job. Mention test scaffolding is available as a follow-up.
- Mocks for the new repo unless tests are also being scaffolded
- The view if no design was provided
- "Future-proofing" code (extra fields the user didn't ask for, "just in case" methods)
- Documentation files (README, .md) unless explicitly requested

## Handling Edge Cases

- **No `lib/infrastructure/usecase.dart` exists:** project doesn't use a base Usecase class. Generate without it, but flag this so the user knows.
- **No conforming sibling feature to copy from:** ask the user which feature to model after. Don't guess.
- **API requires auth but no `bearerTokenProvider` exists:** ask the user where the token comes from.
- **Pagination not specified:** ask once — "Is the response paginated? If yes, page-based or cursor-based?"
- **Mixed conventions in the project (some `_imp.dart`, some `_impl.dart`):** ask which the user prefers for new code.

## Output Format for the User

After generation, present this summary:

```
Scaffolded the <feature> feature.

Files created (N):
- lib/features/<feature>/data/<rest_model>/rest_<feature>_model.dart
- lib/features/<feature>/domain/entities/<feature>_entity.dart
- ... etc

Files to edit (manually or with approval) (M):
- lib/util/router/paths.dart — add route constant
- ... etc

Next steps:
1. Run: dart run build_runner build --delete-conflicting-outputs
2. Run: flutter analyze
3. Want tests scaffolded? I can run the flutter-testing skill next.
```

## When in Doubt

Inspect 2-3 conforming sibling features before generating. If the project's pattern conflicts with what CLAUDE.md states, follow the project's actual pattern and flag the inconsistency to the user.
