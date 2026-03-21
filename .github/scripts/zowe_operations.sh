#!/usr/bin/env bash
# ----------------------------------------------------------------
# zowe_operations.sh
# Uploads COBOL Check zip and source files for NUMBERS, EMPPAY
# and DEPTPAY to the IBM Z Xplore Server.
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
echo "-> Creating directories..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "
mkdir -p ${REMOTE_DIR}
mkdir -p ${REMOTE_DIR}/src/main/cobol
mkdir -p ${REMOTE_DIR}/src/test/cobol/NUMBERS
mkdir -p ${REMOTE_DIR}/src/test/cobol/EMPPAY
mkdir -p ${REMOTE_DIR}/src/test/cobol/DEPTPAY
mkdir -p ${REMOTE_DIR}/scripts
mkdir -p ${REMOTE_DIR}/testruns
"
echo "Directories ready."

# --- Upload ZIP directly to mainframe --------------------------
echo "-> Uploading cobol-check.zip..."
sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/cobol-check.zip \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/cobol-check.zip"

# --- Unzip on mainframe using jar ------------------------------
echo "-> Unzipping on mainframe..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" \
  "cd ${REMOTE_DIR} && /usr/lpp/java/J8.0_64/bin/jar xf cobol-check.zip && rm cobol-check.zip"

# --- Upload COBOL source files ---------------------------------
echo "-> Uploading source files..."
sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/src/main/cobol/NUMBERS.CBL \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/src/main/cobol/NUMBERS.CBL"

sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/src/main/cobol/EMPPAY.CBL \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/src/main/cobol/EMPPAY.CBL"

sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/src/main/cobol/DEPTPAY.CBL \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/src/main/cobol/DEPTPAY.CBL"

# --- Upload test suites ----------------------------------------
sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/src/test/cobol/NUMBERS/SymbolicRelationsTest.cut \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/src/test/cobol/NUMBERS/SymbolicRelationsTest.cut"

sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/src/test/cobol/EMPPAY/EMPPAY.cut \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/src/test/cobol/EMPPAY/EMPPAY.cut"

sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/src/test/cobol/DEPTPAY/DEPTPAY.cut \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/src/test/cobol/DEPTPAY/DEPTPAY.cut"

# --- Upload JCL files ------------------------------------------
sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/NUMBERS.JCL \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/NUMBERS.JCL"

sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/EMPPAY.JCL \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/EMPPAY.JCL"

sshpass -e scp -P 22 -o StrictHostKeyChecking=no \
  $GITHUB_WORKSPACE/DEPTPAY.JCL \
  "${SSH_USERNAME}@${SSH_HOST}:${REMOTE_DIR}/DEPTPAY.JCL"
echo "Source files uploaded."

# --- Convert uploaded files to EBCDIC --------------------------
echo "-> Converting files to EBCDIC..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "
for FILE in \
  ${REMOTE_DIR}/src/main/cobol/NUMBERS.CBL \
  ${REMOTE_DIR}/src/main/cobol/EMPPAY.CBL \
  ${REMOTE_DIR}/src/main/cobol/DEPTPAY.CBL \
  ${REMOTE_DIR}/src/test/cobol/NUMBERS/SymbolicRelationsTest.cut \
  ${REMOTE_DIR}/src/test/cobol/EMPPAY/EMPPAY.cut \
  ${REMOTE_DIR}/src/test/cobol/DEPTPAY/DEPTPAY.cut \
  ${REMOTE_DIR}/NUMBERS.JCL \
  ${REMOTE_DIR}/EMPPAY.JCL \
  ${REMOTE_DIR}/DEPTPAY.JCL; do
  iconv -f ISO8859-1 -t IBM-1047 \$FILE > \${FILE}.tmp && mv \${FILE}.tmp \$FILE
done
"
echo "Files converted to EBCDIC."

# --- Generate zos_run_tests script on mainframe ----------------
echo "-> Generating zos_run_tests script..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "
rm -f ${REMOTE_DIR}/scripts/zos_run_tests
echo '#!/bin/sh' > ${REMOTE_DIR}/scripts/zos_run_tests
echo 'PROGRAM=\$1' >> ${REMOTE_DIR}/scripts/zos_run_tests
echo 'export PATH=/usr/lpp/IBM/cobol/igyv6r4/bin:\$PATH' >> ${REMOTE_DIR}/scripts/zos_run_tests
echo 'cob2 -o \${PROGRAM%.CBL} \$PROGRAM' >> ${REMOTE_DIR}/scripts/zos_run_tests
echo './\${PROGRAM%.CBL}' >> ${REMOTE_DIR}/scripts/zos_run_tests
chmod +x ${REMOTE_DIR}/scripts/zos_run_tests
"
echo "zos_run_tests script generated."

# --- Configure config.properties -------------------------------
echo "-> Configuring config.properties..."
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" "
cd ${REMOTE_DIR}
iconv -f IBM-1047 -t ISO8859-1 config.properties | \
  sed 's|cobolcheck.test.program.path = ./testruns|cobolcheck.test.program.path = ./|' | \
  iconv -f ISO8859-1 -t IBM-1047 > config_new.properties && \
  mv config_new.properties config.properties
echo 'linux.process = zos_run_tests' | iconv -f ISO8859-1 -t IBM-1047 >> config.properties
"
echo "config.properties configured."

echo "zowe_operations.sh completed successfully."