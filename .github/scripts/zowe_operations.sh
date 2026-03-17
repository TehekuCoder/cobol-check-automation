#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# zowe_operations.sh
# Prepares the USS environment on the mainframe and uploads
# the COBOL Check tool files.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail   # exit on error, unset vars, or pipe failures

# ── Validate required environment variables ──────────────────────
: "${ZOWE_USERNAME:?ERROR: ZOWE_USERNAME is not set}"

LOWERCASE_USERNAME=$(echo "$ZOWE_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"

echo "▶  Target USS directory: ${REMOTE_DIR}"

# ── Ensure remote directory exists ───────────────────────────────
if zowe zos-files list uss-files "$REMOTE_DIR" &>/dev/null; then
  echo "✔  Directory already exists — skipping creation."
else
  echo "✦  Directory not found — creating ${REMOTE_DIR} …"
  zowe zos-files create uss-directory "$REMOTE_DIR"
  echo "✔  Directory created."
fi

# ── Upload COBOL Check files ──────────────────────────────────────
echo "▶  Uploading cobol-check/ to mainframe …"
zowe zos-files upload dir-to-uss "./cobol-check" "$REMOTE_DIR" \
  --recursive \
  --binary-files "cobol-check-*.jar"

# ── Verify upload ─────────────────────────────────────────────────
echo "▶  Verifying upload:"
zowe zos-files list uss-files "$REMOTE_DIR"

echo "✔  zowe_operations.sh completed successfully."
