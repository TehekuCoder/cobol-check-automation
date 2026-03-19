#!/usr/bin/env bash
# ----------------------------------------------------------------
# zowe_operations.sh
# Transfers the COBOL check files to the
# IBM Z Xplore Server via scp and creates the working directory.
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
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "mkdir -p ${REMOTE_DIR} && echo 'mkdir OK' && ls -la /z/${LOWERCASE_USERNAME}/"
echo "Directory ready."

# --- Debug: Show what's in the current directory  -------------
echo "-> Current directory: $(pwd)"
ls -al
echo "-> cobol-check contents:"
ls -al ./cobol-check/ 2>/dev/null || echo "cobol-check/ not found!"

# --- Upload COBOL Check files ----------------------------------
echo "-> Transfer cobol-check/ via scp..."
sshpass -e scp -r -P 22 \
  -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/cobol-check \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/"
echo "Upload complete."

# --- Verify upload ---------------------------------------------
echo "-> Content of the remote directory:"
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "mkdir -p ${REMOTE_DIR}"

echo "zowe_operations.sh completed successfully."
