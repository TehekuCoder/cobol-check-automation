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

export SSHPASS="$SSH_PASSWORD"
SSH_OPTS="-p 22 -o StrictHostKeyChecking=no -o BatchMode=no"

echo "-> Connect with ${SSH_USERNAME}@${SSH_HOST}..."

# --- Fix line endings before upload ----------------------------
sed -i 's/\r//' $GITHUB_WORKSPACE/.github/scripts/remote_cobolcheck.sh

# --- Upload remote script --------------------------------------
sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  -o "SendEnv=LC_ALL" \
  $GITHUB_WORKSPACE/.github/scripts/remote_cobolcheck.sh \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/remote_cobolcheck.sh"

# --- Execute it on the mainframe -------------------------------
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" \
  "chmod +x ${REMOTE_DIR}/remote_cobolcheck.sh && zsh ${REMOTE_DIR}/remote_cobolcheck.sh ${LOWERCASE_USERNAME} ${SSH_USERNAME}"

echo "mainframe_operations.sh completed successfully."
