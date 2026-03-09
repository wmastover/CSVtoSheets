# CSV to Sheets for macOS - PRD (OSS Minimal)

## Name

Working name: `CSV to Sheets for macOS`

## Goal

A small open-source macOS app that lets a user open a local CSV file and send it directly into a newly created Google Sheet.

## Audience

- Primary: personal daily use
- Secondary: GitHub users who want the same workflow

## Problem

Opening CSV exports in Google Sheets manually is repetitive:

- download CSV
- go to Google Sheets
- create/import
- upload file
- wait
- open result

## Solution

Associate `.csv` files with a macOS app that:

1. reads the file locally
2. authenticates with Google
3. creates a new Google Sheet
4. uploads rows
5. opens the result in the browser

## Product Principles

- local-first
- minimal UI
- no backend
- no tracking by default
- easy to build and maintain
- easy for OSS contributors to understand

## Non-goals

- monetization
- trials/licensing/purchase restore
- proprietary user accounts
- anti-abuse logic
- cloud sync
- spreadsheet editing
- bidirectional file sync
- complex formatting preservation
- import into existing sheets
- `.xls` support (deferred)

## Scope

### v0.1 (MVP)

- macOS app
- open `.csv`
- sign in with Google
- create new Google Sheet
- upload rows
- open resulting sheet URL in browser

### v0.2

- drag-and-drop file onto app window
- delimiter auto-detect
- clearer error handling
- import progress UI

### v0.3

- `.xlsx` support
- choose spreadsheet title
- choose target Google account

### Explicitly not now

- `.xls`
- menu bar app mode
- import into existing sheets
- fancy formatting features
- team features

## Core User Flow

1. User installs app
2. User signs in with Google
3. User opens a `.csv` via Finder or drag-drop
4. App parses CSV locally
5. App creates a new Google Sheet
6. App writes rows to first worksheet
7. App opens created sheet in browser

## Functional Requirements

### 1) Authentication

- Google OAuth for installed desktop apps
- Secure token storage in macOS Keychain
- Sign in and sign out controls
- Token refresh when possible

### 2) File Handling

- Open `.csv`
- Drag-and-drop support
- "Open With" support
- Optional default CSV opener registration

### 3) CSV Import

- Parse UTF-8 CSV
- Quoted fields support
- Commas inside quoted fields support
- Preserve row and column order
- Spreadsheet title defaults from source filename
- Write rows into first worksheet
- Open created spreadsheet URL

### 4) Error Handling

- Empty file
- Malformed CSV
- Unsupported encoding
- Auth failure
- Network failure
- Google API rate limit
- Partial upload failure

### 5) Settings

- Connected Google account display
- Sign out
- Toggle browser auto-open
- Toggle default CSV opener
- Optional delimiter override

## Non-functional Requirements

### Performance

- Quick launch from Finder file-open events
- Import typical CSV files without UI freeze
- Visible progress for larger files

### Security & Privacy

- Tokens only in Keychain
- No vendor backend
- File contents only sent to Google APIs as required

### Maintainability

- Clear module boundaries
- Minimal dependencies
- Readable code for contributors

## MVP Acceptance Criteria

- User can sign in with Google
- User can open `.csv` with app
- App creates a new Google Sheet
- Rows appear correctly in Google Sheet
- Created sheet opens in browser
- Auth persists across relaunch
- Common errors show useful messages

## Nice-to-have Acceptance Criteria

- Drag-and-drop works
- Delimiter auto-detect works for comma/tab/semicolon
- Large import progress bar shown
- Retry after transient API failure
