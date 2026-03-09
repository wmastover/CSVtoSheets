# CSV to Sheets for macOS

Minimal open-source macOS utility: open a local CSV file and send it to a new Google Sheet.

## Why this exists

Manual CSV import into Google Sheets is repetitive. This app makes the common flow one action from Finder.

## Features

- Open `.csv` files from macOS
- Google OAuth sign-in (desktop app flow)
- Create a new Google Sheet
- Upload CSV rows
- Open resulting sheet URL in browser
- Local-first behavior (no vendor backend)

## Scope

Current target is intentionally narrow:

- CSV-only first (`.csv`)
- no trial/licensing/purchase restore
- no analytics by default
- no anti-abuse logic
- no backend

See [Docs/PRD.md](Docs/PRD.md) and [Docs/MILESTONES.md](Docs/MILESTONES.md) for roadmap and non-goals.

## Build

Implemented app stack:

- Swift
- SwiftUI (+ AppKit where needed)
- URLSession for Google APIs
- Keychain for credential storage

## Project structure

- `Sources/App/` - SwiftUI app shell, views, app state, settings
- `Sources/Features/Auth/` - OAuth flow and Keychain token store
- `Sources/Features/Import/` - file-open handling and import orchestration
- `Sources/Services/Google/` - Google Sheets API adapter
- `Sources/Services/Parsing/` - CSV parser
- `Sources/Models/` - shared app models and typed errors
- `Resources/` - local config templates (OAuth)

## Run

1. Install Xcode (or full macOS developer toolchain).
2. Clone this repo.
3. Configure OAuth (below).
4. Build:

```bash
swift build
```

5. Run:

```bash
swift run
```

## Google API setup

1. Create a Google Cloud project.
2. Enable the Google Sheets API.
3. Create OAuth credentials for a **Desktop app**.
4. Copy the template:

```bash
cp Resources/OAuthConfig.example.json Resources/OAuthConfig.json
```

5. Update `Resources/OAuthConfig.json` with your Desktop OAuth `clientID`.
6. Launch the app and click **Sign In**.

## Privacy and security

- CSV data is processed locally, then uploaded only to Google APIs for import.
- No proprietary backend services.
- OAuth tokens stored in macOS Keychain.
- No tracking/analytics by default.

## Roadmap

- v0.1: CSV open -> OAuth -> create new sheet -> upload -> open browser
- v0.2: drag-and-drop, delimiter auto-detect, better progress/errors
- v0.3: `.xlsx`, title/account selection

## MVP status (v0.1)

- Sign in/out with Google OAuth desktop flow
- Access/refresh token persistence in macOS Keychain
- Open `.csv` from app UI and from file-open events
- UTF-8 CSV parsing with quoted fields and embedded delimiters
- Create Google Sheet and append rows in batches
- Open resulting sheet URL in browser
- Basic settings: auto-open browser toggle, delimiter override
- Typed error mapping for auth/parsing/network/rate-limit/partial upload

## Contributing

Contributions are welcome once the scaffold lands. Please keep changes aligned with the minimalist scope:

- prefer clarity over abstraction
- keep dependencies small
- avoid adding non-MVP features without an issue/discussion

## License

Planned: MIT or Apache-2.0 (to be finalized before first release).
