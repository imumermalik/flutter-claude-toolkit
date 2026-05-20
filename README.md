# Flutter Claude Toolkit

A reusable [Claude Code](https://docs.claude.com/en/docs/claude-code) skill suite for Flutter projects. Drop-in architecture enforcement, Riverpod patterns, helper abstraction, feature scaffolding, testing, code hygiene, design-to-code, QA, and release workflows — all designed to share one philosophy: **lean skills, project-specific CLAUDE.md, no magic.**

---

## What's in the toolkit

11 skills covering the full Flutter development lifecycle:

| Skill | Triggers on | What it does |
|---|---|---|
| **flutter-architecture** | Any `.dart` code work | DDP layer enforcement, SOLID, helper abstraction rule, anti-pattern detection |
| **flutter-riverpod** | Provider work, state management | Provider patterns, `@riverpod` codegen, 2.x → 3.x migration playbook |
| **flutter-environments** | Flavor setup, build/run commands | Flavors, `--dart-define`, per-environment Firebase configs |
| **flutter-package-integration** | "Add package X" | Pub.dev vetting, approval gates, helper wrapping workflow |
| **flutter-project-audit** | "Audit this project" | Structured violation report + per-feature migration plan |
| **flutter-feature-scaffold** | API → feature, JSON/cURL paste | Generates full DDP slice respecting project conventions |
| **flutter-testing** | "Write tests for X" | Unit/widget/BDD tests with `mocktail` + `ProviderContainer` |
| **flutter-code-hygiene** | "Find dead code", "unused assets" | Dead code, unused assets, widget duplication audit |
| **flutter-design-to-code** | Image / Figma → widget | Theme-aware Flutter widgets from designs |
| **flutter-sqa** | "Test the app", "QA checklist" | Integration test scaffolding + manual test plans |
| **flutter-release** | "Prepare release", "Play Store metadata" | Build, release notes, store metadata, ASO, pre-submission checklist |

Plus:
- **`templates/CLAUDE.md.template`** — project-agnostic CLAUDE.md starting point you customize per project
- **`setup-claude-skills.sh`** — one-command install into any Flutter project

---

## Install

### Option A: One-command install (recommended)

```bash
# Clone this repo
git clone https://github.com/imumermalik/flutter-claude-toolkit.git
cd flutter-claude-toolkit

# Run installer in your Flutter project root
cd /path/to/your/flutter-project
/path/to/flutter-claude-toolkit/setup-claude-skills.sh
```

The script will:
1. Verify you're in a Flutter project (`pubspec.yaml` exists)
2. Back up any existing `.claude/` or `CLAUDE.md` (with your confirmation)
3. Copy all skills into `.claude/skills/`
4. Create or update `CLAUDE.md` from the template
5. Update `.gitignore` with sensible defaults
6. Print next steps

### Option B: Manual copy

```bash
cp -r flutter-claude-toolkit/.claude /path/to/your/flutter-project/
cp flutter-claude-toolkit/templates/CLAUDE.md.template /path/to/your/flutter-project/CLAUDE.md
```

### Option C: Git submodule (auto-sync)

```bash
cd /path/to/your/flutter-project
git submodule add https://github.com/imumermalik/flutter-claude-toolkit.git .claude-toolkit
ln -s .claude-toolkit/.claude .claude
cp .claude-toolkit/templates/CLAUDE.md.template CLAUDE.md
```

Update later with: `git submodule update --remote .claude-toolkit`

---

## After install: customize `CLAUDE.md`

Open `CLAUDE.md` and replace `<<FILL IN>>` markers with project specifics:

- App name, domain, platforms
- Flutter / Dart versions
- Flavor names and IDs
- Feature list and folder conventions
- Cross-module dependencies (if any)

Takes 10-15 minutes per project. Skills generic across projects; CLAUDE.md captures what's unique.

---

## How it works

Claude Code auto-loads everything in `.claude/skills/`. Each skill has:

- A **`description`** (always loaded) — what triggers it
- A **body** (loaded only when triggered) — instructions, patterns, examples

This keeps the per-conversation token cost low. Average baseline: ~4-5 KB of context across all 11 skill descriptions, ~1-2 KB extra when a skill triggers.

CLAUDE.md provides project-specific context. Skills provide reusable patterns. Together they tell Claude:
- *What* to do (skills)
- *Where* to do it (CLAUDE.md)

---

## Design principles

1. **Lean over comprehensive.** Each skill body stays under 1,500 tokens. References docs and other skills instead of duplicating.
2. **CURRENT vs TARGET awareness.** Skills respect existing project state; don't impose textbook patterns on real codebases.
3. **Discovery before generation.** Every code-generation skill inspects sibling features before writing — matches actual project conventions.
4. **Approval gates honored.** Skills never modify gated directories (`android/`, `ios/`, `pubspec.yaml`, CI configs) without explicit user approval.
5. **Honest, not aspirational.** Skills push back when a request is unrealistic. No fake "I can test the whole app" promises.
6. **English-only skills.** Project-specific CLAUDE.md can use any language. Skills stay portable.

---

## Upgrading

When new toolkit versions release, in your Flutter project:

```bash
cd /path/to/flutter-claude-toolkit
git pull

cd /path/to/your/flutter-project
/path/to/flutter-claude-toolkit/setup-claude-skills.sh --upgrade
```

`--upgrade` mode preserves your project's customized CLAUDE.md.

---

## Versioning

Semver. See `CHANGELOG.md` for what changed between versions.

Current version: see `VERSION` file.

---

## Compatibility

- **Flutter:** Tested on 3.41.2+. Should work on any recent stable.
- **Claude Code:** v2.0+ (skills feature required)
- **Riverpod:** Both 2.x (with migration support) and 3.x patterns covered

---

## Contributing

Issues and PRs welcome. Each skill is a single `SKILL.md` file — easy to read, easy to edit.

When adding a skill:
- Description: ≤ 100 tokens
- Body: ≤ 1,500 tokens
- Reference long content via lazy-load (other files, web docs)
- Inspect existing skills for tone and structure

---

## License

MIT — see `LICENSE`.

---

## Acknowledgments

Built with [Claude](https://claude.ai) / [Claude Code](https://docs.claude.com/en/docs/claude-code). Skill design informed by months of real Flutter codebase work, audit findings on production apps, and the principle that a good CLAUDE.md beats clever prompting every time.
