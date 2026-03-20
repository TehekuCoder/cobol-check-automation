#!/usr/bin/env bash
# ----------------------------------------------------------------
# zowe_operations.sh
# Uploads the COBOL Check zip and NUMBERS.JCL to the
# IBM Z Xplore Server, unpacks the zip, and configures
# the environment for z/OS.
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

# --- Generate zos_run_tests script on mainframe ----------------
echo "-> Generate zos_run_tests script..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "
rm -f ${REMOTE_DIR}/scripts/zos_run_tests
echo '#!/bin/sh' >> ${REMOTE_DIR}/scripts/zos_run_tests
echo 'PROGRAM=\$1' >> ${REMOTE_DIR}/scripts/zos_run_tests
echo 'export PATH=/usr/lpp/IBM/cobol/igyv6r4/bin:\$PATH' >> ${REMOTE_DIR}/scripts/zos_run_tests
echo 'cob2 -o \${PROGRAM%.CBL} \$PROGRAM' >> ${REMOTE_DIR}/scripts/zos_run_tests
echo './\${PROGRAM%.CBL}' >> ${REMOTE_DIR}/scripts/zos_run_tests
chmod +x ${REMOTE_DIR}/scripts/zos_run_tests
"
echo "zos_run_tests script generated."

# --- Configure config.properties -------------------------------
echo "-> Configure config.properties..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "
echo 'cobolcheck.test.run = false' >> ${REMOTE_DIR}/config.properties
echo 'zos.process = zos_run_tests' >> ${REMOTE_DIR}/config.properties
echo 'unix.process = zos_run_tests' >> ${REMOTE_DIR}/config.properties
"
echo "config.properties updated."

# --- Verify result ---------------------------------------------
echo "-> Content of the remote directory:"
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "ls -al ${REMOTE_DIR}"

echo "zowe_operations.sh completed successfully."
