#!/usr/bin/env bash
# -----------------------------------------------------------------
# mainframe_operations.sh
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
sshpass -e ssh $SSH_OPTS "${SSH_USERNAME}@${SSH_HOST}" << EOF
cat > ${REMOTE_DIR}/remote_cobolcheck.sh << 'SCRIPT'
LOWERCASE_USERNAME=\$1
USERNAME=\$2
REMOTE_DIR="/z/\${LOWERCASE_USERNAME}/cobolcheck"
PROGRAM="NUMBERS"
export JAVA_HOME=/usr/lpp/java/J8.0_64
export PATH="\${JAVA_HOME}/bin:\${PATH}"
cd "\${REMOTE_DIR}"
chmod +x cobolcheck
chmod +x scripts/linux_gnucobol_run_tests
./cobolcheck -p "\${PROGRAM}"
cp "CC##99.CBL" "//'\${USERNAME}.CBL(\${PROGRAM})'"
cp "\${PROGRAM}.JCL" "//'\${USERNAME}.JCL(\${PROGRAM})'"
SCRIPT
chmod +x ${REMOTE_DIR}/remote_cobolcheck.sh
zsh ${REMOTE_DIR}/remote_cobolcheck.sh ${LOWERCASE_USERNAME} ${SSH_USERNAME}
EOF

echo "mainframe_operations.sh completed successfully."
