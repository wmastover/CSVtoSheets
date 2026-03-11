# Google OAuth Setup

This app uses Google OAuth for installed desktop apps. You need to create your own OAuth client credentials — this takes about five minutes.

## Why you need this

Google requires every app to identify itself with a client ID before users can sign in. You create this credential in Google Cloud Console at no cost.

## Step-by-step

### 1. Create a Google Cloud project

1. Go to [console.cloud.google.com](https://console.cloud.google.com).
2. Click the project picker at the top → **New Project**.
3. Give it any name (e.g. `CSV to Sheets`). Click **Create**.
4. Make sure the new project is selected in the picker before continuing.

### 2. Enable the Google Sheets API

1. Go to **APIs & Services → Library**.
2. Search for **Google Sheets API**.
3. Click it, then click **Enable**.

### 3. Configure the OAuth consent screen

1. Go to **APIs & Services → OAuth consent screen**.
2. Choose **External** as the user type. Click **Create**.
3. Fill in the required fields:
   - **App name**: `CSV to Sheets` (or anything you like)
   - **User support email**: your Google account email
   - **Developer contact email**: your Google account email
4. Click **Save and Continue** through Scopes (no changes needed here).
5. On the **Test users** step, click **Add Users** and add your own Google account email. Click **Save and Continue**.
6. Review and click **Back to Dashboard**.

> The app stays in "Testing" mode, which is fine for personal use. Only test users you add can sign in.

### 4. Create OAuth credentials

1. Go to **APIs & Services → Credentials**.
2. Click **Create credentials → OAuth client ID**.
3. Set **Application type** to **Desktop app**.
4. Name it anything (e.g. `CSV to Sheets Desktop`). Click **Create**.
5. A dialog shows your **Client ID** and **Client Secret**.
6. Copy the **Client ID** — it looks like:
   ```
   123456789-abcdefghijklmnop.apps.googleusercontent.com
   ```
   You only need the Client ID, not the secret.

### 5. Add the Client ID to the app

```bash
cp Resources/OAuthConfig.example.json Resources/OAuthConfig.json
```

Open `Resources/OAuthConfig.json` and replace the placeholder with your real Client ID:

```json
{
  "clientID": "123456789-abcdefghijklmnop.apps.googleusercontent.com",
  "scopes": [
    "openid",
    "email",
    "https://www.googleapis.com/auth/spreadsheets"
  ]
}
```

### 6. Rebuild and reinstall

```bash
./make_app.sh
```

This bundles the updated config into the app and re-registers it with macOS.

---

## Common errors

| Error | Cause | Fix |
|---|---|---|
| `Error 401: invalid_client` | Placeholder client ID is still in the config | Follow step 5 above |
| `Access blocked: Authorization Error` | Consent screen not configured, or your account not added as a test user | Follow step 3 above |
| `OAuthConfig.json not found` | Config file missing or not bundled into app | Run `./make_app.sh` after placing the file |
| Sign-in times out | Local firewall or VPN blocking loopback on port 53682 | Temporarily disable VPN and retry |

---

## Privacy note

Your OAuth client ID is not a secret — it is included in the app bundle and sent to Google as part of the sign-in URL. Access tokens are stored only in your macOS Keychain and are never sent anywhere except Google APIs.
