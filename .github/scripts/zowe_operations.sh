#!/usr/bin/env bash
# ----------------------------------------------------------------
# zowe_operations.sh
# Transfers the COBOL check files to the
# IBM Z Xplore Server via scp and creates the working directory.
# ----------------------------------------------------------------
set -euo pipefail

# ---  Check required environment variables ----------------------
: "${ZOWE_HOST:?ERROR: ZOWE_HOST is not set}"
: "${ZOWE_PORT:?ERROR: ZOWE_PORT is not set}"
: "${ZOWE_USERNAME:?ERROR: ZOWE_USERNAME is not set}"
: "${ZOWE_PASSWORD:?ERROR: ZOWE_PASSWORD is not set}"

LOWERCASE_USERNAME=$(echo "$ZOWE_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"

# sshpass passes the password non-interactively
SSHPASS="sshpass -e"   # -e reads the password from $SSHPASS (set below)
export SSHPASS="$ZOWE_PASSWORD"

SSH_OPTS="-p ${ZOWE_PORT} -o StrictHostKeyChecking=no -o BatchMode=no"

echo "-> Destination: ${ZOWE_USERNAME}@${ZOWE_HOST}:${REMOTE_DIR}"

# --- Create a directory on the mainframe (if one does not already exist) --------
echo "->  Check / create directory …"
sshpass -e ssh $SSH_OPTS "${ZOWE_USERNAME}@${ZOWE_HOST}" "mkdir -p '${REMOTE_DIR}'"
echo "Directory ready."

# ---  Upload COBOL Check Files --------------------------------------------------
echo "->  Transfer cobol-check/ via SCP …"
sshpass -e scp -r -P "${ZOWE_PORT}" \
  -o StrictHostKeyChecking=no \
  ./cobol-check \
  "${ZOWE_USERNAME}@${ZOWE_HOST}:${REMOTE_DIR}/"
echo "Upload complete."

# --- Check Upload ----------------------------------------------------------------
echo "->  Content of the remote directory:"
sshpass -e ssh $SSH_OPTS "${ZOWE_USERNAME}@${ZOWE_HOST}" "ls -al '${REMOTE_DIR}'"

echo "zowe_operations.sh completed successfully."
