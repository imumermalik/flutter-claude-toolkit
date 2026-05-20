# Changelog

All notable changes to the Flutter Claude Toolkit. Format: [Keep a Changelog](https://keepachangelog.com/). Versioning: [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-05-20

### Added

**Wave 1 — Foundation**
- `flutter-architecture` — DDP layer rules, SOLID, helper abstraction enforcement, anti-pattern table
- `flutter-riverpod` — `@riverpod` codegen patterns, ref method rules, 2.x → 3.x migration playbook
- `flutter-environments` — Flutter flavors, `--dart-define=FLAVOR=`, per-environment Firebase configs

**Wave 2 — Onboarding & Packages**
- `flutter-package-integration` — pub.dev vetting workflow, mandatory approval gate, helper-wrapping order
- `flutter-project-audit` — Two-phase audit (discovery + per-feature migration), violation detection, structured report template

**Wave 3 — Creation**
- `flutter-feature-scaffold` — API → DDP slice generator, pre-scaffold discovery, project-convention matching
- `flutter-testing` — `flutter_test` + `mocktail` patterns, BDD via `bdd_widget_test`, AAA template, coverage targets

**Wave 4 — Quality & Polish**
- `flutter-code-hygiene` — Dead code, unused asset, widget duplication audits (read-only by default, per-batch approval)
- `flutter-design-to-code` — Image/Figma → component-accurate, theme-aware widgets

**Wave 5 — End-of-cycle**
- `flutter-sqa` — Integration test scaffolding + manual test plan generator
- `flutter-release` — Build commands, release notes generation, store metadata (App Store + Play Store), ASO checklist, pre-submission checklist

**Templates & Tooling**
- `templates/CLAUDE.md.template` — project-agnostic CLAUDE.md starting point
- `setup-claude-skills.sh` — one-command install script with `--upgrade` and `--dry-run` modes
- `README.md` — toolkit documentation
- `CHANGELOG.md` — this file

### Design Principles

- Lean skills: each description ≤ 100 tokens, each body ≤ 1,500 tokens
- CURRENT vs TARGET awareness: skills respect existing project state, don't impose textbook patterns
- Discovery before generation: code-generation skills inspect sibling features before writing
- Approval gates honored across all skills
- English-only for portability; project CLAUDE.md may use any language

---

## [0.3.0] - 2026-05-20 (pre-release)

### Added
- Wave 3: `flutter-feature-scaffold`, `flutter-testing`

## [0.2.0] - 2026-05-20 (pre-release)

### Added
- Wave 2: `flutter-package-integration`, `flutter-project-audit`

## [0.1.0] - 2026-05-20 (pre-release)

### Added
- Initial repository structure
- Wave 1: `flutter-architecture`, `flutter-riverpod`, `flutter-environments`
- `templates/CLAUDE.md.template`
