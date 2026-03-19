#!/usr/bin/env bash
# -----------------------------------------------------------------
# mainframe_operations.sh
# Runs a COBOL check for the NUMBERS program via SSH on the
# IBM Z Xplore Server and copies the results to the
# MVS datasets.
# -----------------------------------------------------------------
set -euo pipefail

# ---  Check required environment variables ----------------------
: "${ZOWE_HOST:?ERROR: ZOWE_HOST is not set}"
: "${ZOWE_PORT:?ERROR: ZOWE_PORT is not set}"
: "${ZOWE_USERNAME:?ERROR: ZOWE_USERNAME is not set}"
: "${ZOWE_PASSWORD:?ERROR: ZOWE_PASSWORD is not set}"

LOWERCASE_USERNAME=$(echo "$ZOWE_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"
PROGRAM="NUMBERS"

# sshpass reads the password from the $SSHPASS environment variable
export SSHPASS="$ZOWE_PASSWORD"
SSH_OPTS="-p ${ZOWE_PORT} -o StrictHostKeyChecking=no -o BatchMode=no"

echo "->  Connect with ${ZOWE_USERNAME}@${ZOWE_HOST} …"

# --- Execute all commands in an SSH session using heredoc ------
# Local variables are used without a backslash,
# while remote variables (\$) are evaluated on the server.
sshpass -e ssh $SSH_OPTS "${ZOWE_USERNAME}@${ZOWE_HOST}" bash << REMOTE
set -euo pipefail

# Add Java to the PATH on the Z Xplore Server
export JAVA_HOME=/usr/lpp/java/J8.0_64
export PATH="\${JAVA_HOME}/bin:\${PATH}"

echo "->  Java version:"
java -version 2>&1

# Navigate to the COBOL Check directory
cd "${REMOTE_DIR}"
echo "->  Working directory: \$(pwd)"

# Make scripts executable
chmod +x cobolcheck
chmod +x scripts/linux_gnucobol_run_tests
echo "Permissions set."

# --- execute COBOL Check ----------------------------------
echo ""
echo "-> Run cobolcheck for ${PROGRAM} …"
exit_code=0
./cobolcheck -p "${PROGRAM}" || exit_code=\$?

if [[ \$exit_code -ne 0 ]]; then
  echo "!!! cobolcheck ended with code \${exit_code}."
else
  echo "cobolcheck for ${PROGRAM} was successful."
fi

# --- Copy CC##99.CBL to the MVS dataset ---------------------
if [[ -f "CC##99.CBL" ]]; then
  cp "CC##99.CBL" "//'${ZOWE_USERNAME}.CBL(${PROGRAM})'" \
    && echo "CC##99.CBL → ${ZOWE_USERNAME}.CBL(${PROGRAM})" \
    || { echo "Failed to copy CC##99.CBL."; exit 1; }
else
  echo "CC##99.CBL not found — check the cobolcheck output."
  exit 1
fi

# --- Copy JCL file to MVS dataset ------------------------------
if [[ -f "${PROGRAM}.JCL" ]]; then
  cp "${PROGRAM}.JCL" "//'${ZOWE_USERNAME}.JCL(${PROGRAM})'" \
    && echo "✔  ${PROGRAM}.JCL → ${ZOWE_USERNAME}.JCL(${PROGRAM})" \
    || { echo "Failed to copy ${PROGRAM}.JCL."; exit 1; }
else
  echo "${PROGRAM}.JCL not found — JCL step skipped."
fi

echo ""
echo "All steps on the mainframe have been successfully completed."
REMOTE
