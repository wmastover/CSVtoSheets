# CSV to Sheets for macOS 🚀

Turn any local CSV into a live Google Sheet with one Finder action.

Double-click a `.csv` file -> authenticate with Google (once) -> sheet is created -> rows are uploaded -> browser opens the result. Easy win. ✅

## Why this exists 🤔

If you import CSVs often, the normal Sheets flow gets old fast. This app is a tiny macOS utility that makes importing feel basically one-click.

## What it does ✨

- Handles `.csv` directly from Finder (`Open With` / default app) 📂
- Uses Google OAuth desktop flow with token persistence in Keychain 🔐
- Creates a brand-new spreadsheet for each import 🆕
- Uploads rows in batches to keep large imports reliable 📈
- Opens the created Google Sheet automatically 🌐
- Runs local-first (no vendor backend) 🏡

## Scope 🎯

Current target is intentionally narrow:

- CSV-only first (`.csv`)
- no trial/licensing/purchase restore
- no analytics by default
- no anti-abuse logic
- no backend

See [Docs/PRD.md](Docs/PRD.md) and [Docs/MILESTONES.md](Docs/MILESTONES.md) for roadmap and non-goals.

## Build 🛠️

Implemented app stack:

- Swift
- SwiftUI (+ AppKit where needed)
- URLSession for Google APIs
- Keychain for credential storage

## Project structure 🧭

- `Sources/App/` - SwiftUI app shell, views, app state, settings
- `Sources/Features/Auth/` - OAuth flow and Keychain token store
- `Sources/Features/Import/` - file-open handling and import orchestration
- `Sources/Services/Google/` - Google Sheets API adapter
- `Sources/Services/Parsing/` - CSV parser
- `Sources/Models/` - shared app models and typed errors
- `Resources/` - local config templates (OAuth)

## Quick Start (recommended) ⚡

This path builds and installs a proper `.app` bundle in `/Applications` and registers it with macOS for Finder file-open flow.

1. Install Xcode (full, not just Command Line Tools).
2. Clone this repo.
3. Follow [Docs/OAUTH_SETUP.md](Docs/OAUTH_SETUP.md) to create a Google OAuth credential and populate `Resources/OAuthConfig.json`.
4. Run:

```bash
./make_app.sh
```

5. Right-click any `.csv` in Finder → **Get Info** → **Open with** → select **CSV to Sheets** → **Change All**.

From now on, double-clicking a CSV imports it straight to a new Google Sheet. 🎉

Use `./make_app.sh --release` for a faster production binary.

## Google OAuth setup 🔑

Full instructions with screenshots-equivalent step-by-step: [Docs/OAUTH_SETUP.md](Docs/OAUTH_SETUP.md).

Short version:
1. Create a Google Cloud project.
2. Enable the Google Sheets API.
3. Create an **OAuth client ID** with type **Desktop app**.
4. Copy the client ID into `Resources/OAuthConfig.json`.
5. Re-run `./make_app.sh`.

## Development (local run) 🧪

For quick iteration without installing:

```bash
cp Resources/OAuthConfig.example.json Resources/OAuthConfig.json
# edit OAuthConfig.json with your real clientID
swift build
swift run
```

`swift run` is for dev iteration only. It does not register Finder file associations. Use `./make_app.sh` for real app behavior.

## Privacy + Security 🛡️

- CSV data is parsed locally and sent only to Google APIs you authorize.
- No proprietary backend services.
- OAuth tokens stored in macOS Keychain.
- No tracking/analytics by default.

## Roadmap 🗺️

- v0.1: CSV open -> OAuth -> create new sheet -> upload -> open browser ✅
- v0.2: drag-and-drop, delimiter auto-detect, better progress/errors
- v0.3: `.xlsx`, title/account selection

## MVP status (v0.1) ✅

- Sign in/out with Google OAuth desktop flow
- Access/refresh token persistence in macOS Keychain
- Open `.csv` from app UI and from file-open events
- UTF-8 CSV parsing with quoted fields and embedded delimiters
- Create Google Sheet and append rows in batches
- Open resulting sheet URL in browser
- Basic settings: auto-open browser toggle, delimiter override
- Typed error mapping for auth/parsing/network/rate-limit/partial upload

## Contributing 🤝

Contributions are welcome once the scaffold lands. Please keep changes aligned with the minimalist scope:

- prefer clarity over abstraction
- keep dependencies small
- avoid adding non-MVP features without an issue/discussion

## License 📄

Planned: MIT or Apache-2.0 (to be finalized before first release).
