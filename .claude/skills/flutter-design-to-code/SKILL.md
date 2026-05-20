---
name: flutter-design-to-code
description: Use when the user provides a design (image, screenshot, Figma URL, or visual mockup) and wants Flutter widget code generated from it. Triggers on "build this screen", "convert this design", "make a widget for this", uploaded images of UI mockups, Figma URLs, or any visual input asking for Flutter UI implementation. Produces component-accurate, theme-aware Flutter code using the project's existing colors, common widgets, and responsive system. Does not invent business logic.
---

# Flutter Design to Code

Turns visual designs into idiomatic Flutter widget code. Component-accurate and theme-aware — not pixel-perfect (which requires exact spec values), but production-quality starting code that compiles and integrates with the project's design system.

## Input Types Accepted

- **Screenshots / mockup images** — works best; Claude can see directly
- **Figma URLs** — only useful if the user has Figma MCP integration; otherwise treat as a description and ask for an image export
- **Hand-drawn wireframes** — work but less detail; expect iteration
- **Plain text description** — last resort; ask for an image if available

## Expectation Setting (state upfront in first response)

When the user provides a design, briefly tell them:

> "I'll generate component-accurate code using your project's theme colors, `flutter_screenutil` sizing, and common widgets. Color values, exact spacing, and font weights may need 1-2 rounds of iteration — that's normal. I'll call out my assumptions clearly so you can correct them."

Don't promise pixel-perfection. It's not achievable from an image alone.

## Pre-Generation Discovery (MANDATORY)

Read these files before writing any widget code:

### 1. Theme
- `lib/util/resources/data/colors.dart` (or wherever colors live) — extract palette
- `lib/core/theme/` or `lib/util/theme/` — read text styles, button themes
- Note the primary, secondary, accent colors and their hex values

### 2. Common widgets
- `lib/common/widgets/` — list available shared widgets
- Each shared widget's purpose (button, input, dialog, card, etc.)
- USE existing widgets whenever the design needs one — don't reinvent

### 3. Sizing approach
- Does the project use `flutter_screenutil`? Yes → use `.sp`, `.h`, `.w` extensions
- Mobile design size and tablet design size from `ScreenUtilInit` config

### 4. Responsive pattern
- Does the project have separate `mobile/` and `tablet/` view folders? Match this convention
- Is there an `AppDisplayProvider` or `isMobile`/`isTablet` extension? Use it

### 5. Localization
- Does the project use `context.appLocale` or `AppLocalizations.of(context)`?
- All text strings must use the project's localization pattern — never hard-code

### 6. Existing similar screens
- Find 1-2 existing screens that resemble the new design
- Copy their structure: `ConsumerWidget` extension, layout patterns, state handling

## Generation Workflow

### Step 1: Acknowledge what you see

Describe the design in your own words first. This catches misunderstandings early:

> "I see a notifications screen with: a header (back button + title 'Notifications' + clear-all action), a list of cards each with a colored icon on the left, title + subtitle, timestamp on the right, and an unread indicator dot. Empty state shows when the list is empty. Is that correct?"

Wait for confirmation if anything is ambiguous. Don't ask 5 questions — just confirm the structure.

### Step 2: List assumptions you're making

Be explicit about what you're guessing:

> "Assumptions:
> - Primary color #F15A24 (from your theme)
> - Card background: white with 8px corner radius (matching `dashcams` cards)
> - Spacing: 16px between cards (matching project standard)
> - Font: Inter, body size 14sp
> - Icon size: 24×24
>
> Let me know if any of these are wrong."

### Step 3: Generate the widget

File location: `lib/features/<feature>/presentation/views/mobile/mobile_<feature>_view.dart`

Code requirements:
- `extends ConsumerWidget` (or `ConsumerStatefulWidget` if state needed)
- `const` constructors wherever possible
- Theme colors from `lib/util/resources/data/colors.dart` — no hex literals in widget code
- Sizing via `flutter_screenutil` — no magic numbers
- Strings via `context.appLocale.<key>` — no hard-coded text
- Reuse `lib/common/widgets/` components
- No business logic — `build()` reads from a provider, that's it
- No data fetching in `initState` — that's the notifier's job

### Step 4: Generate localization keys

For every user-visible string, generate the corresponding ARB entries:

```json
// lib/l10n/app_en.arb additions:
"notificationsTitle": "Notifications",
"notificationsEmpty": "No notifications yet",
"notificationsClearAll": "Clear all",
```

User must run `flutter gen-l10n` (or it auto-runs) to regenerate `app_localizations.dart`.

### Step 5: Generate tablet variant (if project has tablet support)

File: `lib/features/<feature>/presentation/views/tablet/tablet_<feature>_view.dart`

Differences from mobile:
- Wider layouts (often 2-column or 3-column)
- Larger paddings/margins
- More content visible at once

If the design only shows mobile, ask: "Should I also generate a tablet layout, or skip until you have a tablet design?"

### Step 6: Routing

Note the routing changes needed (don't apply silently):

```
Add to lib/util/router/paths.dart:
  static const String notifications = '/notifications';

Add to lib/util/router/router.dart:
  GoRoute(path: RoutePaths.notifications, builder: (_, __) => const MobileNotificationsView()),
```

User applies after approval.

## Style Mapping Reference

Common design patterns → Flutter widgets:

| Design element | Flutter widget |
|---|---|
| Rounded card with shadow | `Container` with `BoxDecoration` (color, borderRadius, boxShadow) — or `Card` widget |
| Pill-shaped tag/chip | `Container` with `borderRadius: BorderRadius.circular(999)` |
| Soft drop shadow | `BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: black.withOpacity(0.08))` |
| Icon + text row | `Row` with `Icon` + `SizedBox(width: ...)` + `Text` |
| Two-column list | `Row` of `Expanded` widgets, OR `Wrap` for flexibility |
| Gradient button | `Container` with `LinearGradient` decoration wrapping an `InkWell` |
| Floating action button | `FloatingActionButton.extended` |
| Bottom sheet | `showModalBottomSheet` with `isScrollControlled: true` |
| Tab bar | `DefaultTabController` + `TabBar` + `TabBarView` |
| Form input with floating label | `TextFormField` with `InputDecoration(labelText: ..., floatingLabelBehavior: ...)` |
| Pull-to-refresh | `RefreshIndicator` wrapping a scrollable |

## What to AVOID

- Inline hex color values (`Color(0xFFF15A24)`) — use named theme colors
- Magic spacing numbers (`SizedBox(height: 16)`) — use `16.h` from `flutter_screenutil`
- Hard-coded strings (`Text('Notifications')`) — use `context.appLocale.notifications`
- Building widgets inside helper methods like `Widget _buildHeader() { ... }` — extract to a separate widget class
- Stateful logic in views — notifier handles state
- Custom widgets that duplicate something in `lib/common/widgets/`

## Refusing or Pushing Back

Tell the user honestly if:
- The design implies behavior you can't infer (e.g., a swipe gesture with unspecified animation)
- A specific UI element doesn't translate cleanly to Flutter (e.g., heavy CSS effects, complex SVG animations)
- The design conflicts with the project's theme (e.g., uses a color not in the palette) — ask if it's a new theme color to add, or a one-off

Don't silently approximate. Surface the tradeoff.

## Output Format

After generation, show the user:

```
Generated:
- lib/features/<feature>/presentation/views/mobile/mobile_<feature>_view.dart
- lib/features/<feature>/presentation/views/tablet/tablet_<feature>_view.dart (if applicable)
- l10n keys to add (listed below)

Assumptions made (please verify):
- <list of color/spacing/font guesses>

Not generated (out of scope for this skill):
- Data provider — use `flutter-feature-scaffold` skill
- Tests — use `flutter-testing` skill
- Routing entries — listed for your review

Want me to iterate? Common refinements:
1. Adjust spacing or sizes
2. Change a color or use a different theme token
3. Add an animation
4. Generate tablet variant
```

## Iteration Workflow

User feedback typically falls into:
- "Make X bigger/smaller" → adjust the specific sizing
- "Color is wrong" → swap the theme reference
- "Move X to the right" → restructure layout
- "Match this other screen" → re-read that screen, align patterns

Iterate one change at a time. Show the diff. Don't regenerate the whole file.
