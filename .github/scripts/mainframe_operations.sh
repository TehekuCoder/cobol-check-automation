#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# mainframe_operations.sh
# Führt COBOL Check für das NUMBERS-Programm aus und kopiert
# die erzeugten Dateien in die MVS-Datasets.
# (Lab 1 — weitere Programme kommen in späteren Labs dazu)
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Pflicht-Umgebungsvariablen prüfen ────────────────────────────
: "${ZOWE_USERNAME:?ERROR: ZOWE_USERNAME ist nicht gesetzt}"

LOWERCASE_USERNAME=$(echo "$ZOWE_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"

# ── Java & Zowe im PATH verfügbar machen ─────────────────────────
export JAVA_HOME=/usr/lpp/java/J8.0_64
export PATH="${JAVA_HOME}/bin:/usr/lpp/zowe/cli/node/bin:${PATH}"

echo "▶  Java-Version:"
java -version 2>&1

# ── In das COBOL Check Verzeichnis wechseln ──────────────────────
cd "$REMOTE_DIR"
echo "▶  Arbeitsverzeichnis: $(pwd)"
ls -al

# ── Skripte ausführbar machen ─────────────────────────────────────
chmod +x cobolcheck
chmod +x scripts/linux_gnucobol_run_tests
echo "✔  Berechtigungen gesetzt."

# ── COBOL Check für NUMBERS ausführen ────────────────────────────
PROGRAM="NUMBERS"
echo ""
echo "▶  Führe cobolcheck für ${PROGRAM} aus …"

exit_code=0
./cobolcheck -p "$PROGRAM" || exit_code=$?

if [[ $exit_code -ne 0 ]]; then
  echo "⚠  cobolcheck für ${PROGRAM} endete mit Code ${exit_code}."
else
  echo "✔  cobolcheck für ${PROGRAM} erfolgreich."
fi

# ── Erzeugten Test-Source in MVS Dataset kopieren ────────────────
if [[ -f "CC##99.CBL" ]]; then
  if cp "CC##99.CBL" "//'${ZOWE_USERNAME}.CBL(${PROGRAM})'"; then
    echo "✔  CC##99.CBL → ${ZOWE_USERNAME}.CBL(${PROGRAM})"
  else
    echo "✘  Kopieren von CC##99.CBL fehlgeschlagen."
    exit 1
  fi
else
  echo "✘  CC##99.CBL wurde nicht erzeugt — prüfe die cobolcheck-Ausgabe."
  exit 1
fi

# ── JCL-Datei in MVS Dataset kopieren ───────────────────────────
if [[ -f "${PROGRAM}.JCL" ]]; then
  if cp "${PROGRAM}.JCL" "//'${ZOWE_USERNAME}.JCL(${PROGRAM})'"; then
    echo "✔  ${PROGRAM}.JCL → ${ZOWE_USERNAME}.JCL(${PROGRAM})"
  else
    echo "✘  Kopieren von ${PROGRAM}.JCL fehlgeschlagen."
    exit 1
  fi
else
  echo "ℹ  ${PROGRAM}.JCL nicht gefunden — JCL-Schritt übersprungen."
fi

echo ""
echo "✔  mainframe_operations.sh erfolgreich abgeschlossen."
