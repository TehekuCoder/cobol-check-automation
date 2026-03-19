#!/usr/bin/env bash
# -----------------------------------------------------------------
# mainframe_operations.sh
# Runs a COBOL check for the NUMBERS program via SSH on the
# IBM Z Xplore Server and copies the results to the
# MVS datasets.
# -----------------------------------------------------------------
set -euo pipefail

# --- Check required environment variables ----------------------
: "${SSH_HOST:?ERROR: SSH_HOST is not set}"
: "${SSH_USERNAME:?ERROR: SSH_USERNAME is not set}"
: "${SSH_PASSWORD:?ERROR: SSH_PASSWORD is not set}"

LOWERCASE_USERNAME=$(echo "$SSH_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"
PROGRAM="NUMBERS"

export SSHPASS="$SSH_PASSWORD"
SSH_OPTS="-p 22 -o StrictHostKeyChecking=no -o BatchMode=no"

echo "-> Connect with ${SSH_USERNAME}@${SSH_HOST}..."

# --- Execute all commands in an SSH session using heredoc ------
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" bash << REMOTE
set -euo pipefail

export JAVA_HOME=/usr/lpp/java/J8.0_64
export PATH="\${JAVA_HOME}/bin:\${PATH}"

echo "-> Java version:"
java -version 2>&1

cd "${REMOTE_DIR}"
echo "-> Working directory: \$(pwd)"

chmod +x cobolcheck
chmod +x scripts/linux_gnucobol_run_tests
echo "Permissions set."

echo ""
echo "-> Run cobolcheck for ${PROGRAM}..."
exit_code=0
./cobolcheck -p "${PROGRAM}" || exit_code=\$?

if [[ \$exit_code -ne 0 ]]; then
  echo "!!! cobolcheck ended with code \${exit_code}."
else
  echo "cobolcheck for ${PROGRAM} was successful."
fi

if [[ -f "CC##99.CBL" ]]; then
  cp "CC##99.CBL" "//'${SSH_USERNAME}.CBL(${PROGRAM})'" \
    && echo "CC##99.CBL -> ${SSH_USERNAME}.CBL(${PROGRAM})" \
    || { echo "Failed to copy CC##99.CBL."; exit 1; }
else
  echo "CC##99.CBL not found — check the cobolcheck output."
  exit 1
fi

if [[ -f "${PROGRAM}.JCL" ]]; then
  cp "${PROGRAM}.JCL" "//'${SSH_USERNAME}.JCL(${PROGRAM})'" \
    && echo "${PROGRAM}.JCL -> ${SSH_USERNAME}.JCL(${PROGRAM})" \
    || { echo "Failed to copy ${PROGRAM}.JCL."; exit 1; }
else
  echo "${PROGRAM}.JCL not found — JCL step skipped."
fi

echo ""
echo "All steps on the mainframe have been successfully completed."
REMOTE
