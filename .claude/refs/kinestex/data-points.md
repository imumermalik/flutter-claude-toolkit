# KinesteX Data Points (Events) — Complete Reference

**Loaded by:** `flutter-kinestex` skill when handling KinesteX PostMessage events, parsing workout/exercise data, or building analytics/persistence.
**Source:** https://www.kinestex.com/docs/data-points

KinesteX sends 45+ event types via `onMessageReceived` callback. Use typed `is` checks, not string comparison.

---

## Message Handler Pattern (Always Use This)

```dart
void handleMessage(WebViewMessage message) {
  if (message is KinestexLaunched) {
    // App started
  } else if (message is ExitKinestex) {
    // User exited — ALWAYS hide the view
    setState(() => showKinesteX.value = false);
  } else if (message is WorkoutCompleted) {
    // Workout done
  } else if (message is WorkoutOverview) {
    // Full stats available
  } else if (message is ExerciseCompleted) {
    // Individual exercise done
  } else if (message is SuccessfulRepeat) {
    // Camera component: rep counted
  } else if (message is Mistake) {
    // Form mistake
  } else if (message is ErrorOccurred) {
    // Log error
  } else {
    // Fallback for unknown
    debugPrint('Unhandled KinesteX message: ${message.data}');
  }
}
```

---

## Application Lifecycle Events

| Event | Type | Description |
|---|---|---|
| `kinestex_launched` | `KinestexLaunched` | App launched. Payload: timestamp |
| `kinestex_loaded` | — | Fully loaded and ready |
| `exit_kinestex` | `ExitKinestex` | User exited. Payload: `date`, `time_spent` |
| `main_page_opened` | — | Main/home page opened |
| `home_page_opened` | — | Home Page integration screen opened (fires once per mount) |
| `streak_extended` | — | User extended their daily streak |

### `streak_extended` payload

```dart
{
  'current_streak': 5,         // Days
  'longest_streak': 12,
  'last_activity_date': '...', // ISO date
}
```

---

## Workout Events

| Event | Type | Description |
|---|---|---|
| `workout_opened` | `WorkoutOpened` | Details page opened. `{ title, id, date }` |
| `workout_started` | `WorkoutStarted` | Session started. `{ id, date }` |
| `workout_completed` | `WorkoutCompleted` | User exited overview after completion |
| `workout_ended` | — | Session ended. `{ id, exit_type, date }` |
| `workout_overview` | `WorkoutOverview` | Full summary statistics |

### `workout_ended` exit_type values

| Value | Meaning |
|---|---|
| `complete` | Finished entire workout including outro |
| `exit` | Abandoned mid-session |
| `outro` | Exited from outro/cooldown after all exercises done |

### `workout_overview` payload (THE big one)

```dart
{
  'workout_title': String,
  'workout_id': String,
  'target_duration_seconds': int,
  'workout_duration_seconds': int,  // Total wall-clock (includes rest, pauses)
  'total_time_spent': int,          // Active exercise time only
  'completed_reps_count': int,
  'target_reps_count': int,
  'calories_burned': double,
  'completion_percentage': double,  // 0-100
  'total_mistakes': int,
  'accuracy_score': double,         // 0-100
  'efficiency_score': double,       // 0-100
  'total_exercise': int,
  'actual_hold_time_seconds': int,
  'target_hold_time_seconds': int,
}
```

**Use `workout_duration_seconds`** for total session display.
**Use `total_time_spent`** for active exercise time only.

---

## Exercise Events

| Event | Type | Description |
|---|---|---|
| `exercise_completed` | `ExerciseCompleted` | Single exercise done |
| `exercise_overview` | `ExerciseOverview` | All exercises summary (array) |

### `exercise_completed` payload

```dart
{
  'exercise_title': String,
  'time_spent': int,            // seconds
  'repeats': int,
  'total_reps': int,            // required
  'total_duration': int,        // countdown time
  'perfect_hold_position': int, // seconds in perfect hold (0 for non-hold)
  'calories': double,
  'exercise_id': String,
  'exercise_index': int,        // 1-based position
  'total_exercises': int,
  'mistakes': [
    { 'mistake': String, 'count': int },
  ],
  'average_accuracy': double?,  // 0-1, optional
}
```

### `exercise_overview` items have same shape + extra fields

```dart
{
  // ...all exercise_completed fields...
  'mistake_count': int,         // Total
  'accuracy_reps': List<int>?,  // Per-rep scores
  'average_accuracy': double?,  // 0-100
}
```

---

## Camera & Frame Events

| Event | Description |
|---|---|
| `left_camera_frame` | User left camera view. `{ date }` |
| `returned_camera_frame` | User returned. `{ date }` |
| `check_frame_completed` | Frame check passed. `{ message }` |
| `camera_selector_opened` | Selector opened. `{ message }` (array of cameras) |
| `camera_selected` | Camera chosen. `{ id, label, isMirrorCamera }` |
| `total_active_seconds` | Active workout time (sent every 5s, pauses if user leaves frame) |

---

## Plan Events

| Event | Description |
|---|---|
| `plan_unlocked` | `{ id, img, title, date }` |
| `plan_opened` | `{ id }` — results screen rendered |
| `plan_onboarding_plan_created` | `{ plan_id, plan_type }` — new plan from onboarding/assessment |
| `plan_progression_saved` | Day progression saved successfully |
| `plan_progression_failed` | Day progression save failed |
| `personalized_plan_exit` | `{ workout, date }` |
| `remind_me_later_clicked` | User tapped "Remind me later" on Assessment screen |

**To track plan progression**: when launching a plan workout, pass `planId`, `planType`, `progressWorkoutId` in `customParams`. After completion, you'll get `plan_progression_saved` or `plan_progression_failed`.

---

## Challenge Events

| Event | Description |
|---|---|
| `challenge_started` | `{ exerciseId }` |
| `challenge_completed` | `{ repCount, mistakes }` |
| `challenge_exit` | `{ workout, date }` |

---

## Leaderboard Events

| Event | Description |
|---|---|
| `highlighted_user` | `{ username, score, position }` (1-based) |

---

## Navigation Events

| Event | Description |
|---|---|
| `kinestex_home_exit` | `{ workout, date }` |
| `navigation_back` | `{ exercise_index, total_exercises }` |

---

## Feedback Events

| Event | Description |
|---|---|
| `feedback_submitted` | User submitted training or per-exercise feedback |

### Training feedback payload (`source: 'training_feedback'`)

```dart
{
  'type': 'feedback_submitted',
  'source': 'training_feedback',
  'rating': int,
  'is_like': bool,
  'description': String,
  'workout_id': String,
  'workout_title': String,
}
```

### Per-exercise feedback (`source: 'exercise_feedback'`)

```dart
{
  'type': 'feedback_submitted',
  'source': 'exercise_feedback',
  'workout_id': String,
  'workout_title': String,
  'feedbacks': [
    {
      'exercise_id': String,
      'exercise_title': String,
      'is_like': bool,
      'description': String,
    },
  ],
}
```

---

## Session & Upload Events

Only fired when `shouldSendStats: true` is passed.

| Event | Description |
|---|---|
| `workout_session_saved` | Session saved to backend |
| `session_save_complete` | Motion uploads finished |
| `motion_upload_progress` | `{ completed, total }` |
| `motion_upload_error` | `{ error }` |
| `workout_completion_overlay_dismissed` | User dismissed completion celebration |

### `workout_session_saved` payload

```dart
{
  'session_id': int,
  'workout_title': String,
  'accuracy_score': double,
  'efficiency_score': double,
  'completion_percentage': double,
  'completed_reps_count': int,
  'calories_burned': double,
}
```

---

## Error & Status Events

| Event | Description |
|---|---|
| `error_occurred` | General error. `{ data }` or `{ message }` or `{ data, error }` |
| `warning` | Warning. `{ data }` |
| `ios_video_fallback_activated` | iOS video decoder stuck, switched to image-based playback |

### `ios_video_fallback_activated` payload

```dart
{
  'type': 'ios_video_fallback_activated',
  'reason': String,      // e.g. 'video_stuck_at_metadata'
  'videoUrl': String,
  'readyState': int,
  'userAgent': String,
}
```

Use for analytics on iOS playback issues. No action required.

---

## Assessment Events

| Event | Description |
|---|---|
| `assessment_overview` | Results page loaded with metrics |
| `assessment_completed` | User clicked restart or finish |
| `assessment_exit` | `{ exerciseId }` — exited before results |
| `assessment_exit_results` | `{ exerciseId }` — exited from results screen |

### Common payload fields (all assessments)

```dart
{
  'type': 'assessment_overview' | 'assessment_completed',
  'assessmentType': String,  // 'tug', 'sls', 'balloonpop', etc.
  'date': DateTime,
  'time': double,            // total seconds
  'steps': int?,             // walking assessments only
  // ... assessment-specific fields below
}
```

### Risk levels (all assessments with `riskLevel_*`)

| Value | Meaning |
|---|---|
| `low` | Good performance |
| `moderate` | Some limitations |
| `high` | Significant limitations |

### Per-assessment fields

For **TUG, Gait Speed, SLS, SBSS, STSS, Full Tandem, STS, Five Times STS, FRT, Shoulder ROM, Balloon Pop, Color Chase, Alien Squat Shooter** — see official data points page for full field list. Each has 5–15 specific fields like `walkingForwardTime`, `symmetryScore_sls`, `gameScore`, `masteryTitle_balloonpop`, etc.

### Game health benefits (all games)

```dart
'healthBenefits': {
  'heartDiseaseReduction': double,  // max 15%
  'diabetesReduction': double,      // max 20%
  'obesityReduction': double,       // max 10%
  'depressionReduction': double,    // max 15%
}
```

Formula: `reduction = min((gameScore / 100) * maxReduction, maxReduction)`

---

## Admin Editor Events (Flutter only — `createAdminWorkoutEditor`)

| Event | Type | Description |
|---|---|---|
| `kinestex_loaded` | — | App loaded |
| `kinestex_launched` | — | Authentication successful |
| `error_occurred` | `ErrorOccurred` | Auth error |
| `exercise_opened` | — | Exercise detail page opened |
| `exercise_selection_opened` | — | Exercise list page opened |
| `exercise_selected` | `ExerciseSelected` | User selected exercise (when `isSelectableMenu: true`) |
| `exercise_saved` | `ExerciseSaved` | Exercise created/updated |
| `exercise_removed` | — | Exercise removed from workout |
| `workout_opened` | — | Workout detail page opened |
| `workout_selection_opened` | — | Workout list page opened |
| `workout_selected` | `WorkoutSelected` | User selected workout |
| `workout_saved` | `WorkoutSaved` | Workout created/updated. `data['workout_id']` |
| `plan_opened` | — | Plan detail page opened |
| `plan_selection_opened` | — | Plan list page opened |
| `plan_selected` | — | User selected plan |
| `plan_saved` | `PlanSaved` | Plan created/updated. `data['plan_id']` |

---

## Event Flow Examples

### Complete Workout Flow

1. `kinestex_launched`
2. `workout_opened`
3. `workout_started`
4. `returned_camera_frame` / `left_camera_frame` (intermittent)
5. Multiple `exercise_completed` (one per exercise)
6. `workout_overview`
7. `exercise_overview`
8. `workout_completed`
9. `exit_kinestex`

### Challenge Flow

1. `challenge_started`
2. `exercise_completed`
3. `challenge_completed`
4. `challenge_exit`

### Assessment Flow

1. `kinestex_launched`
2. *(user follows on-screen instructions)*
3. `assessment_overview` — results page loaded
4. `assessment_completed` — user clicked restart/finish
5. `assessment_exit_results` (or `assessment_exit` if abandoned)
6. `exit_kinestex`

### Plan Workout Flow

1. `workout_opened`
2. `workout_started`
3. *(exercises)*
4. `workout_overview`
5. `plan_progression_saved` (if `planId` was passed) or `plan_progression_failed`
6. `workout_completed`

---

## Apployee Pattern: Analytics + Persistence

```dart
class WorkoutAnalyticsService {
  final AnalyticsHelper _analytics = sl<AnalyticsHelper>();
  final WorkoutHistoryRepository _history = sl<WorkoutHistoryRepository>();

  Future<void> handleKinesteXMessage(WebViewMessage message) async {
    if (message is KinestexLaunched) {
      _analytics.track('kinestex_launched', {});
    } else if (message is WorkoutStarted) {
      _analytics.track('workout_started', {
        'workout_id': message.data['id'],
      });
    } else if (message is WorkoutOverview) {
      // Persist + log
      await _history.saveWorkout(_parseOverview(message));
      _analytics.track('workout_completed', {
        'workout_id': message.data['workout_id'],
        'completion_pct': message.data['completion_percentage'],
        'calories': message.data['calories_burned'],
      });
    } else if (message is ExerciseCompleted) {
      _analytics.track('exercise_completed', {
        'exercise_id': message.data['exercise_id'],
        'reps': message.data['repeats'],
      });
    } else if (message is ErrorOccurred) {
      sl<Logger>().error('KinesteX error', message.data);
    }
  }

  WorkoutHistoryEntry _parseOverview(WorkoutOverview message) {
    final d = message.data;
    return WorkoutHistoryEntry(
      workoutId: d['workout_id'] as String,
      title: d['workout_title'] as String,
      durationSeconds: d['workout_duration_seconds'] as int,
      caloriesBurned: (d['calories_burned'] as num).toDouble(),
      completionPercentage: (d['completion_percentage'] as num).toDouble(),
      accuracyScore: (d['accuracy_score'] as num).toDouble(),
      totalReps: d['completed_reps_count'] as int,
      totalMistakes: d['total_mistakes'] as int,
      completedAt: DateTime.now(),
    );
  }
}
```

---

## Common Mistakes

- **Using string-based `message.type == 'workout_completed'`** instead of `message is WorkoutCompleted`. Fragile and breaks on SDK updates.
- **Not handling `ExitKinestex`**: SDK stays mounted but invisible if you don't hide the view.
- **Reading data without null checks**: `message.data['value'] ?? 0` is safer than `message.data['value']`.
- **Logging entire `message.data`**: contains nested objects that may not be JSON-serializable. Pick specific fields.
- **Persisting on every event**: only persist on `workout_overview` (full data) or `exercise_completed` (per-exercise). Don't persist `total_active_seconds` (fires every 5s).
