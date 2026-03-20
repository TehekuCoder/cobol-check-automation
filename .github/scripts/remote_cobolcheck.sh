# remote_cobolcheck.sh
# Runs on the IBM Z Xplore mainframe via zsh

LOWERCASE_USERNAME=$1
USERNAME=$2
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"
PROGRAM="NUMBERS"

export JAVA_HOME=/usr/lpp/java/J8.0_64
export PATH="${JAVA_HOME}/bin:${PATH}"

cd "${REMOTE_DIR}"
echo "-> Working directory: $(pwd)"

sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" \
  "grep -i 'compiler\|cobol\|launcher' ${REMOTE_DIR}/config.properties"

chmod +x cobolcheck
chmod +x scripts/linux_gnucobol_run_tests
echo "Permissions set."

echo "-> Run cobolcheck for ${PROGRAM}..."
./cobolcheck -p "${PROGRAM}"

if [[ -f "CC##99.CBL" ]]; then
  cp "CC##99.CBL" "//'${USERNAME}.CBL(${PROGRAM})'"
  echo 'cp \"CC##99.CBL\" \"//\x27\${USERNAME}.CBL(\${PROGRAM})\x27\"' >> ${REMOTE_DIR}/remote_cobolcheck.sh
else
  echo "CC##99.CBL not found."
  exit 1
fi

if [[ -f "${PROGRAM}.JCL" ]]; then
  cp "${PROGRAM}.JCL" "//'${USERNAME}.JCL(${PROGRAM})'"
  echo "${PROGRAM}.JCL -> ${USERNAME}.JCL(${PROGRAM})"
else
  echo "${PROGRAM}.JCL not found — JCL step skipped."
fi

echo "remote_cobolcheck.sh completed successfully."
