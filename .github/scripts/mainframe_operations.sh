#!/usr/bin/env bash
# -----------------------------------------------------------------
# mainframe_operations.sh
# Runs a COBOL check for the NUMBERS program via SSH on the
# IBM Z Xplore Server and copies the results to the MVS datasets.
# -----------------------------------------------------------------
set -euo pipefail

: "${SSH_HOST:?ERROR: SSH_HOST is not set}"
: "${SSH_USERNAME:?ERROR: SSH_USERNAME is not set}"
: "${SSH_PASSWORD:?ERROR: SSH_PASSWORD is not set}"

LOWERCASE_USERNAME=$(echo "$SSH_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"

export SSHPASS="$SSH_PASSWORD"
SSH_OPTS="-p 22 -o StrictHostKeyChecking=no -o BatchMode=no"

echo "-> Connect with ${SSH_USERNAME}@${SSH_HOST}..."

# --- Generate remote script directly on mainframe --------------
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "
rm -f ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'LOWERCASE_USERNAME=\$1' >> ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'USERNAME=\$2' >> ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'REMOTE_DIR=\"/z/\${LOWERCASE_USERNAME}/cobolcheck\"' >> ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'PROGRAM=\"NUMBERS\"' >> ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'export JAVA_HOME=/usr/lpp/java/J8.0_64' >> ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'export PATH=\"\${JAVA_HOME}/bin:\${PATH}\"' >> ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'cd \"\${REMOTE_DIR}\"' >> ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'chmod +x scripts/linux_gnucobol_run_tests' >> ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'chmod +x scripts/zos_run_tests' >> ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'java -jar \${REMOTE_DIR}/bin/cobol-check-0.2.19.jar -p \"\${PROGRAM}\"' >> ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'cp \"testruns/CC##99.CBL\" \"//\x27\${USERNAME}.CBL(\${PROGRAM})\x27\"' >> ${REMOTE_DIR}/remote_cobolcheck.sh
echo 'cp \"\${PROGRAM}.JCL\" \"//\x27\${USERNAME}.JCL(\${PROGRAM})\x27\"' >> ${REMOTE_DIR}/remote_cobolcheck.sh
chmod +x ${REMOTE_DIR}/remote_cobolcheck.sh
"

# --- Execute it on the mainframe -------------------------------
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" \
  "zsh ${REMOTE_DIR}/remote_cobolcheck.sh ${LOWERCASE_USERNAME} ${SSH_USERNAME}"

echo "mainframe_operations.sh completed successfully."
