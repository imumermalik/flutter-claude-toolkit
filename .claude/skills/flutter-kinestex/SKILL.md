---
name: flutter-kinestex
description: Use whenever Claude works with the KinesteX AI motion-tracking SDK in Flutter — integrating workouts, plans, challenges, AI experiences, camera component, custom workouts, admin editor, fetching content via the Content API, handling PostMessage events (reps, mistakes, workout_overview, etc.), customizing UI/theme/language, or wrapping any of this in Riverpod/DDP patterns. Triggers on KinesteX, motion tracking, pose detection, fitness SDK, workout integration, exercise tracking, Camera Component, or kinestex_sdk_flutter package work.
---

# Flutter KinesteX SDK

Authoritative sources (fetch via web_fetch when in doubt):
- Official docs: https://www.kinestex.com/docs/getting-started
- Pub.dev: https://pub.dev/packages/kinestex_sdk_flutter
- API docs: https://pub.dev/documentation/kinestex_sdk_flutter/latest/kinestex_sdk/
- GitHub: https://github.com/KinesteX/KinesteX-SDK-Flutter
- Latest SDK version: `kinestex_sdk_flutter: ^1.4.7` (Feb 2026)

If memory disagrees with the docs, **docs win**. Versions and APIs change.

## When to Use Which Integration Option

| User goal | Use |
|---|---|
| Show complete fitness experience (let KinesteX handle UX) | **Main View** (`createMainView`) |
| Launch one specific workout | **Workout View** (`createWorkoutView`) |
| Launch a multi-day workout plan | **Plan View** (`createPlanView`) |
| Single-exercise gamified challenge with leaderboard | **Challenge View** (`createChallengeView`) |
| AI games (Balloon Pop, etc.) or clinical assessments (TUG, etc.) | **Experience View** (`createExperienceView`) |
| AI-generated personalized plan from biometrics | **Personalized Plan** (`createPersonalizedPlanView`) |
| Embed admin editor (create/edit workouts in-app) | **Admin Workout Editor** (`createAdminWorkoutEditor`) |
| Custom workout sequence (your own exercise order) | **Custom Workout View** (`createCustomWorkoutView`) |
| Build your own UI, use only motion tracking | **Camera Component** (`createCameraComponent`) |

**Don't default to MainView for everything** — it's the broadest integration, but most apps actually want WorkoutView or ChallengeView for tighter UX control.

For detailed examples of each option (including complete code + customization), read `.claude/refs/kinestex/integration-options.md`.

## Required Setup (Once Per Project)

### 1. pubspec.yaml

```yaml
dependencies:
  kinestex_sdk_flutter: ^1.4.7
  permission_handler: ^11.3.1
```

### 2. iOS — `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for AI-powered workout tracking</string>
<key>NSMotionUsageDescription</key>
<string>Motion sensors help position your device correctly for workouts</string>
```

### 3. iOS — `ios/Podfile`

Add inside `post_install` block:

```ruby
config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
  '$(inherited)',
  'PERMISSION_CAMERA=1',
]
```

Then run `cd ios && pod install`.

### 4. Android — `android/app/src/main/AndroidManifest.xml`

Inside `<manifest>` tag (not inside `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.sensor.accelerometer" android:required="false" />
<uses-feature android:name="android.hardware.sensor.gyroscope" android:required="false" />
```

### 5. Android — minimum API 26

Check `android/app/build.gradle` — `minSdkVersion 26`. KinesteX requires API 26+.

### 6. Initialization (call before `runApp`)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KinesteXAIFramework.initialize(
    apiKey: AppConfig.kinestexApiKey,      // from env/flavor config
    companyName: AppConfig.kinestexCompany, // from env/flavor config
    userId: currentUserId,                  // from auth — min 2 chars
  );
  runApp(const MyApp());
}
```

**Never hardcode the API key in source.** Use flavor configs (`AppConfig.kinestexApiKey`) or `--dart-define`. Apployee already has flavor-based configs; follow that pattern.

### 7. Dispose on app close

In root widget's `dispose()`:

```dart
@override
void dispose() {
  KinesteXAIFramework.dispose();
  super.dispose();
}
```

## Core Pattern (Every Integration Uses This)

KinesteX views are **toggled, not pushed/popped**. Pattern:

```dart
final ValueNotifier<bool> showKinesteX = ValueNotifier<bool>(false);

// In build:
return ValueListenableBuilder<bool>(
  valueListenable: showKinesteX,
  builder: (context, isVisible, _) {
    return isVisible
      ? SafeArea(child: KinesteXAIFramework.createXxxView(...))
      : ScaffoldWithButton(onPressed: () => showKinesteX.value = true);
  },
);
```

**Why a ValueNotifier?** KinesteX needs to observe visibility changes; passing a bare bool would not trigger SDK lifecycle correctly.

**Always wrap in SafeArea** — KinesteX uses full-screen UI and doesn't account for notches.

## Apployee Integration Pattern (Hybrid: Riverpod Wrapper, No Full DDP)

KinesteX is a UI SDK, not a data source. Full DDP (UseCase + Repository + DataSource) is **overkill**. Use this hybrid pattern instead:

### Layer 1: Helper for SDK lifecycle

Create `lib/helpers/kinestex_helper/kinestex_helper.dart`:

```dart
class KinesteXHelper {
  Future<void> initialize() async {
    await KinesteXAIFramework.initialize(
      apiKey: AppConfig.kinestexApiKey,
      companyName: AppConfig.kinestexCompany,
      userId: sl<UserSession>().userId,
    );
  }

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  Future<void> dispose() async {
    await KinesteXAIFramework.dispose();
  }
}
```

Register in `di.dart`: `sl.registerLazySingleton(() => KinesteXHelper());`

### Layer 2: Riverpod provider for visibility/state

```dart
@riverpod
class KinestexSessionController extends _$KinestexSessionController {
  @override
  KinestexSessionState build() => const KinestexSessionState.idle();

  Future<void> startWorkout(String workoutName) async {
    final hasPermission = await sl<KinesteXHelper>().requestCameraPermission();
    if (!hasPermission) {
      state = const KinestexSessionState.permissionDenied();
      return;
    }
    state = KinestexSessionState.active(workoutName: workoutName);
  }

  void completeSession(WorkoutOverviewData data) {
    state = KinestexSessionState.completed(data);
    // Log to analytics, save to backend, etc.
  }

  void exitSession() {
    state = const KinestexSessionState.idle();
  }
}
```

### Layer 3: Widget that handles SDK + messages

```dart
class KinestexWorkoutScreen extends ConsumerWidget {
  final String workoutName;
  const KinestexWorkoutScreen({super.key, required this.workoutName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(kinestexSessionControllerProvider);
    final showKinesteX = ValueNotifier<bool>(session is KinestexSessionStateActive);

    return Scaffold(
      body: KinesteXAIFramework.createWorkoutView(
        workoutName: workoutName,
        isShowKinestex: showKinesteX,
        isLoading: ValueNotifier<bool>(false),
        customParams: const {'style': 'dark', 'language': 'en'},
        onMessageReceived: (message) {
          _handleMessage(message, ref);
        },
      ),
    );
  }

  void _handleMessage(WebViewMessage message, WidgetRef ref) {
    final controller = ref.read(kinestexSessionControllerProvider.notifier);
    if (message is ExitKinestex) {
      controller.exitSession();
    } else if (message is WorkoutCompleted) {
      controller.completeSession(_parseOverview(message));
    }
    // ... other event types
  }
}
```

**Why this pattern works for Apployee:**
- Riverpod stays in charge of state (consistent with rest of codebase)
- Helper wraps SDK calls (consistent with helper pattern in `lib/helpers/`)
- No artificial UseCase/Repository layer for what's fundamentally a UI widget
- Analytics, persistence, navigation triggered from the controller — testable

## Message Handling (Always Pattern-Match)

Use `is` checks on typed message classes, **not** raw string comparison:

```dart
// ✅ Correct
if (message is ExitKinestex) { ... }
else if (message is WorkoutOverview) { ... }
else if (message is ExerciseCompleted) { ... }

// ❌ Wrong (string-based, fragile)
if (message.type == 'exit_kinestex') { ... }
```

The SDK provides typed message classes. Use them.

**Always handle at minimum:**
- `ExitKinestex` — user closed the SDK (always hide the view)
- `WorkoutCompleted` / `WorkoutOverview` — for analytics/persistence
- `ErrorOccurred` — log to error tracking

For the full 45+ event list with payload structures, read `.claude/refs/kinestex/data-points.md`.

## Customization (Theme, Language, UI Controls)

Pass via `customParams` (Flutter) or `style` parameter (`IStyle` class):

```dart
KinesteXAIFramework.createWorkoutView(
  workoutName: 'Fitness Lite',
  style: IStyle(
    style: 'dark',                     // or 'light'
    loadingBackgroundColor: '1A1A2E',  // hex WITHOUT # for Flutter
    loadingStickmanColor: 'e94560',
    loadingTextColor: 'FFFFFF',
  ),
  customParams: {
    'language': 'en',                  // en, es, fr, de, nl, it, ar, hi, ...
    'isHideHeaderMain': true,
    'hideFeelingDialog': true,
    'showLeaderboard': true,
    'username': 'user_display_name',
  },
  // ...
)
```

**Hex color gotcha:** Flutter SDK uses hex **without** `#`. Swift uses **with** `#`. Don't copy-paste between platforms blindly.

For the full customization parameter reference (40+ params), read `.claude/refs/kinestex/integration-options.md`.

## Camera Component (For Custom UI / Direct Motion Tracking)

If you want **only** motion tracking without KinesteX's UI:

```dart
KinesteXAIFramework.createCameraComponent(
  isShowKinestex: showKinesteX,
  exercises: ['squats_v2', 'jumping_jack_v2'],  // exercise IDs (recommended)
  currentExercise: 'squats_v2',
  customParams: {
    'exerciseFetchType': 'exercise_id',  // 'exercise_id' | 'model_id' | 'exercise_title'
  },
  onMessageReceived: (message) {
    if (message is SuccessfulRepeat) {
      // message.data['value'] = total reps
    }
    if (message is Mistake) {
      // message.data['value'] = mistake type
    }
  },
)
```

**Wait for both `model_warmedup` AND `models_loaded` events before showing camera to user.** Show a loader until both fire.

For deep camera component usage (pose data, model IDs, controls, runtime exercise switching), read `.claude/refs/kinestex/camera-component.md`.

## Content API (Fetch Workouts/Plans/Exercises)

Use this to build your own browser UI for KinesteX content:

```dart
final result = await KinesteXAIFramework.apiService.fetchContent(
  contentType: ContentType.workout,
  category: 'Fitness',
  limit: 10,
);

switch (result) {
  case WorkoutsResult(:final response):
    final workouts = response.workouts;  // List<WorkoutModel>
  case ErrorResult(:final message):
    // handle error
  default: break;
}
```

**Plans REQUIRE a category parameter** in Flutter SDK. Without it, you'll get unexpected `PlanResult` (single) instead of `PlansResult` (list).

For Content API patterns (pagination, filtering by body parts, model structures), read `.claude/refs/kinestex/content-api.md`.

## Camera Permission Flow

KinesteX requires camera at runtime. Always request **before** showing the view:

```dart
Future<void> _startWorkout() async {
  final status = await Permission.camera.request();
  if (status != PermissionStatus.granted) {
    if (!mounted) return;
    showDialog(/* "Camera required" */);
    return;
  }
  showKinesteX.value = true;
}
```

**Never** call `showKinesteX.value = true` without checking permission first. The SDK will fail silently or show a black screen.

## Anti-Patterns (Reject These)

| Anti-pattern | Why wrong | Replace with |
|---|---|---|
| Hardcoded API key in source | Public repos leak it | `AppConfig.kinestexApiKey` from flavor/env |
| Pushing KinesteX view as new route | SDK lifecycle expects toggle | `ValueNotifier<bool>` + conditional render |
| String-based message type check | Fragile, breaks on SDK updates | `if (message is ExitKinestex)` |
| Showing camera component without waiting for events | User sees black/loading screen | Wait for `model_warmedup` + `models_loaded` |
| Wrapping KinesteX in full DDP (UseCase/Repo/DataSource) | SDK is UI, not data | Helper + Riverpod controller (hybrid) |
| Calling `initialize()` multiple times | Causes SDK state corruption | Once in `main()`, dispose in root `dispose()` |
| Title-based exercise lookup in production | Locale-dependent, can mismatch | Exercise IDs from Content API |
| Using `Stop Camera` command for pause | Destructive — releases all models | Use `Pause Exercise` instead |
| Hardcoded user ID like `'test_user'` | Breaks analytics, leaderboards | Real user ID from auth (min 2 chars) |
| Mixing hex `#` styles between platforms | Flutter wants without, Swift with | Always check platform-specific format |

## Common Bugs

- **Black screen on camera view:** Permission not granted, or wait events not handled.
- **Workouts not loading:** API key/company mismatch, or `userId` shorter than 2 chars.
- **Events not received:** Message handler not passed correctly, or wrong `is` type check.
- **Plans returning single instead of list:** `category` parameter missing in `fetchContent`.
- **iOS build fails:** `pod install` not run after adding dependency, or `PERMISSION_CAMERA=1` missing in Podfile.
- **Android crashes on launch:** `minSdkVersion` below 26.
- **Memory issues on long workouts (iOS):** Set `motionDataEnabled: false` in `customParams`.

## When in Doubt

- Check `.claude/refs/kinestex/` for deep details (integration options, camera component, data points, content API)
- Fetch official docs via web_fetch — APIs evolve fast in this SDK
- Look at neighboring Apployee features for established Riverpod/helper patterns
- Don't invent KinesteX features — verify they exist in current SDK version (1.4.7)

## Verification Before Implementing

Before implementing a customization or integration option you're not sure about:
1. Check the official docs page for that specific feature
2. Verify the SDK version on pub.dev hasn't changed
3. For experimental features (Mutations, Offline persistence — wait, that's Riverpod, not KinesteX) — none in KinesteX currently
4. For Apployee: confirm with user which integration option fits the use case
