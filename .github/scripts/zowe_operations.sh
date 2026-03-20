#!/usr/bin/env bash
# ----------------------------------------------------------------
# zowe_operations.sh
# Uploads the COBOL Check zip and source files to the
# IBM Z Xplore Server and configures the environment.
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

# --- Create directories on the mainframe -----------------------
echo "-> Check / create directories..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "
mkdir -p ${REMOTE_DIR}
mkdir -p ${REMOTE_DIR}/src/main/cobol
mkdir -p ${REMOTE_DIR}/src/test/cobol/NUMBERS
mkdir -p ${REMOTE_DIR}/testruns
"
echo "Directories ready."

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

# --- Upload COBOL source files ---------------------------------
echo "-> Upload NUMBERS.CBL..."
sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/src/main/cobol/NUMBERS.CBL \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/src/main/cobol/NUMBERS.CBL"

echo "-> Upload NUMBERS.cut test suite..."
sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/src/test/cobol/NUMBERS/SymbolicRelationsTest.cut \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/src/test/cobol/NUMBERS/SymbolicRelationsTest.cut"

echo "-> Upload NUMBERS.JCL..."
sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/NUMBERS.JCL \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/NUMBERS.JCL"
echo "Source files uploaded."

# --- Convert NUMBERS.CBL from ASCII to EBCDIC ------------------
echo "-> Convert NUMBERS.CBL to EBCDIC..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" \
  "iconv -f ISO8859-1 -t IBM-1047 ${REMOTE_DIR}/src/main/cobol/NUMBERS.CBL > ${REMOTE_DIR}/src/main/cobol/NUMBERS_EBCDIC.CBL && mv ${REMOTE_DIR}/src/main/cobol/NUMBERS_EBCDIC.CBL ${REMOTE_DIR}/src/main/cobol/NUMBERS.CBL"
echo "NUMBERS.CBL converted to EBCDIC."

# --- Convert SymbolicRelationsTest.cut from ASCII to EBCDIC ----
echo "-> Convert SymbolicRelationsTest.cut to EBCDIC..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" \
  "iconv -f ISO8859-1 -t IBM-1047 ${REMOTE_DIR}/src/test/cobol/NUMBERS/SymbolicRelationsTest.cut > ${REMOTE_DIR}/src/test/cobol/NUMBERS/SymbolicRelationsTest_EBCDIC.cut && mv ${REMOTE_DIR}/src/test/cobol/NUMBERS/SymbolicRelationsTest_EBCDIC.cut ${REMOTE_DIR}/src/test/cobol/NUMBERS/SymbolicRelationsTest.cut"
echo "SymbolicRelationsTest.cut converted to EBCDIC."

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
cd ${REMOTE_DIR}
printf 'cobolcheck.test.run = false\n' | iconv -f ISO8859-1 -t IBM-1047 >> config.properties
"
echo "config.properties updated."

sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" \
  "iconv -f IBM-1047 -t ISO8859-1 ${REMOTE_DIR}/config.properties 2>/dev/null | head -20 || cat ${REMOTE_DIR}/config.properties | head -20"

# --- Convert config.properties to EBCDIC ----------------------
echo "-> Convert config.properties to EBCDIC..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" \
  "iconv -f ISO8859-1 -t IBM-1047 ${REMOTE_DIR}/config.properties > ${REMOTE_DIR}/config_ebcdic.properties && mv ${REMOTE_DIR}/config_ebcdic.properties ${REMOTE_DIR}/config.properties"
echo "config.properties converted to EBCDIC."

# --- Verify result ---------------------------------------------
echo "-> Content of the remote directory:"
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "ls -al ${REMOTE_DIR}"

echo "zowe_operations.sh completed successfully."
