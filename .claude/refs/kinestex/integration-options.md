# KinesteX Integration Options — Complete Reference

**Loaded by:** `flutter-kinestex` skill when working with specific integration options or customization parameters.
**Source:** https://www.kinestex.com/docs/integration + customization-parameters page

This file covers all 9 integration options + all customization parameters with copy-paste-ready Flutter examples.

---

## Integration Options Summary

| Option | Function | Use case |
|---|---|---|
| Main View | `createMainView` | Full KinesteX experience, plan selection by category |
| Workout View | `createWorkoutView` | Launch one specific workout |
| Plan View | `createPlanView` | Multi-day workout plan |
| Challenge View | `createChallengeView` | Single-exercise gamified challenge |
| Leaderboard View | `createLeaderboardView` | Standalone leaderboard for an exercise |
| Experience View | `createExperienceView` | AI games + clinical assessments |
| Personalized Plan | `createPersonalizedPlanView` | AI-generated plan from biometrics |
| Admin Editor | `createAdminWorkoutEditor` | Embed workout/exercise editor (Flutter only) |
| Custom Workout | `createCustomWorkoutView` | Custom exercise sequence |
| Camera Component | `createCameraComponent` | Motion tracking only, your own UI |

---

## 1. Main View (Complete UX)

Full KinesteX experience with plan selection by category, user survey, and AI-generated schedule.

**Plan Categories:** Strength, Cardio, Weight Management, Rehabilitation, Custom

```dart
KinesteXAIFramework.createMainView(
  isShowKinestex: showKinesteX,
  planCategory: PlanCategory.Cardio,
  customParams: {
    'style': 'dark',
    'isHideHeaderMain': false,
  },
  isLoading: ValueNotifier<bool>(false),
  onMessageReceived: (message) {
    if (message is ExitKinestex) {
      showKinesteX.value = false;
    } else if (message is KinestexLaunched) {
      // Track app open
    } else if (message is WorkoutCompleted) {
      // Track completion
    }
  },
)
```

### Customize home page (Complete UX only)

```dart
customParams: {
  'challenges_home': [
    {'id': 'squats_v2', 'name': 'Squats Challenge', 'isGame': false},
    {'id': 'balloonpop', 'name': 'Balloon Pop', 'isGame': true},
  ],
}
```

You **must** pass exactly 2 items. Mix challenges and games freely.

---

## 2. Workout View

Launch a specific workout by name or ID. Most common integration for fitness apps.

```dart
KinesteXAIFramework.createWorkoutView(
  isShowKinestex: showKinesteX,
  workoutName: 'Fitness Lite',  // or workout ID
  customParams: {'style': 'dark', 'language': 'en'},
  isLoading: ValueNotifier<bool>(false),
  onMessageReceived: (message) {
    if (message is ExitKinestex) {
      showKinesteX.value = false;
    }
  },
)
```

### Plan context (when workout is part of a plan)

If launching a workout that belongs to a plan, pass plan context so progression is tracked:

```dart
customParams: {
  'planId': 'plan_abc123',
  'planType': 'personalized',
  'progressWorkoutId': 'plan_day_3',
}
```

After completion, you'll receive `plan_progression_saved` or `plan_progression_failed`.

---

## 3. Plan View

Display a specific multi-day workout plan with schedule.

```dart
KinesteXAIFramework.createPlanView(
  isShowKinestex: showKinesteX,
  planName: 'Full Body Fitness',  // or plan ID
  customParams: {'style': 'dark'},
  isLoading: ValueNotifier<bool>(false),
  onMessageReceived: (message) {
    if (message is ExitKinestex) {
      showKinesteX.value = false;
    }
  },
)
```

---

## 4. Challenge View

Single-exercise gamified challenge with countdown timer and leaderboard.

```dart
KinesteXAIFramework.createChallengeView(
  isShowKinestex: showKinesteX,
  exercise: 'Squats',  // exercise title or ID
  countdown: 100,       // seconds
  showLeaderboard: true,
  customParams: {
    'style': 'dark',
    'username': 'user_display_name',
    'autoSubmitLeaderboard': false,  // true = skip submit modal
  },
  isLoading: ValueNotifier<bool>(false),
  onMessageReceived: (message) {
    if (message is ExitKinestex) {
      showKinesteX.value = false;
    } else if (message is ChallengeCompleted) {
      // Handle reps, mistakes
    }
  },
)
```

---

## 5. Leaderboard View

Standalone leaderboard for an exercise (no challenge runs, just shows rankings).

```dart
KinesteXAIFramework.createLeaderboardView(
  isShowKinestex: showKinesteX,
  exercise: 'Squats',
  username: 'current_user_display_name',  // highlights user if matched
  customParams: {
    'style': 'dark',
    'isHideHeaderMain': true,  // hide back button if embedded
  },
  isLoading: ValueNotifier<bool>(false),
  onMessageReceived: (message) {
    if (message is ExitKinestex) {
      showKinesteX.value = false;
    }
  },
)
```

---

## 6. Experience View (AI Games + Assessments)

### Available games

| Game | Exercise ID |
|---|---|
| Balloon Pop | `balloonpop` |
| Color Memory | `colorchase` |
| Alien Squat Shooter | `aliensquatshooter` |

### Available clinical assessments

| Assessment | Exercise ID |
|---|---|
| Timed Up and Go | `tug` |
| Gait Speed Test | `gaitspeedtest` |
| Sit-to-Stand | `sittostand` |
| Functional Reach Test | `functionalreachtest` |
| Single Leg Stance | `singlelegstancetest` |
| Five Times Sit-to-Stand | `fivetimessts` |
| Side-by-Side Stand | `sidebysidestand` |
| Semi-Tandem Stand | `semitandemstand` |
| Full Tandem Stand | `fulltandem` |
| Shoulder Range of Motion | `romshoulder` |

```dart
KinesteXAIFramework.createExperienceView(
  isShowKinestex: showKinesteX,
  experience: 'assessment',  // or 'game'
  exercise: 'balloonpop',     // exercise ID from tables above
  customParams: {'style': 'dark'},
  isLoading: ValueNotifier<bool>(false),
  onMessageReceived: (message) {
    // Assessment results come via assessment_overview event
  },
)
```

### Balloon Pop rounds mode

Pass both `reps` and `countdown` to switch from default 30s timer to rounds mode:

```dart
customParams: {
  'reps': 4,        // 4 rounds
  'countdown': 2,   // 2 balloons per round
  // → 8 total pops, no timer
}
```

---

## 7. Personalized Plan

AI-generated plan from user biometrics + assessment results.

```dart
KinesteXAIFramework.createPersonalizedPlanView(
  isShowKinestex: showKinesteX,
  customParams: {'style': 'dark'},
  isLoading: ValueNotifier<bool>(false),
  onMessageReceived: handleMessage,
)
```

### Plan onboarding prefill

Skip onboarding survey screens by pre-filling answers:

```dart
KinesteXAIFramework.createCustomComponentView(
  route: 'plan-onboarding',
  customParams: {
    'planOnboardingPrefill': {
      'goal': 'weight_loss',
      'healthIssues': ['back_pain'],
      'injuries': [],
      'duration': 30,
      'lifestyle': 'sedentary',
    },
  },
)
```

For **reassessment flow** (user already has profile, just wants fresh assessment), use:
```dart
'planOnboardingPrefill': {
  'assessmentOnly': true,  // skips all survey screens
}
```

---

## 8. Admin Workout Editor (Flutter only)

Embed the admin dashboard for creating/managing workouts and exercises.

```dart
KinesteXAIFramework.createAdminWorkoutEditor(
  organization: 'your_org_name',
  isShowKinestex: showKinesteX,
  customQueries: {
    'hidePlansTab': false,
    'tab': 'workouts',           // 'exercises' | 'workouts' | 'plans'
    'isSelectableMenu': true,    // shows Select button, triggers _selected events
  },
  isLoading: ValueNotifier<bool>(false),
  onMessageReceived: (message) {
    if (message is WorkoutSaved) {
      // message.data['workout_id']
    } else if (message is ExerciseSaved) {
      // message.data['exercise_id']
    } else if (message is WorkoutSelected) {
      // User clicked Select on a workout
    }
  },
)
```

### Admin events

- `kinestex_loaded`, `kinestex_launched`, `error_occurred`
- `exercise_opened`, `exercise_selection_opened`, `exercise_selected`, `exercise_saved`, `exercise_removed`
- `workout_opened`, `workout_selection_opened`, `workout_selected`, `workout_saved`
- `plan_opened`, `plan_selection_opened`, `plan_selected`, `plan_saved`

---

## 9. Custom Workout

Define your own exercise sequence with reps, durations, rest periods.

```dart
final customExercises = [
  WorkoutSequenceExercise(
    exerciseId: 'jz73VFlUyZ9nyd64OjRb',
    reps: 15,
    duration: null,           // null = unlimited time for reps
    includeRestPeriod: true,
    restDuration: 20,
  ),
  WorkoutSequenceExercise(
    exerciseId: 'ZVMeLsaXQ9Tzr5JYXg29',
    reps: 10,
    duration: 30,             // 30s time cap
    includeRestPeriod: true,
    restDuration: 15,
  ),
  // Duplicate to create a set
  WorkoutSequenceExercise(
    exerciseId: 'ZVMeLsaXQ9Tzr5JYXg29',
    reps: 10,
    duration: 30,
    includeRestPeriod: true,
    restDuration: 15,
  ),
];

KinesteXAIFramework.createCustomWorkoutView(
  isShowKinestex: showKinesteX,
  customWorkouts: customExercises,
  customParams: {'style': 'dark'},
  isLoading: ValueNotifier<bool>(false),
  onMessageReceived: (message) {
    if (message.type == 'all_resources_loaded') {
      // Send start action AFTER resources loaded
      KinesteXAIFramework.sendAction('workout_activity_action', 'start');
    }
  },
)
```

**Workflow:**
1. Mount view (resources start loading)
2. Wait for `all_resources_loaded` message
3. Send `workout_activity_action: start`
4. Workout runs

Get exercise IDs from Content API (`fetchContent` with `ContentType.exercise`).

---

## Customization Parameters Reference

### User Profile (UserDetails)

```dart
final user = UserDetails(
  age: 30,
  height: 180,           // cm or inches based on locale
  weight: 75,            // kg or lbs based on locale
  gender: Gender.male,   // .male | .female | .other
  lifestyle: Lifestyle.active,  // .sedentary | .active | etc.
);
```

Affects: BMI calc, calorie estimation, intensity recommendations, content personalization.

### Theme (IStyle class)

```dart
IStyle(
  style: 'dark',                       // 'dark' | 'light'
  themeName: 'CustomBrand',            // optional
  loadingBackgroundColor: '1A1A2E',    // hex WITHOUT # for Flutter
  loadingStickmanColor: 'e94560',
  loadingTextColor: 'FFFFFF',
)
```

### Language

```dart
customParams: {
  'language': 'en',  // en, es, fr, de, nl, it, pt, ru, ar, he, hi, bn, id, da, el, zh
  'content_gender': 'female',  // optional instructor preference
}
```

RTL support: `ar`, `he`.

### UI Controls

```dart
customParams: {
  'isHideHeaderMain': true,           // hide top header
  'hideFeelingDialog': true,          // skip post-workout prompt
  'hideMusicIcon': true,              // hide music toggle
  'hideMistakesFeedback': false,      // hide form correction prompts
  'isOnboarding': false,              // skip onboarding
  'hideCompletionOverlay': true,      // skip completion summary
  'preventGestureControl': true,      // disable hand gestures
  'disableGuide': true,               // suppress guide entirely
  'disableCookies': true,             // GDPR compliance
  'hideStatisticsHeader': false,
  'nativeParentScroll': false,        // delegate scroll to native
}
```

### Camera & Pose Detection

```dart
customParams: {
  'shouldAskCamera': true,
  'shouldShowCameraSelector': false,
  'cameraId': '...',                  // specific device ID
  'minPoseDetectionConfidence': 0.5,
  'minTrackingConfidence': 0.5,
  'minPosePresenceConfidence': 0.5,
  'mediapipeModel': 'full',           // 'light' | 'full' | 'heavy'
  'defaultDelegate': 'GPU',           // 'GPU' | 'CPU'
  'landmarkColor': '#14FF00',         // pose overlay color (WITH # here)
  'showSilhouette': true,
  'includePoseData': ['poseLandmarks', 'worldLandmarks', 'angles'],
  'includePoseBorders': true,
  'includeRealtimeAccuracy': false,   // beta
  'videoFit': 'contain',              // 'cover' (default) | 'contain'
}
```

⚠️ `includePoseData` has performance cost — only enable for custom calculations.

### Leaderboard

```dart
customParams: {
  'showLeaderboard': true,
  'username': 'display_name',
  'autoSubmitLeaderboard': true,  // Challenge only: skip submit modal
}
```

Username is auto-saved to localStorage for future sessions.

### Motion Tracking

```dart
customParams: {
  'motionTrackingSettingOn': true,   // show toggle in UI
  'motionTrackingEnabled': true,     // session-level override
  'motionDataEnabled': false,        // disable per-frame recording (memory savings)
}
```

⚠️ `motionDataEnabled: false` disables session replay. Only use if hitting memory limits on long workouts.

### Session Saving

```dart
customParams: {
  'shouldSendStats': true,  // save sessions + motion uploads to backend
}
```

When enabled, emits `workout_session_saved`, `session_save_complete`, `motion_upload_progress` events.

### Navigation

```dart
customParams: {
  'instantRedirect': '/workout/start',  // immediately navigate after verification
}
```

---

## Workout Activity Actions (Send Commands to SDK)

After workout starts, control it via `sendAction`:

```dart
// Pause/resume
KinesteXAIFramework.sendAction('workout_activity_action', 'pause_workout');
KinesteXAIFramework.sendAction('workout_activity_action', 'resume_workout');

// Audio
KinesteXAIFramework.sendAction('workout_activity_action', 'mute_workout');
KinesteXAIFramework.sendAction('workout_activity_action', 'unmute_workout');

// Just speech (sounds still play)
KinesteXAIFramework.sendAction('workout_activity_action', 'mute_speech');
KinesteXAIFramework.sendAction('workout_activity_action', 'unmute_speech');
```

Use these for in-app controls (e.g., a pause button overlay during a workout).

---

## Complete Apployee Example: Workout View with Riverpod

```dart
// Provider
@riverpod
class WorkoutSessionController extends _$WorkoutSessionController {
  @override
  AsyncValue<WorkoutSessionState> build() => const AsyncData(WorkoutSessionState.idle());

  Future<void> launchWorkout(String workoutName) async {
    final granted = await sl<KinesteXHelper>().requestCameraPermission();
    if (!granted) {
      state = AsyncData(const WorkoutSessionState.permissionDenied());
      return;
    }
    state = AsyncData(WorkoutSessionState.launching(workoutName: workoutName));
  }

  void onCompleted(WorkoutOverviewData data) {
    state = AsyncData(WorkoutSessionState.completed(data));
    // Sync to backend, update local stats, etc.
  }

  void exit() {
    state = const AsyncData(WorkoutSessionState.idle());
  }
}

// Widget
class WorkoutScreen extends ConsumerWidget {
  final String workoutName;
  const WorkoutScreen({super.key, required this.workoutName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionControllerProvider);
    final controller = ref.read(workoutSessionControllerProvider.notifier);
    final showKinesteX = ValueNotifier<bool>(false);

    session.whenData((state) {
      showKinesteX.value = state is WorkoutSessionStateLaunching;
    });

    return Scaffold(
      body: SafeArea(
        child: KinesteXAIFramework.createWorkoutView(
          isShowKinestex: showKinesteX,
          workoutName: workoutName,
          style: IStyle(
            style: 'dark',
            loadingBackgroundColor: '0F1419',
          ),
          customParams: {
            'language': context.appLocale,
            'hideFeelingDialog': true,
          },
          isLoading: ValueNotifier<bool>(false),
          onMessageReceived: (message) {
            if (message is ExitKinestex) {
              controller.exit();
            } else if (message is WorkoutOverview) {
              controller.onCompleted(_mapOverview(message));
            } else if (message is ErrorOccurred) {
              sl<Logger>().error('KinesteX error', message.data);
            }
          },
        ),
      ),
    );
  }
}
```
