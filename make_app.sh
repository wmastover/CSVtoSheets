#!/usr/bin/env bash
# Builds CSVtoSheets, packages it as a proper macOS .app bundle,
# installs it to /Applications, and registers it with Launch Services
# so Finder offers it as the default opener for .csv files.
#
# Usage:
#   ./make_app.sh            # debug build
#   ./make_app.sh --release  # release build (slower compile, faster app)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="CSVtoSheets"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_CONFIG="debug"
INSTALL_DIR="/Applications"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# Parse flags
for arg in "$@"; do
  case $arg in
    --release)
      BUILD_CONFIG="release"
      ;;
  esac
done

echo "==> Building ${APP_NAME} (${BUILD_CONFIG})..."
if [ "$BUILD_CONFIG" = "release" ]; then
  swift build -c release --package-path "$SCRIPT_DIR"
else
  swift build --package-path "$SCRIPT_DIR"
fi

BINARY_PATH="${SCRIPT_DIR}/.build/${BUILD_CONFIG}/${APP_NAME}"
if [ ! -f "$BINARY_PATH" ]; then
  echo "ERROR: Build succeeded but binary not found at ${BINARY_PATH}"
  exit 1
fi

# Assemble .app bundle in a temp directory, then move to /Applications
STAGING_DIR="$(mktemp -d)"
BUNDLE_PATH="${STAGING_DIR}/${BUNDLE_NAME}"

echo "==> Assembling bundle at ${BUNDLE_PATH}..."
mkdir -p "${BUNDLE_PATH}/Contents/MacOS"
mkdir -p "${BUNDLE_PATH}/Contents/Resources"

cp "$BINARY_PATH"                                      "${BUNDLE_PATH}/Contents/MacOS/${APP_NAME}"
cp "${SCRIPT_DIR}/Resources/Info.plist"                "${BUNDLE_PATH}/Contents/Info.plist"

# Copy OAuthConfig.json into the bundle Resources if it exists.
# If it doesn't exist yet the app will show an error on first launch,
# which is fine — see Docs/OAUTH_SETUP.md.
if [ -f "${SCRIPT_DIR}/Resources/OAuthConfig.json" ]; then
  cp "${SCRIPT_DIR}/Resources/OAuthConfig.json" "${BUNDLE_PATH}/Contents/Resources/OAuthConfig.json"
else
  echo "WARN: Resources/OAuthConfig.json not found — app will prompt to configure OAuth on first launch."
  echo "      See Docs/OAUTH_SETUP.md for setup instructions."
fi

DEST="${INSTALL_DIR}/${BUNDLE_NAME}"

echo "==> Installing to ${DEST} (may ask for your password)..."
if [ -d "$DEST" ]; then
  sudo rm -rf "$DEST"
fi
sudo cp -R "${BUNDLE_PATH}" "${INSTALL_DIR}/"

# Clean up staging dir
rm -rf "$STAGING_DIR"

echo "==> Registering with Launch Services..."
"$LSREGISTER" -f "${DEST}"
# Also unregister stale entries and re-scan /Applications to be safe
"$LSREGISTER" -kill -r -domain local -domain system -domain user 2>/dev/null || true
"$LSREGISTER" -f "${DEST}"

echo ""
echo "Done! CSV to Sheets is installed at ${DEST}."
echo ""
echo "To set it as the default CSV opener:"
echo "  1. Right-click any .csv file in Finder"
echo "  2. Get Info (Cmd+I)"
echo "  3. Under 'Open with', select 'CSV to Sheets'"
echo "  4. Click 'Change All...'"
echo ""
echo "After that, double-clicking any .csv in Finder will import it straight to Google Sheets."
