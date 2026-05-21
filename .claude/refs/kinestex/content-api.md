# KinesteX Content API — Flutter Reference

**Loaded by:** `flutter-kinestex` skill when fetching workouts, plans, or exercises from KinesteX content servers.
**Source:** https://www.kinestex.com/docs/content-api

Use the Content API to build your own content browsing UI for KinesteX workouts/plans/exercises.

---

## SDK vs REST

**Flutter SDK** has built-in convenience: `KinesteXAIFramework.apiService.fetchContent(...)`. Use it. Don't make raw HTTP calls.

---

## Available Endpoints

| `ContentType` | Returns |
|---|---|
| `ContentType.workout` | Workouts |
| `ContentType.plan` | Workout plans |
| `ContentType.exercise` | Exercises |

---

## Parameters

| Parameter | Type | Description |
|---|---|---|
| `contentType` | `ContentType` | Required |
| `category` | `String?` | Filter. **REQUIRED for plans** in Flutter |
| `bodyParts` | `List<BodyPart>?` | Filter by targeted body parts |
| `includeKinestex` | `bool` | Include KinesteX library (default `true`). Set `false` for custom-only content |
| `limit` | `int` | Results per page (default 10) |
| `lang` | `String` | Language code (default `'en'`) |
| `lastDocId` | `String?` | For pagination |
| `id` | `String?` | Fetch single item by ID |
| `title` | `String?` | Fetch single item by title (case-insensitive, first match) |

---

## Categories

**Workouts:** `'Fitness'`, `'Rehabilitation'`

**Plans:** `'Strength'`, `'Cardio'`, `'Weight Management'`, `'Rehabilitation'`

⚠️ **Plans REQUIRE a `category`** in Flutter SDK. Without it, the SDK may interpret the response as `PlanResult` (single) instead of `PlansResult` (list).

---

## Body Parts (BodyPart enum)

`BodyPart.abs`, `.biceps`, `.calves`, `.chest`, `.externalOblique`, `.forearms`, `.glutes`, `.hamstrings`, `.lats`, `.lowerBack`, `.neck`, `.quads`, `.shoulders`, `.traps`, `.triceps`, `.fullBody`

---

## Fetching Workouts

```dart
Future<void> fetchWorkouts() async {
  final result = await KinesteXAIFramework.apiService.fetchContent(
    contentType: ContentType.workout,
    category: 'Fitness',
    bodyParts: [BodyPart.abs, BodyPart.glutes],
    limit: 10,
  );

  switch (result) {
    case WorkoutsResult(:final response):
      final workouts = response.workouts;  // List<WorkoutModel>
      for (final w in workouts) {
        debugPrint('${w.title} - ${w.totalMinutes} min');
      }
      // Store for pagination
      final nextPageId = response.lastDocId;
    case ErrorResult(:final message):
      debugPrint('Error: $message');
    default:
      break;
  }
}
```

---

## Fetching Plans

```dart
Future<void> fetchPlans() async {
  final result = await KinesteXAIFramework.apiService.fetchContent(
    contentType: ContentType.plan,
    category: 'Strength',  // REQUIRED
    limit: 5,
  );

  switch (result) {
    case PlansResult(:final response):
      final plans = response.plans;  // List<PlanModel>
    case ErrorResult(:final message):
      // handle error
    default:
      break;
  }
}
```

---

## Fetching Exercises

```dart
Future<void> fetchExercises() async {
  final result = await KinesteXAIFramework.apiService.fetchContent(
    contentType: ContentType.exercise,
    bodyParts: [BodyPart.abs, BodyPart.glutes],
    limit: 10,
  );

  switch (result) {
    case ExercisesResult(:final response):
      for (final ex in response.exercises) {
        debugPrint('${ex.title} (model: ${ex.modelId})');
        // Use ex.modelId for Camera Component
      }
    case ErrorResult(:final message):
      // handle
    default:
      break;
  }
}
```

---

## Fetching Single Item by ID

```dart
Future<WorkoutModel?> fetchWorkoutById(String id) async {
  final result = await KinesteXAIFramework.apiService.fetchContent(
    contentType: ContentType.workout,
    id: id,
  );

  switch (result) {
    case WorkoutResult(:final workout):
      return workout;
    case ErrorResult():
      return null;
    default:
      return null;
  }
}
```

Same pattern for `ExerciseResult` and `PlanResult`.

---

## Fetching by Title

```dart
final result = await KinesteXAIFramework.apiService.fetchContent(
  contentType: ContentType.workout,
  title: 'Fitness Lite',
);
```

⚠️ Title matching is case-insensitive but locale-dependent. For production, prefer IDs.

---

## Pagination

```dart
Future<List<WorkoutModel>> fetchAllWorkouts() async {
  final all = <WorkoutModel>[];
  String? lastDocId;

  do {
    final result = await KinesteXAIFramework.apiService.fetchContent(
      contentType: ContentType.workout,
      category: 'Fitness',
      limit: 20,
      lastDocId: lastDocId,
    );

    switch (result) {
      case WorkoutsResult(:final response):
        all.addAll(response.workouts);
        lastDocId = response.lastDocId.isNotEmpty ? response.lastDocId : null;
      case ErrorResult(:final message):
        throw Exception(message);
      default:
        lastDocId = null;
    }
  } while (lastDocId != null);

  return all;
}
```

---

## Excluding KinesteX Library (Custom Content Only)

```dart
final result = await KinesteXAIFramework.apiService.fetchContent(
  contentType: ContentType.workout,
  category: 'Fitness',
  includeKinestex: false,  // your own content only
  limit: 10,
);
```

---

## Data Models

### `WorkoutModel`

| Field | Type |
|---|---|
| `id` | `String` |
| `title` | `String` |
| `category` | `String` |
| `calories` | `int?` |
| `totalMinutes` | `int?` |
| `bodyParts` | `List<String>` |
| `difficultyLevel` | `String?` |
| `description` | `String` |
| `imgURL` | `String` |
| `sequence` | `List<ExerciseModel>` |

### `ExerciseModel`

| Field | Type |
|---|---|
| `id` | `String` |
| `title` | `String` |
| `bodyParts` | `List<String>` |
| `videoURL` | `String` |
| `thumbnailURL` | `String` |
| `modelId` | `String` |
| `description` | `String` |
| `steps` | `List<String>` |
| `commonMistakes` | `String` |
| `tips` | `String` |

### `PlanModel`

| Field | Type |
|---|---|
| `id` | `String` |
| `title` | `String` |
| `imgURL` | `String` |
| `category` | `PlanModelCategory` |
| `levels` | `Map<String, PlanLevel>` |
| `createdBy` | `String` |

### `PlanLevel`

```dart
{
  title: String,
  description: String,
  days: Map<String, PlanDay>,  // '1', '2', etc.
}
```

### `PlanDay`

```dart
{
  title: String,
  description: String,
  workouts: List<WorkoutSummary>?,
}
```

---

## Error Handling

```dart
Future<List<WorkoutModel>> fetchSafely() async {
  try {
    final result = await KinesteXAIFramework.apiService.fetchContent(
      contentType: ContentType.workout,
      category: 'Fitness',
    );

    return switch (result) {
      WorkoutsResult(:final response) => response.workouts,
      ErrorResult(:final message) => throw KinesteXContentException(message),
      RawDataResult(:final errorMessage) => throw KinesteXContentException(errorMessage ?? 'Parse error'),
      _ => <WorkoutModel>[],
    };
  } on SocketException {
    throw NetworkException('No internet connection');
  } on TimeoutException {
    throw NetworkException('Request timed out');
  }
}
```

---

## Result Types

| Result type | When |
|---|---|
| `WorkoutResult` | Single workout (by `id` or `title`) |
| `WorkoutsResult` | List of workouts |
| `PlanResult` | Single plan |
| `PlansResult` | List of plans (requires `category`) |
| `ExerciseResult` | Single exercise |
| `ExercisesResult` | List of exercises |
| `ErrorResult` | API returned an error |
| `RawDataResult` | Parsing failed, raw data + error message available |

---

## Apployee Pattern: Content Browser with Riverpod

```dart
// Repository (in helpers, not full DDP)
class KinesteXContentRepository {
  Future<List<WorkoutModel>> fetchWorkoutsByCategory(String category) async {
    final result = await KinesteXAIFramework.apiService.fetchContent(
      contentType: ContentType.workout,
      category: category,
      limit: 20,
    );

    return switch (result) {
      WorkoutsResult(:final response) => response.workouts,
      ErrorResult(:final message) => throw KinesteXContentException(message),
      _ => <WorkoutModel>[],
    };
  }
}

// Provider
@riverpod
Future<List<WorkoutModel>> kinestexWorkoutsByCategory(
  Ref ref,
  String category,
) async {
  return sl<KinesteXContentRepository>().fetchWorkoutsByCategory(category);
}

// Widget
class WorkoutListScreen extends ConsumerWidget {
  final String category;
  const WorkoutListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(kinestexWorkoutsByCategoryProvider(category));

    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: workoutsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workouts) => ListView.builder(
          itemCount: workouts.length,
          itemBuilder: (context, i) {
            final w = workouts[i];
            return ListTile(
              leading: w.imgURL.isNotEmpty
                  ? Image.network(w.imgURL, width: 56)
                  : null,
              title: Text(w.title),
              subtitle: Text('${w.totalMinutes} min · ${w.calories ?? 0} cal'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutScreen(workoutId: w.id),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

---

## Response Status Codes

| Status | Meaning |
|---|---|
| 200/201 | Success |
| 400 | Validation error (check params) |
| 401 | Unauthorized (bad API key) |
| 404 | Content not found |
| 500 | Internal server error |

The SDK wraps these in `ErrorResult` — you don't deal with raw HTTP codes typically.
