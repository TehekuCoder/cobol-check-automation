#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# mainframe_operations.sh
# Runs COBOL Check for each program and submits the resulting
# JCL job on the mainframe via Zowe CLI.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Validate required environment variables ──────────────────────
: "${ZOWE_USERNAME:?ERROR: ZOWE_USERNAME is not set}"

LOWERCASE_USERNAME=$(echo "$ZOWE_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"

# List of programs to process (add/remove programs here)
PROGRAMS=(NUMBERS EMPPAY DEPTPAY)

OVERALL_EXIT=0   # track if any program failed

# ── Helper: set up Java & Zowe paths ─────────────────────────────
setup_environment() {
  export JAVA_HOME=/usr/lpp/java/J8.0_64
  export PATH="${JAVA_HOME}/bin:/usr/lpp/zowe/cli/node/bin:${PATH}"

  echo "▶  Java version:"
  java -version 2>&1
}

# ── Helper: run cobolcheck for one program ────────────────────────
run_cobolcheck() {
  local program="$1"
  echo ""
  echo "════════════════════════════════════════"
  echo "  Processing: ${program}"
  echo "════════════════════════════════════════"

  cd "${REMOTE_DIR}"

  # Make scripts executable (idempotent)
  chmod +x cobolcheck
  chmod +x scripts/linux_gnucobol_run_tests

  # Run COBOL Check (do not abort on non-zero — capture exit code)
  local cc_exit=0
  ./cobolcheck -p "$program" || cc_exit=$?

  if [[ $cc_exit -ne 0 ]]; then
    echo "⚠  cobolcheck for ${program} exited with code ${cc_exit}."
    OVERALL_EXIT=1
  else
    echo "✔  cobolcheck for ${program} passed."
  fi

  # ── Copy generated test source to MVS dataset ─────────────────
  local generated_cbl="CC##99.CBL"
  if [[ -f "$generated_cbl" ]]; then
    if cp "$generated_cbl" "//'${ZOWE_USERNAME}.CBL(${program})'"; then
      echo "✔  Copied ${generated_cbl} → ${ZOWE_USERNAME}.CBL(${program})"
    else
      echo "✘  Failed to copy ${generated_cbl} to MVS. Check dataset permissions."
      OVERALL_EXIT=1
    fi
  else
    echo "✘  ${generated_cbl} not found for ${program} — skipping copy."
    OVERALL_EXIT=1
  fi

  # ── Copy JCL file to MVS dataset ──────────────────────────────
  local jcl_file="${program}.JCL"
  if [[ -f "$jcl_file" ]]; then
    if cp "$jcl_file" "//'${ZOWE_USERNAME}.JCL(${program})'"; then
      echo "✔  Copied ${jcl_file} → ${ZOWE_USERNAME}.JCL(${program})"
    else
      echo "✘  Failed to copy ${jcl_file} to MVS."
      OVERALL_EXIT=1
    fi
  else
    echo "ℹ  ${jcl_file} not found — skipping JCL copy."
  fi
}

# ── Main ──────────────────────────────────────────────────────────
setup_environment

for program in "${PROGRAMS[@]}"; do
  run_cobolcheck "$program"
done

echo ""
if [[ $OVERALL_EXIT -eq 0 ]]; then
  echo "✔  All programs processed successfully."
else
  echo "✘  One or more programs had failures — see output above."
fi

exit $OVERALL_EXIT
