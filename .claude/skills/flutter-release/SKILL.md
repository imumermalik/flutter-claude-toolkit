---
name: flutter-release
description: Use when the user wants to prepare a Flutter app release. Triggers on "prepare release", "build for release", "update release notes", "App Store metadata", "Play Store listing", "ASO review", "submit to stores", "pre-submission checklist", "what's new section", or anything related to publishing to Apple App Store or Google Play Store. Handles build commands, release notes (EN + localized), store metadata with character limits, ASO checks, and rejection-prevention checklists.
---

# Flutter Release

End-to-end release workflow for Flutter apps — from build to store submission. Covers Apple App Store and Google Play Store with their specific quirks. Generates release notes from git log, store metadata respecting character limits, and pre-submission checklists.

## What This Skill Covers

1. **Build commands** per environment (already in `flutter-environments`, but this skill orchestrates release builds specifically)
2. **Release notes generation** from git log (EN + localized)
3. **Store metadata** — titles, descriptions, keywords, promotional text (with character limit enforcement)
4. **ASO checklist** — keyword research prompts, screenshot specs, app preview specs
5. **Pre-submission checklist** — common rejection reasons, declarations, privacy
6. **Post-release** — release history archiving, version bumping

## Release Workflow Overview

```
1. Bump version → 2. Build → 3. Generate release notes → 
4. Update store metadata → 5. Run pre-submission checklist → 
6. Manual submission → 7. Archive
```

Claude assists with steps 1, 3, 4, 5, and 7. Steps 2 (build) and 6 (manual submission) are user actions.

---

## Step 1: Version Bump

Conventions:
- `pubspec.yaml` version: `<major>.<minor>.<patch>+<build>`
- Build number increments every submission, never resets
- Patch for hotfixes, minor for new features, major for breaking changes

Workflow:
1. Ask user: current version + target version
2. Update `pubspec.yaml`
3. Confirm: this requires approval (gated file)
4. After approval, edit and commit (commit requires its own approval)

---

## Step 2: Build Commands

### Production builds (signed)

```bash
# Android APK (sideload + Firebase App Distribution)
flutter build apk --release --flavor production --dart-define=FLAVOR=production

# Android App Bundle (Play Store)
flutter build appbundle --release --flavor production --dart-define=FLAVOR=production

# iOS (requires Xcode for archive + IPA + App Store Connect upload)
flutter build ios --release --flavor production --dart-define=FLAVOR=production
# Then in Xcode: Product → Archive → Distribute App
```

### Staging builds (for QA)

```bash
flutter build apk --release --flavor staging --dart-define=FLAVOR=staging
flutter build appbundle --release --flavor staging --dart-define=FLAVOR=staging
```

### Before any release build:

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze  # MUST be clean
flutter test     # MUST pass
```

If analyze has warnings or tests fail: **stop, fix, then build.**

---

## Step 3: Release Notes Generation

### Sources
- Git log since last release tag: `git log <last-tag>..HEAD --oneline --no-merges`
- Recent PRs / commits
- Existing release notes file structure (look in `.claude/<app>_meta_data/` or `docs/` for the project's pattern)

### Structure (Google Play Store)

**Character limit:** 500 chars per language.

```
Apployee v1.0.3 — Performance Improvements

What's new:
• Faster goal toggling — completes in under 200ms
• Fixed crash on dashcam alerts when opening from notification
• Improved offline mode messaging
• Smaller app size — 8% reduction from last release

Thanks for using Apployee!
```

### Structure (Apple App Store — "What's New in This Version")

**Character limit:** 4000 chars (but keep under 500 — users skim).

Format identical to Play Store. Apple is stricter about "bug fixes and improvements" — be specific about what changed.

### Promotional Text (Apple only)

**Character limit:** 170 chars. Updateable without re-submission.

Use for: highlighting a current feature, announcing a sale/event, calling attention to new functionality.

```
New: real-time goal leaderboards. Track your team's performance and earn badges. Update now for the smoothest dashcam playback yet.
```

### Localized Release Notes (NL example)

```
Apployee v1.0.3 — Prestatieverbeteringen

Wat is er nieuw:
• Snellere doelschakeling — voltooit in minder dan 200ms
• Crash opgelost bij dashcam-meldingen vanuit pushmeldingen
• Verbeterde offline-modus berichten
• Kleinere app — 8% kleiner dan vorige versie

Bedankt voor het gebruik van Apployee!
```

### Workflow for generation

1. Read git log since last release
2. Group commits into: New features / Improvements / Bug fixes
3. Translate jargon to user-facing language ("Refactored AsyncNotifier in goals" → "Faster goal toggling")
4. Drop internal changes (refactors, test additions, docs) unless they affect users
5. Check character count → trim if over
6. Present EN draft → user reviews → produce NL translation
7. Save to project's release notes file

---

## Step 4: Store Metadata

### Apple App Store metadata

| Field | Char limit | Notes |
|---|---|---|
| App Name | 30 | Visible on home screen, in search |
| Subtitle | 30 | Below name in App Store; descriptive tagline |
| Promotional Text | 170 | Updatable anytime; use for announcements |
| Description | 4000 | Long form; first 2-3 lines critical (above "more" fold) |
| Keywords | 100 (comma-sep) | NOT visible to users; ASO ranking signal |
| Support URL | — | Required |
| Marketing URL | — | Optional |
| Privacy Policy URL | — | REQUIRED — see project's privacy policy file |
| What's New | 4000 | Per-release; see Step 3 |

### Google Play Store metadata

| Field | Char limit | Notes |
|---|---|---|
| App Name | 30 | Visible everywhere |
| Short Description | 80 | Shown above the fold on store page |
| Full Description | 4000 | Long form |
| Release Notes | 500 per language | See Step 3 |
| Contact Email | — | Required |
| Privacy Policy URL | — | REQUIRED |
| Category | — | Pick one primary |
| Content Rating | — | Required questionnaire |
| Tags | up to 5 | Helps discovery |

### Character limit enforcement

When generating metadata, ALWAYS check character count and show it:
```
App Name: "Apployee" (8/30)
Subtitle: "Drive smarter, work better" (26/30)
Promotional Text: "..." (162/170) ⚠️ close to limit
Description: "..." (3247/4000) ✅
```

If over limit, propose specific trims. Don't silently truncate.

---

## Step 5: ASO Checklist

ASO = App Store Optimization. Goal: more visibility in store search.

### Keywords (Apple)
- 100 chars total, comma-separated
- Don't repeat words across name/subtitle/keywords (Apple counts each only once)
- Include: app category, key features, common search terms, competitor app names (if relevant)
- Don't include: "app", "free", brand names you don't own, plurals if singular already there

Example:
```
employee,driver,fleet,management,vitality,dashcam,goals,courses,leaderboard,team,performance
```
(95/100 ✅)

### Tags (Play Store)
Up to 5. Pick from Play Console's predefined list. Choose the most specific that fit.

### Screenshots
Required dimensions (current Apple guidelines — verify via web_fetch before each release):
- iPhone 6.7" (1290 × 2796)
- iPhone 6.5" (1284 × 2778 or 1242 × 2688)
- iPad 12.9" (2048 × 2732)
- (Other sizes auto-derived by Apple)

Play Store:
- Phone: 1080 × 1920 minimum
- 7-inch tablet: 1024 × 600 minimum
- 10-inch tablet: 1280 × 800 minimum

**Best practice:** 3-5 screenshots showing core flows. First screenshot is the most important — make it count.

### App Preview Video (Apple) / Promo Video (Play)
- Apple: 15-30 seconds, captured from the actual app, .mp4 or .mov
- Play: link to YouTube video, 30 seconds recommended

### Localization
List languages the app supports. Each gets its own metadata + screenshots.

---

## Step 6: Pre-Submission Checklist

Common rejection reasons and what to verify before hitting "Submit."

### Apple App Store

- [ ] **Privacy Policy URL** works (publicly accessible, not localhost or staging URL)
- [ ] **Data Collection declarations** match what the app actually does (App Store Connect → Privacy)
- [ ] **Sign in with Apple** required if you offer third-party sign-in (Google, Facebook) — otherwise rejection
- [ ] **In-App Purchase** uses Apple's IAP, NOT external payment links (rejected immediately)
- [ ] **IDFA usage** declared if you use it
- [ ] **Camera / Location / Mic** usage descriptions in `Info.plist` — must be specific, not "We need camera"
- [ ] **Background modes** match what's declared
- [ ] **Demo account** provided if app requires login (App Review notes)
- [ ] **Test instructions** explain how to reach all features (especially gated ones)
- [ ] **Functionality complete** — no placeholder screens, no "coming soon" buttons
- [ ] **Encryption usage declaration** filled if using non-standard encryption
- [ ] **Age rating** matches content

### Google Play Store

- [ ] **Privacy Policy URL** works and is current
- [ ] **Data safety form** completed accurately (Play Console)
- [ ] **Content rating** questionnaire completed
- [ ] **Target API level** meets Play's current minimum (verify via Play Console message — Google updates this yearly)
- [ ] **Sensitive permissions** justified (location background, all-files access, etc.)
- [ ] **App Bundle** uploaded, not APK (Play requires AAB for new apps)
- [ ] **Signing key** managed by Play App Signing (recommended)
- [ ] **Test track** used before production rollout (internal → closed → open → production)
- [ ] **Crash-free rate** acceptable (check Firebase Crashlytics for last week's data)
- [ ] **64-bit support** included (default for Flutter, verify)

### Both platforms

- [ ] **App icon** correct in all required sizes
- [ ] **Launch screen** doesn't show debug or staging branding
- [ ] **Version & build number** match `pubspec.yaml`
- [ ] **App ID** matches the platform (no staging IDs in production submission)
- [ ] **Crashes** — run a full test pass on a clean device install
- [ ] **Permission prompts** all have rationale text users will understand

---

## Step 7: Post-Release Archiving

After successful submission:

1. **Move current release content to history**
   - In `release_notes_en.md` and `release_notes_nl.md`: cut the current content, paste under a "Release History" section at the bottom
2. **Tag the release** in git:
   ```bash
   git tag -a v1.0.3 -m "Release v1.0.3 — Performance Improvements"
   git push origin v1.0.3
   ```
   (Tag operations require approval — they affect remote state.)
3. **Update version in CLAUDE.md** if it tracks the current version
4. **Note submission status** — submitted, in review, released
5. **Suggest** running `flutter-sqa` skill for the production smoke test once live

---

## Project-Specific Reference Files

When working in a specific project, check for:
- `.claude/<app>_meta_data/` folder for app store metadata, release notes
- `docs/releases/` or `RELEASES.md` for release history
- Privacy policy and terms files

Apployee specifically has:
- `.claude/apployee_app_meta_data/apple_appstore_release_notes.txt`
- `.claude/apployee_app_meta_data/apployee_apple_appstore_metadata.md`
- `.claude/apployee_app_meta_data/apployee_google_playstore_metadata.md`
- `.claude/apployee_app_meta_data/appstore_release_v1.0.2+8.md`
- `.claude/apployee_app_meta_data/google_play_release_v1.0.2+8.md`

Use these as the source of truth for Apployee releases. The `app_store_and_google_play_store_meta_data` skill (project-specific) handles deeper interaction with these files.

---

## When to Refuse / Push Back

- Submitting on a Friday afternoon → suggest Monday (Apple review during weekends is slower; rollback options are worse)
- Submitting with known P0/P1 bugs → strongly recommend hotfix first
- Submitting without testing on a real device → flag this risk
- Bumping major version for minor changes → suggest minor bump instead
- Changing app name post-launch → warn about brand recognition impact

## Verification Against Current Store Policies

Apple and Google update their policies regularly. Before any release:
1. `web_fetch` Apple's current App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
2. `web_fetch` Google Play's current policies: https://support.google.com/googleplay/android-developer/

Cite specific guideline references if a checklist item is gating submission.

## Output Format

When asked "prepare release v1.0.3":

```
# Release v1.0.3 Preparation Plan

## Status
- Last release: v1.0.2+8 (date)
- Target: v1.0.3+9
- Changed since last release: <N commits, summary>

## To Do
1. [ ] Bump version in pubspec.yaml (1.0.2+8 → 1.0.3+9) — REQUIRES APPROVAL
2. [ ] Generate release notes (EN + NL)
3. [ ] Update App Store / Play Store "What's New"
4. [ ] Run pre-submission checklist
5. [ ] Build release artifacts (apk, aab, ipa)
6. [ ] Submit (manual)
7. [ ] Tag git after successful submission — REQUIRES APPROVAL

Which do you want me to start with?
```
