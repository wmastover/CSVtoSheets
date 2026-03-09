# Milestones

## Scope guardrails (apply to all milestones)

- No trial, licensing, or purchase restore.
- No backend services.
- No anti-abuse logic.
- No analytics by default.
- Keep contributor-friendly architecture and minimal dependencies.

## v0.1 - CSV MVP

### In scope

- macOS app shell (SwiftUI)
- Google OAuth desktop sign-in
- Open `.csv` from Finder/Open With
- Parse CSV reliably (UTF-8, quotes, embedded delimiters)
- Create new Google Sheet and upload rows
- Open resulting sheet URL in browser
- Basic settings: sign-out, auto-open toggle
- Useful error messages for common failure modes

### Out of scope

- drag-and-drop
- delimiter auto-detect
- `.xlsx` / `.xls`
- import into existing sheets
- advanced formatting

## v0.2 - UX Reliability Pass

### In scope

- drag-and-drop import
- delimiter auto-detection (comma, tab, semicolon)
- import progress UI for larger files
- clearer transient error handling + retry affordance

### Out of scope

- `.xlsx` / `.xls`
- multiple account picker
- existing sheet target selection

## v0.3 - Extended Input

### In scope

- `.xlsx` support
- optional custom spreadsheet title
- explicit target account selection in UI

### Out of scope

- `.xls` support
- menu bar mode
- team/admin features

## Deferred (do not build yet)

- `.xls` support
- menu bar app mode
- import into existing sheets
- fancy formatting features
- team collaboration features
