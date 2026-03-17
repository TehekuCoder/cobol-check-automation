#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# zowe_operations.sh
# Bereitet das USS-Verzeichnis auf dem Mainframe vor und
# lädt die COBOL Check Dateien hoch.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail   # Abbruch bei Fehler, nicht gesetzten Variablen oder Pipe-Fehlern

# ── Pflicht-Umgebungsvariablen prüfen ────────────────────────────
: "${ZOWE_USERNAME:?ERROR: ZOWE_USERNAME ist nicht gesetzt}"

LOWERCASE_USERNAME=$(echo "$ZOWE_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"

echo "▶  Ziel-Verzeichnis: ${REMOTE_DIR}"

# ── Remote-Verzeichnis anlegen falls nötig ───────────────────────
if zowe zos-files list uss-files "$REMOTE_DIR" &>/dev/null; then
  echo "✔  Verzeichnis existiert bereits."
else
  echo "✦  Verzeichnis nicht gefunden — lege ${REMOTE_DIR} an …"
  zowe zos-files create uss-directory "$REMOTE_DIR"
  echo "✔  Verzeichnis angelegt."
fi

# ── COBOL Check Dateien hochladen ─────────────────────────────────
echo "▶  Lade cobol-check/ auf den Mainframe hoch …"
zowe zos-files upload dir-to-uss "./cobol-check" "$REMOTE_DIR" \
  --recursive \
  --binary-files "cobol-check-*.jar"

# ── Upload prüfen ─────────────────────────────────────────────────
echo "▶  Upload-Ergebnis:"
zowe zos-files list uss-files "$REMOTE_DIR"

echo "✔  zowe_operations.sh erfolgreich abgeschlossen."
