# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Collaborative kanban board MVP — a Flutter mobile app backed by Firebase. Targets small teams (1-6 people) with small projects (<100 tasks). Real-time sync is a core requirement.

## Commands

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run

# Run all tests
flutter test

# Run a single test file
flutter test test/path_to_test.dart

# Analyze code (lint)
flutter analyze

# Build
flutter build apk        # Android
flutter build ios         # iOS
```

## Architecture

**Backend:** Firebase (Firestore + Firebase Auth). Chosen for native real-time sync and FlutterFire integration.

**State management:** Not yet selected — research docs comparing BLoC, Riverpod, and MVVM are in `../docs/research/`.

**Firestore structure:**
- `users/{uuid}` — email, name
- `boards/{uuid}` — name, ownerUuid, members list
  - `boards/{uuid}/tasks/{uuid}` — title, description, column (enum: todo/blocked/inProgress/inReview/done), position (fractional), assigneeUuid
  - `boards/{uuid}/boardMembers/{uuid}` — userUuid

**Linting:** Uses `flutter_lints` (configured in `analysis_options.yaml`).

## Domain Rules

- Fixed columns: Todo → Blocked → In Progress → In Review → Done (no column customization)
- Task positioning uses fractional indexing (single write per move)
- Last-write-wins for concurrent edits (no merge strategy)
- Board owner is sole admin (add/remove members, delete board); members can CRUD tasks
- Owner leaving = board deletion (no ownership transfer)
- Board deletion cascades: removes all tasks and members
- Account deletion: owned boards deleted, assigned tasks unassigned, removed from member lists
- No retry mechanics for failed API calls — local action is reverted on failure with user notification
- Members are added directly (no invitation flow); user search is exact match only

## Documentation

Design docs live in `../docs/`:
- `project_brief.md` — scope, entities, authorization model
- `design_document.md` — key flows and complexity trade-offs
- `architecture_decisions/` — backend, database, and frontend selection rationale
- `research/` — state management comparison studies
