#!/usr/bin/env bash
# ----------------------------------------------------------------
# zowe_operations.sh
# Transfers the COBOL Check zip to the
# IBM Z Xplore Server via scp and unzips it there.
# ----------------------------------------------------------------
set -euo pipefail

# --- Check required environment variables ----------------------
: "${SSH_HOST:?ERROR: SSH_HOST is not set}"
: "${SSH_USERNAME:?ERROR: SSH_USERNAME is not set}"
: "${SSH_PASSWORD:?ERROR: SSH_PASSWORD is not set}"

LOWERCASE_USERNAME=$(echo "$SSH_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"

export SSHPASS="$SSH_PASSWORD"
SSH_OPTS="-p 22 -o StrictHostKeyChecking=no -o BatchMode=no"

echo "-> Destination: ${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}"

# --- Create directory on the mainframe -------------------------
echo "-> Check / create directory..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "mkdir -p ${REMOTE_DIR}"
echo "Directory ready."

# --- Upload ZIP directly to mainframe --------------------------
echo "-> Transfer cobol-check.zip via scp..."
sshpass -e scp -P 22 \
  -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/cobol-check.zip \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/cobol-check.zip"
echo "Upload complete."

# --- Unzip on mainframe ----------------------------------------
echo "-> Unzip on mainframe..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" \
  "cd ${REMOTE_DIR} && unzip -o cobol-check.zip && rm cobol-check.zip"
echo "Unzip complete."

# --- Verify result ---------------------------------------------
echo "-> Content of the remote directory:"
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "ls -al ${REMOTE_DIR}"

echo "zowe_operations.sh completed successfully."
