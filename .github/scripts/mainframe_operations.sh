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
PROGRAM="NUMBERS"

export SSHPASS="$SSH_PASSWORD"
SSH_OPTS="-p 22 -o StrictHostKeyChecking=no -o BatchMode=no"

echo "-> Connecting to ${SSH_USERNAME}@${SSH_HOST}..."

# --- Generate remote script directly on mainframe --------------
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "
rm -f ${REMOTE_DIR}/remote_cobolcheck.sh
printf 'LOWERCASE_USERNAME=\$1\n' >> ${REMOTE_DIR}/remote_cobolcheck.sh
printf 'USERNAME=\$2\n' >> ${REMOTE_DIR}/remote_cobolcheck.sh
printf 'REMOTE_DIR=\"/z/\${LOWERCASE_USERNAME}/cobolcheck\"\n' >> ${REMOTE_DIR}/remote_cobolcheck.sh
printf 'PROGRAM=\"NUMBERS\"\n' >> ${REMOTE_DIR}/remote_cobolcheck.sh
printf 'export JAVA_HOME=/usr/lpp/java/J8.0_64\n' >> ${REMOTE_DIR}/remote_cobolcheck.sh
printf 'export PATH=\"\${JAVA_HOME}/bin:\${PATH}\"\n' >> ${REMOTE_DIR}/remote_cobolcheck.sh
printf 'cd \"\${REMOTE_DIR}\"\n' >> ${REMOTE_DIR}/remote_cobolcheck.sh
printf 'chmod +x scripts/zos_run_tests\n' >> ${REMOTE_DIR}/remote_cobolcheck.sh
printf 'java -jar \${REMOTE_DIR}/bin/cobol-check-0.2.19.jar -p \"\${PROGRAM}\"\n' >> ${REMOTE_DIR}/remote_cobolcheck.sh
printf 'cp \"testruns/CC##99.CBL\" \"//\x27\${USERNAME}.CBL(\${PROGRAM})\x27\"\n' >> ${REMOTE_DIR}/remote_cobolcheck.sh
printf 'cp \"\${PROGRAM}.JCL\" \"//\x27\${USERNAME}.JCL(\${PROGRAM})\x27\"\n' >> ${REMOTE_DIR}/remote_cobolcheck.sh
chmod +x ${REMOTE_DIR}/remote_cobolcheck.sh
"

# --- Check how COBOL Check reads os.name ---------------------
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "
cd /tmp
/usr/lpp/java/J8.0_64/bin/jar xf ${REMOTE_DIR}/bin/cobol-check-0.2.19.jar \
  org/openmainframeproject/cobolcheck/features/launcher/LauncherController.class
/usr/lpp/java/J8.0_64/bin/javap -c org/openmainframeproject/cobolcheck/features/launcher/LauncherController.class 2>&1 | head -50
"

# --- Execute it on the mainframe -------------------------------
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" \
  "zsh ${REMOTE_DIR}/remote_cobolcheck.sh ${LOWERCASE_USERNAME} ${SSH_USERNAME}"

echo "mainframe_operations.sh completed successfully."
