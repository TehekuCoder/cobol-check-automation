#!/usr/bin/env zsh

export JAVA_HOME=/usr/lpp/java/J8.0_64
export PATH="${JAVA_HOME}/bin:${PATH}"

LOWERCASE_USERNAME=$1
USERNAME=$2
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"
PROGRAM="NUMBERS"

cd "${REMOTE_DIR}"

chmod +x cobolcheck
chmod +x scripts/linux_gnucobol_run_tests

./cobolcheck -p "${PROGRAM}"

cp "CC##99.CBL" "//'${USERNAME}.CBL(${PROGRAM})'"
cp "${PROGRAM}.JCL" "//'${USERNAME}.JCL(${PROGRAM})'"

echo "remote_cobolcheck.sh completed successfully."
