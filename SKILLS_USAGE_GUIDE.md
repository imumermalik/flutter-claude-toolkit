# Flutter Claude Toolkit — Practical Daily Usage Guide

How to actually use each skill in Apployee. Real prompts, real examples, real workflows.

**Important:** Skills auto-trigger based on what you type. You don't say "use skill X" — you just describe what you want, and Claude picks the right skill. The prompts below are the natural-language phrases that trigger each skill correctly.

---

## Quick Reference — Which skill for what?

| You want to... | Use this skill | Trigger phrase example |
|---|---|---|
| Add a new feature from an API | `flutter-feature-scaffold` | "Build a notifications feature for this API: ..." |
| Convert design to code | `flutter-design-to-code` | "Build this screen" + paste image |
| Write tests | `flutter-testing` | "Write tests for the goals usecase" |
| Audit the project | `flutter-project-audit` | "Audit this project, Phase 1 only" |
| Add a package | `flutter-package-integration` | "I need a package for chart drawing" |
| Find dead code | `flutter-code-hygiene` | "Find dead code in this project" |
| Find unused assets | `flutter-code-hygiene` | "Audit unused assets" |
| Find duplicate widgets | `flutter-code-hygiene` | "Find widget duplication in features" |
| Build APK / IPA | `flutter-environments` + `flutter-release` | "Build production APK" |
| Migrate Riverpod 2.x → 3.x | `flutter-riverpod` | "Migrate this provider to Riverpod 3.x" |
| Set up new flavor | `flutter-environments` | "Add a dev flavor with API mode staticDev" |
| Create QA test plan | `flutter-sqa` | "Create a manual test plan for the v1.0.3 release" |
| Prepare release | `flutter-release` | "Prepare release v1.0.3" |
| Spike SDK question | `spike-dev` (Apployee only) | "How do I enable Spike background delivery?" |
| App Store metadata | `app_store_and_google_play_store_meta_data` (Apployee only) | "Update App Store What's New for v1.0.3" |

---

## Section 1: Building Things

### 1.1 Scaffold a new feature from an API

**Skill:** `flutter-feature-scaffold`

**When to use:** You have an API endpoint (GET, POST, etc.) and need the full DDP slice — DTO, entity, datasource, repository, usecase, provider.

**Prompt template:**
```
Build a [feature_name] feature for this API endpoint.

Endpoint: [METHOD] [PATH]
Auth: [bearer token / public / etc.]
Request body (if any): [paste JSON]
Response: [paste JSON]

Follow this project's exact conventions (DDP, source/remote/, rest_model/, _imp.dart, autogen markers).
Don't generate the view yet — stop at the provider.
Show me the plan first since this will create more than 3 files.
```

**Real example:**
```
Build a "notifications" feature for this API endpoint.

Endpoint: GET /notifications
Auth: bearer token (use stmBearerTokenProvider)
Response:
{
  "data": [
    {"id": "abc", "title": "Welcome", "body": "Thanks for joining", "timestamp": "2026-05-20T10:30:00Z", "isRead": false}
  ]
}

Follow this project's exact conventions. Don't generate the view yet.
Show me the plan first.
```

**What happens:**
1. Claude inspects 2-3 sibling features (dashcams, courses) for the project's pattern
2. Lists all files to create + files to edit
3. Waits for your approval
4. Generates files, runs `build_runner` and `flutter analyze`
5. Reports results

**Combine with:**
- `flutter-design-to-code` → if you have the screen design, share image in same conversation to also get the view
- `flutter-testing` → after scaffold, ask "now write tests for this feature"

---

### 1.2 Convert design to Flutter widget

**Skill:** `flutter-design-to-code`

**When to use:** You have a screen design (screenshot, mockup, Figma export) and want Flutter widget code.

**Prompt template:**
```
Build this screen as a Flutter widget for the [feature_name] feature.

[Attach image]

Use this project's theme colors, flutter_screenutil sizing, and common widgets.
Make it ConsumerWidget. Don't add business logic — just the UI.
Generate mobile + tablet variants if the project has tablet views for this kind of screen.
```

**Real example:**
```
Build this notifications list screen as a Flutter widget.

[image attached: notifications screen with header + list of cards]

Use the project's theme colors. Match the pattern of dashcams list view.
Mobile only — no tablet for now.
```

**What happens:**
1. Claude reads `colors.dart`, common widgets, sibling screens
2. Describes what it sees, lists assumptions
3. Generates the widget file with theme tokens (no hex literals)
4. Lists localization keys to add to ARB files
5. Lists routing edits needed

**Combine with:**
- `flutter-feature-scaffold` → if you don't have the provider yet, scaffold first, then design
- Iterate with feedback: "make the card padding bigger", "use orange for the unread indicator"

---

### 1.3 Migrate Riverpod 2.x to 3.x (one provider at a time)

**Skill:** `flutter-riverpod`

**When to use:** Apployee has 5 legacy `StateNotifier` files (per audit). Migrating one at a time.

**Prompt template:**
```
Migrate this provider to Riverpod 3.x @riverpod codegen.

File: [path]

Follow the project's standard AsyncNotifier pattern (private _fetchX(), sl<> for usecases, AsyncValue.guard for refresh).
Show me the migration plan first. Get my approval before changing the file.
Run flutter analyze after to verify.
```

**Real example:**
```
Migrate this provider to Riverpod 3.x @riverpod codegen.

File: lib/features/profile/presentation/providers/profile_provider.dart

Show me the plan first. Be especially careful since the audit said this file uses fetchProfile() in the constructor (anti-pattern) and has no usecase layer.
```

**What happens:**
1. Claude reads the file + dependent consumers
2. Identifies migration risks
3. Proposes new code structure
4. Waits for approval
5. Migrates, runs `build_runner`, runs `flutter analyze`
6. Reports results

**Important:** For `lib/features/auth/`, skill will be extra cautious per CLAUDE.md (ambiguous cases refuse to auto-migrate).

---

## Section 2: Quality & Cleanup

### 2.1 Find dead code

**Skill:** `flutter-code-hygiene` (Mode 1)

**When to use:** Cleanup pass before release, or "what can I delete from this codebase?"

**Prompt template:**
```
Find dead code in this project. Read-only audit — don't delete anything yet.
Cover:
- Unused imports (auto-fixable via dart fix)
- Unused private members
- Orphan files (no imports point to them)
- Commented-out code blocks

Produce the structured report. I'll approve deletions per category.
```

**What happens:**
1. Claude runs `dart analyze`, `dart fix --dry-run`
2. Greps for orphan files (excluding generated)
3. Detects commented-out code blocks (5+ contiguous comment lines that look like code)
4. Produces categorized report
5. Waits for your approval per category

**After approval:**
```
Delete all auto-fixable items first. Then I'll review orphans one by one.
```

---

### 2.2 Find unused assets

**Skill:** `flutter-code-hygiene` (Mode 2)

**When to use:** App size optimization. Especially before release.

**Prompt template:**
```
Audit unused assets in this project. Be conservative — string interpolation patterns are common, don't flag false positives.
Show me:
- Definitely unused (zero references, no interpolation in folder)
- Possibly unused (interpolation exists nearby)
- Total potential savings
```

**What happens:**
1. Lists all assets from `pubspec.yaml` + `assets/` folder
2. Greps for direct references
3. Detects interpolation patterns
4. Categorizes findings

---

### 2.3 Find widget duplication

**Skill:** `flutter-code-hygiene` (Mode 3)

**When to use:** Widgetization concept — reduce duplicate UI code.

**Prompt template:**
```
Audit widget duplication in lib/features/. Find UI patterns repeated 3+ times that should be extracted to common widgets.
Don't flag generic patterns (Padding, Row) — only meaningful extractions worth ≥10 lines saved per occurrence.
Suggest extraction interfaces.
```

**What happens:**
1. Scans views and widgets folders
2. Identifies repeated structures (status badges, empty state cards, list items)
3. Proposes extracted widget signatures
4. Estimates lines saved

**After approval:**
```
Extract candidate #1 (status badge) to common/widgets/shared/status_badge.dart, then refactor one usage site at a time.
```

---

### 2.4 Write tests for a feature

**Skill:** `flutter-testing`

**When to use:** After scaffolding a feature, or to backfill tests for existing code.

**Prompt template:**
```
Write tests for [feature_name] using flutter_test + mocktail.
Cover:
- Usecase happy path + error path
- Repository delegates to datasource correctly
- Datasource calls the right endpoint + parses correctly
- Notifier state transitions (loading → data, loading → error)
Skip widget tests for now — focus on domain + data + presentation logic.
```

**Real example:**
```
Write tests for the gamification_goals feature.
Cover: GetAllGoalsUsecase, GoalsRepositoryImp, GoalsRemoteDatasourceImp, GetGoals notifier.
Skip widget tests.
```

**What happens:**
1. Reads the feature files
2. Generates test files in mirrored `test/features/<feature>/` structure
3. Uses `mocktail` for mocks, `ProviderContainer` for notifiers
4. Runs `flutter test` to verify all pass

**Note:** Apployee has zero tests currently. First test file establishes the pattern for the project.

---

## Section 3: Auditing & Planning

### 3.1 Full project audit (Phase 1 only)

**Skill:** `flutter-project-audit`

**When to use:** Periodic health check, or before a major migration. Aap ne already kar liya hai.

**Prompt template:**
```
Run a full Phase 1 audit of this Flutter project. Read-only — no changes.
Sample 4-5 features deeply. Be honest and direct.
Output the structured report following the skill template.
```

**Re-run later:** After Phase 1 quick wins are done, re-run to see progress.

---

### 3.2 Per-feature migration (Phase 2)

**Skill:** `flutter-project-audit` (continues from Phase 1)

**When to use:** After audit, pick one feature to migrate.

**Prompt template:**
```
Let's migrate the [feature_name] feature per the audit report.

Phase 2 workflow:
1. Show me pre-migration analysis (files to change, consumers, risks)
2. Propose the step-by-step plan
3. Wait for my approval
4. Execute one step at a time
5. Run flutter analyze + flutter test after each step
6. Stop and report after the feature is done (don't auto-continue to next feature)
```

**Real example (starting Phase 1 of Apployee migration):**
```
Let's migrate the courses feature per the audit.
The audit flagged: courses_repository_imp.dart is in domain/ instead of data/, and category_entity.dart imports flutter/material for IconData.

Show me the migration plan first.
```

---

## Section 4: Package Management

### 4.1 Add a new package

**Skill:** `flutter-package-integration`

**When to use:** Whenever you need a third-party dependency.

**Prompt template:**
```
I need a package for [purpose]. Suggest 2-3 candidates from pub.dev with the full vetting analysis.
Once I approve one, follow the helper-wrapping workflow before any feature code uses it.
```

**Real example:**
```
I need a package for drawing charts (bar + line). We already use fl_chart in this project.
Should we stick with fl_chart or evaluate alternatives?
```

**What happens:**
1. Claude checks if existing package is sufficient
2. If new package needed: fetches pub.dev pages for 2-3 candidates
3. Presents comparison + full vetting template
4. **Waits for explicit approval**
5. Adds package via `flutter pub add`
6. Generates helper interface FIRST (zero package imports)
7. Generates helper impl wrapping the package
8. Registers in DI
9. Only then is package usable

---

## Section 5: Environments & Builds

### 5.1 Build for a specific environment

**Skill:** `flutter-environments`

**When to use:** Daily — running on device, building artifacts.

**Direct commands** (no skill needed, but skill confirms correctness):
```bash
flutter run --flavor staging --dart-define=FLAVOR=staging
flutter build apk --flavor production --dart-define=FLAVOR=production
flutter build appbundle --flavor production --dart-define=FLAVOR=production
```

**Prompt template** (if you want Claude to run them with checks):
```
Build a staging APK for this app. Run the pre-build checks first (analyze, test).
```

---

### 5.2 Add a new flavor (e.g., dev)

**Skill:** `flutter-environments`

**Prompt template:**
```
Add a "dev" flavor to this app.
- Android ID: app.apployee.nl.dev
- iOS Bundle ID: com.apployee.nl.dev
- Display name: Apployee Dev
- API mode: ApiMode.staticDev

This will modify android/ and ios/ — show me the plan and wait for my approval.
```

---

## Section 6: QA & Release

### 6.1 Create a manual QA test plan

**Skill:** `flutter-sqa`

**When to use:** Before any release.

**Prompt template:**
```
Create a manual QA test plan for the v[X.Y.Z] release.
Read git log since v[previous-tag] to identify changed areas → use those for regression focus.
Cover: smoke tests, feature checklists, cross-cutting tests (localization, responsive, edge cases), sign-off section.
Output as docs/qa/v[X.Y.Z]_test_plan.md
```

---

### 6.2 Scaffold integration tests for a critical flow

**Skill:** `flutter-sqa`

**Prompt template:**
```
Scaffold an integration test for the login flow.
Mock external dependencies via ProviderScope overrides.
Test scenarios:
- Valid credentials → user lands on home
- Invalid credentials → error shown
- Offline → "no internet" overlay
Place in integration_test/flows/login_flow_test.dart
```

---

### 6.3 Prepare a release

**Skill:** `flutter-release`

**When to use:** When ready to submit to App Store or Play Store.

**Prompt template:**
```
Prepare release v[X.Y.Z]+[BB] for this app.
- Bump version in pubspec.yaml (REQUIRES MY APPROVAL)
- Generate release notes from git log since v[previous-tag] (EN + NL)
- Update App Store + Play Store metadata files
- Run the pre-submission checklist
- Stop before building — I'll trigger the build manually

Use the .claude/apployee_app_meta_data/ folder for the existing release file structure.
```

**Real example:**
```
Prepare release v1.0.3+9 for Apployee.
Current version is v1.0.2+8.
Use the metadata files in .claude/apployee_app_meta_data/.
```

---

## Section 7: Apployee-Specific Skills

### 7.1 Spike SDK questions

**Skill:** `spike-dev`

**Prompt template:**
```
[Any question about Spike SDK]
e.g. "How do I enable Spike background delivery for steps + heart rate?"
e.g. "Is Nutrition AI feature flag stable?"
```

---

### 7.2 App Store / Play Store metadata edits

**Skill:** `app_store_and_google_play_store_meta_data`

**Prompt template:**
```
Update Apployee's App Store What's New for v1.0.3. Reference recent git commits to write user-facing release notes (EN + NL).
```

---

## Section 8: Common Workflow Combinations

### Workflow A: New feature end-to-end

```
Step 1: "Build a [feature] feature for this API: [paste]"
        → flutter-feature-scaffold

Step 2: [Share design image] "Build the mobile + tablet views"
        → flutter-design-to-code

Step 3: "Write tests for the feature"
        → flutter-testing

Step 4: "Create acceptance criteria checklist for this feature"
        → flutter-sqa
```

### Workflow B: Pre-release cleanup

```
Step 1: "Find dead code"
        → flutter-code-hygiene (Mode 1)

Step 2: "Audit unused assets"
        → flutter-code-hygiene (Mode 2)

Step 3: "Create QA test plan for v[X.Y.Z]"
        → flutter-sqa

Step 4: "Prepare release v[X.Y.Z]"
        → flutter-release
```

### Workflow C: Audit-driven migration

```
Step 1: "Run Phase 1 audit"
        → flutter-project-audit

Step 2: "Migrate [feature] per audit"
        → flutter-project-audit (Phase 2)

Step 3: "Migrate this provider to Riverpod 3.x"
        → flutter-riverpod

Step 4: "Write tests for the migrated feature"
        → flutter-testing
```

---

## Section 9: How Skills Combine

You DON'T need to call skills explicitly. Just describe what you want, and Claude picks the right skill (or combination).

**Examples of multi-skill conversations:**

You: *"Build a payments feature with this API and design"*
→ Triggers `flutter-feature-scaffold` (for API) + `flutter-design-to-code` (for design)

You: *"Add a chart library and use it in driving_behavior"*
→ Triggers `flutter-package-integration` (vetting + helper) + `flutter-architecture` (DDP enforcement on usage)

You: *"Audit the project and start fixing the courses feature"*
→ Triggers `flutter-project-audit` Phase 1 then Phase 2

---

## Section 10: Tips for Better Results

1. **Be specific about scope.** "Migrate one provider" is better than "modernize the codebase."

2. **Reference existing patterns.** "Follow the same pattern as dashcams" helps Claude match conventions.

3. **Ask for plan first when in doubt.** "Show me the plan before changing files" enforces the approval gate even on small changes.

4. **One feature/file at a time.** Big-bang changes are risky. Skills are designed for incremental work.

5. **Trust CURRENT vs TARGET markers.** If CLAUDE.md says `[CURRENT] Riverpod 2.x`, that's what existing code uses. Don't fight it.

6. **Run `flutter analyze` after every change.** Skills do this automatically, but verify.

7. **Use the audit report as your migration backlog.** It's already prioritized.

---

## Common Mistakes to Avoid

- ❌ Asking for too many things in one prompt → split it up
- ❌ Skipping the approval gate when Claude proposes a plan → review it
- ❌ Migrating multiple features in parallel → one at a time
- ❌ Trusting Claude's training data over the docs → docs win, always
- ❌ Forgetting to commit between phases → small commits = easy rollback

---

## When Things Go Wrong

- **Skill didn't trigger as expected** → rephrase using one of the trigger phrases from the Quick Reference table
- **Claude proposed something that violates CLAUDE.md** → push back, cite the rule. Skills respect CLAUDE.md but aren't perfect
- **`flutter analyze` fails after a skill's changes** → ask Claude to revert and try a different approach
- **Tests break after a refactor** → that's the skill working correctly; the refactor revealed a bug

---

## Reference: All 13 Skills in Apployee

| Skill | Triggers |
|---|---|
| flutter-architecture | Every Dart code task |
| flutter-riverpod | Provider/notifier work, state management |
| flutter-environments | Flavors, builds, `dart-define` |
| flutter-package-integration | "Add package", "pub.dev" |
| flutter-project-audit | "Audit", "review architecture", "migrate" |
| flutter-feature-scaffold | API → feature, JSON/cURL paste |
| flutter-testing | "Write tests", "TDD", "BDD" |
| flutter-code-hygiene | "Dead code", "unused assets", "duplication" |
| flutter-design-to-code | Image upload, "build this screen" |
| flutter-sqa | "Test plan", "QA checklist", "integration tests" |
| flutter-release | "Prepare release", "store metadata", "ASO" |
| spike-dev | Spike SDK questions |
| app_store_and_google_play_store_meta_data | App Store / Play Store metadata edits |

---

**Save this file.** Reference it whenever you start a new task. Skills auto-trigger from natural language — you don't need to memorize trigger phrases, just describe what you want clearly.
