# KinesteX Camera Component — Deep Reference

**Loaded by:** `flutter-kinestex` skill when working with the Camera Component, custom UI motion tracking, pose data, or exercise model IDs.
**Source:** https://www.kinestex.com/docs/integration (Camera Component section)

Use the Camera Component when you want **only** KinesteX's motion tracking, with your own UI on top.

---

## Exercise Identification (3 ways)

You can identify exercises by **exercise ID**, **model ID**, or **exercise title**. Pick one form per session.

| `exerciseFetchType` | Identifier | When to use |
|---|---|---|
| `'exercise_id'` ✅ recommended | e.g. `'squats_v2'` | You have IDs from Content API — no lookup needed |
| `'model_id'` (default) | e.g. `'3'`, `'394'` | You have numeric model IDs (admin dashboard / `WorkoutModel.sequence`) |
| `'exercise_title'` | e.g. `'Squats'`, `'Jumping Jack'` | Prototyping — fragile due to locale/case |

**Set `exerciseFetchType` via `customParams`:**

```dart
KinesteXAIFramework.createCameraComponent(
  exercises: ['squats_v2', 'jumping_jack_v2'],
  currentExercise: 'squats_v2',
  customParams: {
    'exerciseFetchType': 'exercise_id',
  },
  // ...
)
```

**Use the same form for both `exercises` and `currentExercise`.** Don't mix.

### How to get model IDs

Three options:

1. **Content API:** `ExerciseModel.modelId` from `fetchContent(contentType: ContentType.exercise)`
2. **Admin dashboard:** Open exercise at `admin.kinestex.com`, model ID shown at top of header
3. **Workout sequences:** Iterate `WorkoutModel.sequence` — each `ExerciseModel` has its own `model_id`

---

## Preloading Events (CRITICAL)

Two events fire during initialization. **Wait for BOTH before revealing the camera UI:**

| Event | Meaning |
|---|---|
| `model_warmedup` | Pose-tracking (MediaPipe) model is ready |
| `models_loaded` | All exercise models in `exercises` array have downloaded |

**Pattern:** mount camera hidden (`Opacity(opacity: 0)`) with a loader on top. Reveal when both events fire.

```dart
class CameraScreen extends StatefulWidget {
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool modelWarmedUp = false;
  bool modelsLoaded = false;
  final showKinesteX = ValueNotifier<bool>(true);

  bool get isReady => modelWarmedUp && modelsLoaded;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Opacity(
          opacity: isReady ? 1.0 : 0.0,
          child: KinesteXAIFramework.createCameraComponent(
            isShowKinestex: showKinesteX,
            exercises: const ['squats_v2'],
            currentExercise: 'squats_v2',
            customParams: const {'exerciseFetchType': 'exercise_id'},
            isLoading: ValueNotifier<bool>(false),
            onMessageReceived: (message) {
              if (message.type == 'model_warmedup') {
                setState(() => modelWarmedUp = true);
              } else if (message.type == 'models_loaded') {
                setState(() => modelsLoaded = true);
              }
            },
          ),
        ),
        if (!isReady)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
```

---

## Switching Exercises at Runtime

Set `currentExercise` to any model ID from the `exercises` array — camera swaps tracking instantly.

```dart
final updateExercise = ValueNotifier<String?>('squats_v2');

// In widget tree:
ValueListenableBuilder<String?>(
  valueListenable: updateExercise,
  builder: (context, value, _) {
    return KinesteXAIFramework.createCameraComponent(
      isShowKinestex: showKinesteX,
      exercises: const ['squats_v2', 'jumping_jack_v2', 'pushups_v2'],
      currentExercise: value ?? 'squats_v2',
      updatedExercise: value,
      // ...
    );
  },
)

// Switch programmatically:
updateExercise.value = 'jumping_jack_v2';
```

---

## Control Commands

Send these strings as `currentExercise` to control the session:

| Command | Effect |
|---|---|
| `'Pause Exercise'` | Pauses motion tracking; rep counter freezes |
| `'Pause Audio'` | Mutes voice feedback |
| `'Resume Audio'` | Re-enables voice feedback |
| `'Workout Overview'` | Triggers summary snapshot for current session |
| `'Stop Camera'` | ⚠️ **DESTRUCTIVE** — releases camera + models. Fires `stop_camera`. Cannot recover without remounting |

To resume after `Pause Exercise`, set `currentExercise` back to a real model ID.

⚠️ **NEVER use `'Stop Camera'` for normal pauses.** It tears down the entire camera + MediaPipe + all loaded models. Only use when permanently leaving the camera screen. For temporary pauses, use `'Pause Exercise'`.

---

## Customization

Pass via `customParams`:

```dart
customParams: {
  'restSpeeches': ['rest_phrase_1', 'rest_phrase_2'],  // from ExerciseModel.rest_speech
  'videoURL': 'https://example.com/demo.mp4',          // use video instead of live camera
  'landmarkColor': '#14FF00',                          // pose overlay color
  'showSilhouette': true,                              // 'get into frame' guide
  'includeRealtimeAccuracy': true,                     // beta — live position confidence
  'includePoseData': ['poseLandmarks', 'worldLandmarks', 'angles'],  // performance cost!
}
```

---

## All Camera Events

| Event | Payload | When |
|---|---|---|
| `model_warmedup` | `{ message }` | Pose model ready |
| `models_loaded` | `{ message }` | All exercise models downloaded |
| `person_in_frame` | `{ message }` | User entered silhouette |
| `successful_repeat` | `{ exercise, value, accuracy }` | Rep counted (`value` = total reps so far) |
| `mistake` | `{ value }` | Form mistake detected |
| `correct_position_accuracy` | `{ accuracy }` | Beta — live confidence (only if `includeRealtimeAccuracy: true`) |
| `pose_landmarks` | `{ poseLandmarks }` | Per-frame landmarks (only if `includePoseData` contains `'poseLandmarks'`) |
| `world_landmarks` | `{ worldLandmarks }` | Per-frame world landmarks (only if `includePoseData` contains `'worldLandmarks'`) |
| `speech_fetch_complete` | `{ successCount, failureCount }` | All `restSpeeches` loaded |
| `error_occurred` | `{ message }` | Any error |
| `warning` | `{ data }` | Non-fatal config issue |
| `stop_camera` | `{ message }` | Confirms `'Stop Camera'` finished |

---

## Pose Data (Advanced)

Only enable if doing custom calculations. Two coordinate spaces:

- **`poseLandmarks`** — values 0–1, normalized to camera frame
- **`worldLandmarks`** — meters, relative to hips (best Z accuracy)

Each landmark has `{ x, y, z, visibility }` (all 0–1).

### Available landmarks (same in both spaces)

`nose`, `leftEyeInner`, `leftEye`, `leftEyeOuter`, `rightEyeInner`, `rightEye`, `rightEyeOuter`, `leftEar`, `rightEar`, `mouthLeft`, `mouthRight`, `leftShoulder`, `rightShoulder`, `leftElbow`, `rightElbow`, `leftWrist`, `rightWrist`, `leftPinky`, `rightPinky`, `leftIndex`, `rightIndex`, `leftThumb`, `rightThumb`, `leftHip`, `rightHip`, `leftKnee`, `rightKnee`, `leftAnkle`, `rightAnkle`, `leftHeel`, `rightHeel`, `leftFootIndex`, `rightFootIndex`

### Available angles (when `'angles'` is in `includePoseData` — both 2D and 3D)

`leftKneeAngle`, `rightKneeAngle`, `leftHipAngle`, `rightHipAngle`, `leftShoulderAngle`, `rightShoulderAngle`, `leftElbowAngle`, `rightElbowAngle`, `leftWristAngle`, `rightWristAngle`, `leftAnkleAngle`, `rightAnkleAngle`, `leftArmpitAngle`, `rightArmpitAngle`

---

## Complete Example: Camera with Rep Counter and Next/Previous

```dart
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Exercise IDs from Content API
  final exerciseIds = const ['squats_v2', 'jumping_jack_v2'];

  int index = 0;
  int reps = 0;
  String? lastMistake;
  bool modelWarmedUp = false;
  bool modelsLoaded = false;

  final showKinesteX = ValueNotifier<bool>(true);
  final updateExercise = ValueNotifier<String?>('squats_v2');

  bool get isReady => modelWarmedUp && modelsLoaded;

  void switchTo(int newIndex) {
    final wrapped = (newIndex + exerciseIds.length) % exerciseIds.length;
    setState(() {
      index = wrapped;
      reps = 0;
      lastMistake = null;
    });
    updateExercise.value = exerciseIds[wrapped];
  }

  void handleMessage(WebViewMessage m) {
    if (m.type == 'model_warmedup') {
      setState(() => modelWarmedUp = true);
    } else if (m.type == 'models_loaded') {
      setState(() => modelsLoaded = true);
    } else if (m is SuccessfulRepeat) {
      setState(() => reps = m.data['value'] ?? 0);
    } else if (m is Mistake) {
      setState(() => lastMistake = m.data['value']?.toString());
    } else if (m is ExitKinestex) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera (hidden until ready)
          Opacity(
            opacity: isReady ? 1.0 : 0.0,
            child: ValueListenableBuilder<String?>(
              valueListenable: updateExercise,
              builder: (context, value, _) {
                return KinesteXAIFramework.createCameraComponent(
                  isShowKinestex: showKinesteX,
                  exercises: exerciseIds,
                  currentExercise: value ?? exerciseIds[0],
                  updatedExercise: value,
                  customParams: const {'exerciseFetchType': 'exercise_id'},
                  isLoading: ValueNotifier<bool>(false),
                  onMessageReceived: handleMessage,
                );
              },
            ),
          ),

          // Loader while not ready
          if (!isReady)
            const Center(child: CircularProgressIndicator()),

          // UI overlay
          if (isReady) ...[
            // Rep counter (top)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reps: $reps',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (lastMistake != null)
                        Text(
                          'Form: $lastMistake',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Next/Previous (bottom)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      FloatingActionButton(
                        onPressed: () => switchTo(index - 1),
                        child: const Icon(Icons.skip_previous),
                      ),
                      FloatingActionButton(
                        onPressed: () {
                          updateExercise.value = 'Pause Exercise';
                        },
                        child: const Icon(Icons.pause),
                      ),
                      FloatingActionButton(
                        onPressed: () => switchTo(index + 1),
                        child: const Icon(Icons.skip_next),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

---

## Apployee Pattern: Camera Component with Riverpod

```dart
// Provider
@riverpod
class CameraTrackingController extends _$CameraTrackingController {
  @override
  CameraTrackingState build() => const CameraTrackingState.notReady();

  void onModelWarmedUp() {
    state = state.copyWith(modelWarmedUp: true);
    _checkReady();
  }

  void onModelsLoaded() {
    state = state.copyWith(modelsLoaded: true);
    _checkReady();
  }

  void _checkReady() {
    if (state.modelWarmedUp && state.modelsLoaded) {
      state = state.copyWith(isReady: true);
    }
  }

  void onRep(int totalReps) {
    state = state.copyWith(reps: totalReps);
  }

  void onMistake(String mistake) {
    state = state.copyWith(lastMistake: mistake);
  }
}

// Usage in widget — wire onMessageReceived to controller methods
```

---

## When NOT to Use Camera Component

Use a Plug-and-Play option instead if you need:
- Pre-built workout flow (use WorkoutView)
- Rest periods, instructions, exercise transitions (use CustomWorkoutView or WorkoutView)
- Leaderboards (use ChallengeView with `showLeaderboard: true`)
- Plan progression tracking (use PlanView or WorkoutView with plan context)

Camera Component is for: **"I have my own UI and just want pose tracking + rep counting."**
