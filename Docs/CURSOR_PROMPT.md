# Cursor Prompt for Initial App Scaffold

Copy/paste the prompt below into Cursor when ready to generate the initial app.

```text
Build a minimal open-source macOS app called "CSV to Sheets for macOS" using Swift + SwiftUI (AppKit where needed).

Hard constraints:
- No backend.
- No trial/licensing/purchase restore.
- No anti-abuse logic.
- No analytics by default.
- CSV-first; do not add `.xls` support.
- Keep dependencies minimal and architecture contributor-friendly.

Implement in this exact order:
1) SwiftUI macOS app shell
2) Settings window with sign-in state
3) Google OAuth desktop flow + Keychain token storage
4) `.csv` file open handling (Open With / Finder open event)
5) CSV parser (UTF-8, quoted fields, embedded delimiters)
6) Google Sheets API create spreadsheet + append values
7) Success/error UI states and basic progress reporting
8) README + setup docs

Create this repo structure:
- App/
- Features/Auth/
- Features/Import/
- Services/Google/
- Services/Parsing/
- Models/
- Resources/
- Docs/

Define and wire these modules:
- AppState
- AuthManager
- DocumentOpenHandler
- CSVParser
- SheetsService
- ImportCoordinator
- SettingsStore

Required behavior:
- User can sign in with Google.
- User can open a `.csv` file with the app.
- App creates a new Google Sheet.
- CSV rows appear in the first worksheet preserving row/column order.
- Created sheet opens in browser.
- Auth persists across relaunch.
- Common errors show useful messages (auth, malformed CSV, unsupported encoding, network, rate limit, partial upload).

Quality requirements:
- Do not block main UI during parsing/upload.
- Batch API writes for large files.
- Keep code readable with small, clear files.

Also add:
- Minimal README with build/run and Google OAuth setup section.
- Clear notes about privacy: local-first, no vendor server, data only sent to Google APIs.
```
