---
name: flutter-environments
description: Use whenever Claude works with Flutter build flavors, environment configuration, dev/staging/production setups, --dart-define flags, Firebase configs per environment, or build/run commands for specific flavors. Triggers on "build staging APK", "run on production", "set up flavor", "switch to dev environment", and flavor configuration files.
---

# Flutter Environments & Flavors

Standard pattern: Flutter flavors + `--dart-define=FLAVOR=...` + per-flavor Firebase configs.

## Naming Convention

| Flavor | Suggested Android ID | Suggested iOS Bundle ID | Display Name |
|---|---|---|---|
| `production` | `com.company.app` | `com.company.app` | App Name |
| `staging` | `com.company.app.stage` | `com.company.app.stage` | App Name Stage |
| `dev` (optional) | `com.company.app.dev` | `com.company.app.dev` | App Name Dev |

All flavors can install side-by-side on the same device.

## Build & Run Commands

Replace `<flavor>` with `production`, `staging`, or `dev`.

```bash
# Run on device
flutter run --flavor <flavor> --dart-define=FLAVOR=<flavor>

# Build APK
flutter build apk --flavor <flavor> --dart-define=FLAVOR=<flavor>

# Build App Bundle (Play Store)
flutter build appbundle --flavor <flavor> --dart-define=FLAVOR=<flavor>

# Build iOS (requires Xcode for IPA)
flutter build ios --flavor <flavor> --dart-define=FLAVOR=<flavor>
```

If `FLAVOR` is omitted, default to `production` in app code.

## Reading FLAVOR in Dart

```dart
const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'production');

enum ApiMode { staticProd, staticStag, staticDev }

ApiMode get apiMode {
  switch (flavor) {
    case 'staging': return ApiMode.staticStag;
    case 'dev': return ApiMode.staticDev;
    default: return ApiMode.staticProd;
  }
}
```

## Firebase Per-Flavor Setup

### Install FlutterFire CLI (one-time)

```bash
dart pub global activate flutterfire_cli
```

### Configure a new flavor (REQUIRES APPROVAL — touches android/ and ios/)

Before running `flutterfire configure`, get explicit user approval — this command modifies `android/` and `ios/` directories, which are typically gated.

```bash
flutterfire configure \
  --project=<firebase-project-id> \
  --android-package-name=<android-id> \
  --ios-bundle-id=<ios-bundle-id> \
  --out=lib/firebase_options_<flavor>.dart
```

Manually move generated files:
- `google-services.json` → `android/app/src/<flavor>/google-services.json`
- `GoogleService-Info.plist` → `ios/Runner/<flavor>/GoogleService-Info.plist`

### Initializing Firebase per flavor

```dart
import 'firebase_options_production.dart' as prod;
import 'firebase_options_staging.dart' as staging;

Future<void> initFirebase() async {
  final options = flavor == 'staging'
      ? staging.DefaultFirebaseOptions.currentPlatform
      : prod.DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: options);
}
```

## Android Flavor Setup

In `android/app/build.gradle`:

```gradle
android {
    flavorDimensions "env"
    productFlavors {
        production {
            dimension "env"
            applicationId "com.company.app"
            resValue "string", "app_name", "App Name"
        }
        staging {
            dimension "env"
            applicationId "com.company.app.stage"
            resValue "string", "app_name", "App Name Stage"
        }
    }
}
```

## iOS Flavor Setup

In Xcode: create schemes for each flavor (Product → Scheme → Manage Schemes → Duplicate). Each scheme sets a different bundle ID via build configuration. Modifying `ios/` requires explicit user approval.

## Approval Gates

These commands modify gated directories and require explicit user approval before running:

- `flutterfire configure` (modifies `android/`, `ios/`)
- Editing `android/app/build.gradle`
- Editing `ios/Runner.xcodeproj/`
- Modifying scheme files in `ios/Runner.xcworkspace/`

Build and run commands (`flutter build`, `flutter run`) do not need approval — they're read-only on the project.
