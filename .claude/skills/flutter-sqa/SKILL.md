---
name: flutter-sqa
description: Use when the user wants to test the app end-to-end, generate a QA test plan, scaffold integration tests, or prepare a regression test checklist before release. Triggers on "create SQA plan", "test the whole app", "integration tests for [flow]", "QA checklist for release", "pre-release testing", "regression suite", or "smoke test checklist". Produces practical, executable QA artifacts: integration test files for Flutter and manual test checklists in markdown.
---

# Flutter SQA (Software Quality Assurance)

Practical QA tooling for Flutter apps. Two complementary outputs:

1. **Integration test scaffolding** — `integration_test/` files using `integration_test` package + `flutter_test`
2. **Manual test plan markdown** — human-readable checklists for human QA

This skill does NOT auto-test the app at runtime. Claude cannot drive a real device or emulator. Setting that expectation upfront prevents disappointment.

## When to Use Each Output

| Need | Use |
|---|---|
| Critical user journey (login, checkout, payment) | Integration test |
| Regression coverage of all features for a release | Manual test plan |
| Pre-submission App Store / Play Store smoke test | Manual test plan |
| Verifying a fix didn't break adjacent features | Integration test + targeted manual |
| New feature acceptance | Both |

## Output 1: Integration Test Scaffolding

### Setup (one-time)

Verify or add to `pubspec.yaml`:
```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
```

Create `integration_test/` at project root if absent.

### File location pattern

```
integration_test/
├── app_test.dart                    # smoke test (app launches)
├── flows/
│   ├── login_flow_test.dart         # one file per user journey
│   ├── notifications_flow_test.dart
│   └── ...
└── helpers/
    ├── test_overrides.dart          # mock providers for tests
    └── pump_helpers.dart            # common pumping utilities
```

### Standard test template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apployee/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login Flow', () {
    testWidgets('user can log in with valid credentials', (tester) async {
      // Arrange: launch app with mocked dependencies
      await tester.pumpWidget(
        ProviderScope(
          overrides: [/* mocked providers for deterministic test */],
          child: const app.MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Act: enter phone, password, tap login
      await tester.enterText(find.byKey(const Key('login_phone')), '+31123456789');
      await tester.enterText(find.byKey(const Key('login_password')), 'testpass');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      // Assert: user lands on home screen
      expect(find.byKey(const Key('home_screen')), findsOneWidget);
    });

    testWidgets('shows error on invalid credentials', (tester) async {
      // ... similar pattern
    });
  });
}
```

### Key conventions

- **Use widget keys** for all interactive elements being tested. Add them to production code:
  ```dart
  TextFormField(key: const Key('login_phone'), ...)
  ```
- **Mock external dependencies** — network, storage, Firebase. Use `ProviderScope(overrides: ...)` to inject mocks.
- **One test per scenario** — don't test 5 things in one `testWidgets` block.
- **`pumpAndSettle`** after every async operation; never assume timing.
- **Group by flow**, not by screen.

### What to test in integration tests

- ✅ Critical user journeys (login → home → key action)
- ✅ Cross-screen flows (onboarding → home, list → detail → action)
- ✅ Error states that affect users (offline mode, server error)
- ❌ NOT individual widget styling — that's widget tests
- ❌ NOT business logic — that's unit tests
- ❌ NOT trivial happy paths for low-impact features

### Running

```bash
flutter test integration_test/                              # all tests
flutter test integration_test/flows/login_flow_test.dart    # one file
flutter test integration_test/ --coverage                   # with coverage
```

To run on a device:
```bash
flutter test integration_test/ -d <device-id>
```

## Output 2: Manual Test Plan

### Structure

Produce a markdown file at `docs/qa/<release-tag>_test_plan.md` (or wherever the project documents QA).

### Template

```markdown
# QA Test Plan — <App Name> v<X.Y.Z>+<build>

**Build:** <flavor> — <APK/IPA filename>
**Test date:** <date>
**Tester:** <name>
**Device matrix:** <list of devices to cover>

---

## Smoke Tests (must pass before any deeper testing)

- [ ] App launches without crash on Android
- [ ] App launches without crash on iOS
- [ ] Login flow succeeds with test account
- [ ] Logout works and returns to login screen
- [ ] App survives 5-minute background → foreground cycle

If any smoke test fails: **STOP. Report immediately. Don't continue.**

---

## Feature Test Checklists

### Feature: Login
- [ ] Valid credentials → user lands on home
- [ ] Invalid credentials → inline error shown
- [ ] Empty fields → validation messages
- [ ] Network offline → "no internet" overlay appears
- [ ] Forgot password → flow completes end-to-end
- [ ] Login persists across app restart

### Feature: Home Dashboard
- [ ] All cards render for a fully-flagged user
- [ ] Feature flags hide/show cards correctly (test with restricted user)
- [ ] Pull-to-refresh updates all cards
- [ ] Tapping each card navigates to the right screen

### Feature: <Other features...>
[... repeat pattern per feature ...]

---

## Regression Tests (for areas adjacent to changes in this release)

[Auto-generated based on changed files since last release. If `git log` shows changes to `lib/features/X/`, include X here.]

- [ ] X — all primary flows still work
- [ ] Y — UI didn't shift unexpectedly

---

## Cross-Cutting Tests

### Localization
- [ ] Switch to NL — all strings translated, no English fallback visible
- [ ] Switch back to EN — works without restart
- [ ] Dates and numbers respect locale formatting

### Responsive Layout
- [ ] Mobile portrait — all screens fit, no overflow warnings
- [ ] Mobile landscape — UI adapts or locks (per project policy)
- [ ] Tablet portrait — uses tablet layout where defined
- [ ] Tablet landscape — uses tablet layout where defined

### Edge Cases
- [ ] Slow network (3G throttling) — loading states show, no crashes
- [ ] Offline mode — clear messaging, no fake "loading forever"
- [ ] Background notifications — display correctly
- [ ] Deep link from notification → opens correct screen

### Performance
- [ ] App size: APK ≤ <target> MB
- [ ] App launch time: cold start ≤ <target> seconds
- [ ] Scrolling: no jank in long lists (heaviest screen)

---

## Sign-Off

- [ ] All smoke tests pass
- [ ] All feature checklists pass OR have approved exceptions
- [ ] All regression tests pass
- [ ] No P0 / P1 bugs open

**Tester sign-off:** _________________
**Date:** _________________
```

### Generation workflow

When the user requests a test plan:

1. **Read CLAUDE.md** — get the feature list and known tech debt
2. **Read recent commits** (`git log --oneline -30`) to find changed areas → regression scope
3. **Read release notes** if a release version was provided — focus tests on what's new
4. **Generate the markdown file** with all checklists populated
5. **Highlight critical sections** — auth, payments, anything money-touching gets ⭐ markers

## Acceptance Criteria for New Features

When the user says "what should I test for the new <feature> feature?", produce:

```markdown
# Acceptance Criteria — <Feature>

## Functional
- [ ] Happy path: user can complete the primary action
- [ ] Validation: required fields enforce input rules
- [ ] Error handling: API failures show clear messages
- [ ] Empty state: shown when no data
- [ ] Loading state: skeleton or spinner during fetch

## Edge Cases
- [ ] Network offline mid-action — graceful failure
- [ ] App backgrounded mid-flow → resumes correctly
- [ ] Logout mid-flow → returns to login cleanly

## Visual
- [ ] Matches design (mobile + tablet)
- [ ] Theme colors used consistently
- [ ] Localized in EN + NL

## Integration
- [ ] Does not break adjacent features (list affected features)
- [ ] Updates dependent providers correctly
- [ ] Navigation in/out works from all expected entry points

## Non-Functional
- [ ] No analyzer warnings introduced
- [ ] No new test failures
- [ ] App size impact < X KB
```

## What This Skill DOES NOT Do

- Run tests on a real device (Claude can't drive emulators)
- Generate exhaustive tests for every screen (overkill; focus on critical paths)
- Replace human QA judgment for visual polish, animation timing, "feels off" issues
- Test things outside the app (backend, third-party integrations)
- Generate Patrol or Maestro scripts unless explicitly requested

## Coordination with Other Skills

- For **unit tests** of a single class → use `flutter-testing` skill
- For **scaffolding a new feature with tests** → `flutter-feature-scaffold` then `flutter-testing` then this skill for the user journey test
- For **release prep** → run this skill's "Manual Test Plan" then `flutter-release` skill

## When in Doubt

- Ask the user which features are critical (must work) vs important (should work) vs minor
- If git log doesn't reveal release scope, ask for the list of changed features
- Don't over-test the trivial — every checkbox is a tester's minute
