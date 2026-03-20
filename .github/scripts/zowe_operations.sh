#!/usr/bin/env bash
# ----------------------------------------------------------------
# zowe_operations.sh
# Uploads the COBOL Check zip and NUMBERS.JCL to the
# IBM Z Xplore Server and unpacks the zip there.
# ----------------------------------------------------------------
set -euo pipefail

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
sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/cobol-check.zip \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/cobol-check.zip"
echo "Upload complete."

# --- Unzip on mainframe using jar ------------------------------
echo "-> Unzip on mainframe..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" \
  "cd ${REMOTE_DIR} && /usr/lpp/java/J8.0_64/bin/jar xf cobol-check.zip && rm cobol-check.zip"
echo "Unzip complete."

# --- Upload NUMBERS.JCL ----------------------------------------
echo "-> Upload NUMBERS.JCL..."
sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/NUMBERS.JCL \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/NUMBERS.JCL"
echo "NUMBERS.JCL uploaded."

# --- Verify result ---------------------------------------------
echo "-> Content of the remote directory:"
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "ls -al ${REMOTE_DIR}"

echo "zowe_operations.sh completed successfully."
