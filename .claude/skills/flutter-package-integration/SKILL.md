---
name: flutter-package-integration
description: Use whenever the user wants to add, upgrade, or replace a Flutter/Dart package. Triggers on "add package X", "I need a library for Y", "pubspec mein X chahiye", pubspec.yaml edits, "find a package for", or any mention of installing a third-party dependency. Enforces a vetting workflow, requires explicit user approval, and ensures the package is wrapped in a helper interface before any feature code consumes it.
---

# Flutter Package Integration

Adding a package is a high-impact decision. Every package becomes a long-term dependency, a potential security surface, and a maintenance burden. This skill enforces the project's package policy.

## Approval Gate (MANDATORY)

NEVER add a package to `pubspec.yaml` without explicit user approval. Always:

1. Present the vetting analysis (template below)
2. Wait for explicit user confirmation (`yes`, `approved`, `proceed`)
3. Only then run `flutter pub add` or edit `pubspec.yaml`

Do not skip this gate even if the user says "just add it" — show the analysis first, then await confirmation.

## Package Selection Priority

1. **Flutter Favorites** — https://pub.dev/packages?q=is%3Aflutter-favorite
2. **Verified publishers** — Google, Flutter team, Dart team, well-known orgs
3. **Community packages** meeting all of:
   - Pub points ≥ 130
   - Popularity ≥ 90%
   - Last updated within 6 months
   - Null-safety: yes
   - Dart 3 compatible: yes
   - Active issue tracker

## Vetting Analysis Template

Before requesting approval, fetch the package's pub.dev page via `web_fetch` and present this analysis:

```
Package: <name> @ <version>
pub.dev URL: <url>
Flutter Favorite: yes/no
Verified publisher: yes/no — <publisher>
Pub points: X / 160
Popularity: X%
Likes: X
Last updated: <date>
Null safety: yes/no
Dart 3 compatible: yes/no
Compatible with project's Flutter version: confirmed yes/no
Open issues / activity: <one-line summary>
License: <type>
Transitive dependencies of concern: <list, or "none">

Alternatives considered:
- <alt 1>: <why not chosen>
- <alt 2>: <why not chosen>

Why we need it (one paragraph): <use case>

Recommendation: <approve / suggest alternative / do not add>
```

If the package is not in the top quartile of pub.dev scores, explicitly call this out and suggest alternatives.

## Required Implementation Order

After approval, the FIRST file written is the helper interface — not feature code that uses the package.

### Step 1: Add the package

```bash
flutter pub add <package-name>
```

### Step 2: Create the helper interface

```
lib/helpers/<capability>/<capability>_helper.dart
```

Rules:
- ZERO imports from the wrapped package
- Method signatures use Dart primitives or project domain types
- No package types leak through the API
- Documented exceptions list (which exceptions the impl can throw)

### Step 3: Create the helper implementation

```
lib/helpers/<capability>/<capability>_helper_impl.dart
```

Rules:
- `@LazySingleton(as: <Capability>Helper)` annotation
- Package-specific exceptions caught here and rethrown as project exceptions from `lib/util/exceptions/`
- No state leakage — the helper either holds state intentionally or is stateless

### Step 4: Capability-specific exceptions (if needed)

```
lib/helpers/<capability>/exceptions/<name>_exception.dart
```

Extend the project's base exception class.

### Step 5: Run code generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

This registers the helper in `di.config.dart`.

### Step 6: Verify

```bash
flutter analyze
```

Zero errors/warnings before declaring done.

### Step 7: ONLY NOW — feature code may use the helper

Feature code imports the abstract interface (`<capability>_helper.dart`), never the impl, never the package directly.

## What CAN'T Be Used Directly (must be wrapped)

Anything that does I/O, holds state, or talks to OS / network / filesystem / hardware. Examples:

- HTTP clients (`http`, `dio`, `chopper`)
- Storage (`shared_preferences`, `flutter_secure_storage`, `hive`, `sqflite`, `isar`)
- Firebase (`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`)
- Permissions (`permission_handler`)
- Sensors / hardware (`camera`, `geolocator`, `local_auth`, `sensors_plus`)
- WebSockets / real-time (`socket_io_client`, `web_socket_channel`)
- Background work (`workmanager`, `flutter_background_service`)
- Health / fitness SDKs (`health`, Spike SDK)
- Notifications (`flutter_local_notifications`)
- Image / file pickers (`image_picker`, `file_picker`)
- Media (`video_player`, `audioplayers`, `just_audio`)

## What May Be Used Directly (exception list)

Framework primitives and pure-data libraries with no I/O or state:

- `flutter` SDK itself
- `flutter_riverpod`, `riverpod_annotation`, `hooks_riverpod`
- `freezed_annotation`, `json_annotation`
- `intl`, `equatable`, `collection`, `meta`
- Pure data libs (`decimal`, `crypto` for hashing — not for storage)
- Dev/build tools (`build_runner`, `freezed`, `json_serializable`, `injectable_generator`)

## When the User Asks "Find Me a Package for X"

Don't pick blindly. Workflow:

1. **Clarify the requirement** — one targeted question if needed (e.g., "Does this need offline support?")
2. **Search pub.dev** via `web_fetch` for the category
3. **Identify 2-3 candidates**
4. **Present a comparison table**:

| Package | Pub Points | Popularity | Last Update | Notes |
|---|---|---|---|---|
| <a> | X | Y% | <date> | <one-line> |
| <b> | X | Y% | <date> | <one-line> |
| <c> | X | Y% | <date> | <one-line> |

5. **Recommend one** with reasoning
6. **Then proceed to the full vetting template** for the chosen one

## Refusing to Add a Package

Decline (with explanation) when:

- The package is unmaintained (>12 months since update) and no fork exists
- A built-in solution exists (e.g., `dart:io` covers it)
- The dependency cost is disproportionate to the use case (10-line task wrapping a 50KB package)
- License is restrictive (GPL in a closed-source app)
- The package overlaps with one already in `pubspec.yaml`

Suggest the alternative path, don't just refuse.

## Verification Against Docs

Before recommending a package, verify the latest version and breaking changes on its pub.dev `/changelog` page via `web_fetch`. Memory may be outdated.
