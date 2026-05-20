---
name: flutter-testing
description: Use whenever the user asks for tests in a Flutter project. Triggers on "write tests for X", "TDD this feature", "add unit tests", "test this usecase", "BDD for login flow", "scaffold tests", "test the notifier", "add widget tests", or any request to generate or improve Dart/Flutter test files. Generates idiomatic tests using flutter_test + mocktail for TDD and bdd_widget_test for BDD. Respects project's existing test patterns if any exist.
---

# Flutter Testing

Generates test files following AAA (Arrange-Act-Assert) pattern, with the right mocks, the right scope, and no over-engineering.

## Tools (default)

- **TDD:** `flutter_test` (built-in) + `mocktail` (preferred over `mockito` — no codegen required)
- **BDD:** `bdd_widget_test` (generates Gherkin `.feature` files + step definitions)
- **Coverage:** `flutter test --coverage` → `coverage/lcov.info`

If the project uses different tools (e.g., `mockito`, `flutter_gherkin`), match the existing convention.

## Coverage Targets

- **Domain layer (usecases, entities):** ≥ 70% — easy to test, high value
- **Data layer (repositories, datasources):** ≥ 70% — mock the helper, verify the call shape and parsing
- **Presentation (notifiers):** ≥ 50% — test state transitions, not widget pixels
- **Widget tests:** opt-in per feature, not a blanket requirement — they're expensive to maintain

Do not chase 100% coverage. Chase meaningful coverage.

## Pre-Test Discovery

Before writing tests, check:

1. **Does `test/` exist and have anything beyond `widget_test.dart`?**
   - If yes, sample 1-2 existing tests for the project's style
   - If no, this is greenfield — establish the pattern

2. **Is `mocktail` (or `mockito`) in `dev_dependencies`?**
   - If neither: prompt the user to approve adding `mocktail` (uses `flutter-package-integration` skill rules)

3. **Does the project use a custom test harness?** (helper functions for `ProviderContainer` setup, common mocks)
   - If yes, use it
   - If no, generate inline

## Test File Locations

Mirror the `lib/` structure under `test/`:

```
test/
├── features/
│   └── <feature>/
│       ├── domain/
│       │   └── usecases/
│       │       └── <verb>_<feature>_test.dart
│       ├── data/
│       │   ├── repository/
│       │   │   └── <feature>_repository_imp_test.dart
│       │   └── source/remote/
│       │       └── <feature>_remote_datasource_imp_test.dart
│       └── presentation/
│           └── providers/
│               └── <verb>_<feature>_provider_test.dart
└── helpers/
    └── <helper>/
        └── <helper>_impl_test.dart
```

## Test Patterns by Layer

### 1. Usecase Tests (domain)

Highest priority. Cheap to write, high signal.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockXRepository extends Mock implements XRepository {}

void main() {
  late MockXRepository repository;
  late GetXUsecase usecase;

  setUp(() {
    repository = MockXRepository();
    usecase = GetXUsecase(repository: repository);
    registerFallbackValue(GetXUsecaseInput(bearerToken: 'test'));
  });

  group('GetXUsecase', () {
    test('returns output from repository', () async {
      final input = GetXUsecaseInput(bearerToken: 'abc');
      final expected = GetXUsecaseOutput(items: [/* ... */]);
      when(() => repository.getX(any())).thenAnswer((_) async => expected);

      final result = await usecase(input);

      expect(result, expected);
      verify(() => repository.getX(input)).called(1);
    });

    test('propagates repository exceptions', () async {
      when(() => repository.getX(any())).thenThrow(Exception('network'));
      expect(() => usecase(GetXUsecaseInput(bearerToken: 'abc')),
          throwsException);
    });
  });
}
```

### 2. Repository Tests (data)

Mock the datasource. Verify the impl delegates correctly.

```dart
class MockXDatasource extends Mock implements XRemoteDatasource {}

void main() {
  late MockXDatasource datasource;
  late XRepositoryImp repository;

  setUp(() {
    datasource = MockXDatasource();
    repository = XRepositoryImp(xRemoteDatasource: datasource);
  });

  test('getX delegates to datasource and returns output', () async {
    final input = GetXUsecaseInput(bearerToken: 'abc');
    final entities = [/* ... */];
    when(() => datasource.fetchX(any())).thenAnswer((_) async => entities);

    final result = await repository.getX(input);

    expect(result.items, entities);
  });
}
```

### 3. Datasource Tests (data)

Mock the HTTP helper. Verify request shape and response parsing.

```dart
class MockHttpHelper extends Mock implements HttpNetworkCallHelper {}

void main() {
  late MockHttpHelper http;
  late XRemoteDatasourceImp datasource;

  setUp(() {
    http = MockHttpHelper();
    datasource = XRemoteDatasourceImp(httpHelper: http);
  });

  test('fetchX calls correct endpoint with bearer token', () async {
    when(() => http.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => '''{"items":[...]}''');

    final result = await datasource.fetchX(bearerToken: 'abc');

    verify(() => http.get('/notifications',
        headers: {'Authorization': 'Bearer abc'})).called(1);
    expect(result, isA<List<XEntity>>());
  });

  test('throws SomethingWentWrongException on malformed response', () async {
    when(() => http.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => 'not-json');

    expect(() => datasource.fetchX(bearerToken: 'abc'),
        throwsA(isA<SomethingWentWrongException>()));
  });
}
```

### 4. Riverpod Notifier Tests (presentation)

Use `ProviderContainer` with overrides. Always `addTearDown(container.dispose)`.

```dart
class MockGetXUsecase extends Mock implements GetXUsecase {}

void main() {
  late MockGetXUsecase usecase;

  setUp(() {
    usecase = MockGetXUsecase();
    // If usecases are resolved via sl<>, override the sl registration here
    sl.registerSingleton<GetXUsecase>(usecase);
    registerFallbackValue(GetXUsecaseInput(bearerToken: 'test'));
  });

  tearDown(() => sl.reset());

  ProviderContainer makeContainer({String bearer = 'abc'}) {
    final container = ProviderContainer(
      overrides: [
        stmBearerTokenProvider.overrideWith((ref) async => bearer),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('build returns list from usecase', () async {
    final entities = [/* ... */];
    when(() => usecase(any())).thenAnswer(
      (_) async => GetXUsecaseOutput(items: entities),
    );

    final container = makeContainer();
    final value = await container.read(getXProvider.future);

    expect(value, entities);
  });

  test('build transitions to error on usecase failure', () async {
    when(() => usecase(any())).thenThrow(Exception('boom'));

    final container = makeContainer();
    final result = await container.read(getXProvider.future)
        .then<Object>((v) => v)
        .catchError((e) => e);

    expect(result, isA<Exception>());
  });
}
```

### 5. Widget Tests (opt-in)

Pump a widget with required providers overridden. Verify rendered text/state.

```dart
testWidgets('shows loading then list', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        getXProvider.overrideWith(() => MockGetXNotifier(...)),
      ],
      child: const MaterialApp(home: XView()),
    ),
  );
  await tester.pump(); // initial frame
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('Notification 1'), findsOneWidget);
});
```

## BDD Tests (when explicitly requested)

Use `bdd_widget_test`. Generate:

1. `test/features/<feature>/<feature>.feature` — Gherkin scenarios
2. `test/features/<feature>/<feature>_test.dart` — auto-generated step bindings (re-run codegen if scenarios change)
3. `test/features/<feature>/steps/` — custom step definitions

Example `.feature`:
```gherkin
Feature: Notifications list

  Scenario: User sees notifications after login
    Given the user is logged in
    When the user opens the notifications screen
    Then the notifications list is shown
    And the first notification has title "Welcome"
```

BDD is verbose. Recommend it only for critical user journeys (login, checkout, etc.), not for every CRUD screen.

## Anti-Patterns to Reject

| Anti-pattern | Replace with |
|---|---|
| Test calling real HTTP / Firebase | Mock the helper |
| Tests sharing state via top-level variables | Use `setUp` to reset |
| Tests asserting on private implementation details | Assert on behavior, not internals |
| Forgetting `addTearDown(container.dispose)` | Always dispose ProviderContainer |
| `expect(actual, equals(actual))` (tautology) | Compare against expected value |
| Skipping `registerFallbackValue` for mocked args | Always register fallback for non-primitive types |
| Catching all errors with `expect(..., throwsException)` | Use specific exception types |
| Widget tests for trivial UI | Snapshot or skip |

## Workflow

1. **Identify scope** — which layer is being tested? (Usecase / repo / datasource / notifier / widget)
2. **Find or create the mock helpers** — `MockXRepository`, `MockHttpNetworkCallHelper`, etc.
3. **Write 2-4 test cases per file**:
   - Happy path
   - One error path (network/parse/exception)
   - Edge case relevant to the unit (empty list, null field, etc.)
4. **Run**: `flutter test <path>` — must pass
5. **Coverage check** (optional): `flutter test --coverage` and compare against target

## When in Doubt

- Look at existing tests in `test/` for the project's style
- If no existing tests: this skill establishes the pattern — follow the templates above
- Don't write tests for code you don't understand; ask the user to explain the intent first
- If a test is hard to write, the code under test usually needs refactoring (a code smell, not a test smell)
