#!/bin/sh
# -----------------------------------------------------------------
# mainframe_operations.sh
# Runs on the IBM Z Xplore mainframe via: ssh ... 'sh -s' < this_file
# Runs COBOL Check for NUMBERS and copies results to MVS datasets.
# -----------------------------------------------------------------

# --- Environment setup -----------------------------------------
export JAVA_HOME=/usr/lpp/java/J8.0_64
export PATH="${JAVA_HOME}/bin:${PATH}"

# --- Variables -------------------------------------------------
LOWERCASE_USERNAME=$(echo "$SSH_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"
PROGRAM="NUMBERS"

echo "-> Working directory: ${REMOTE_DIR}"
cd "${REMOTE_DIR}"

# --- Make scripts executable -----------------------------------
chmod +x scripts/zos_run_tests

# --- Run COBOL Check -------------------------------------------
echo "-> Running COBOL Check for ${PROGRAM}..."
java -jar ${REMOTE_DIR}/bin/cobol-check-0.2.19.jar -p "${PROGRAM}" || true
echo "-> COBOL Check completed."

# --- Copy CC##99.CBL to MVS dataset ----------------------------
if [ -f "testruns/CC##99.CBL" ]; then
  cp "testruns/CC##99.CBL" "//'${SSH_USERNAME}.CBL(${PROGRAM})'" && \
    echo "-> CC##99.CBL copied to ${SSH_USERNAME}.CBL(${PROGRAM})" || \
    echo "-> Failed to copy CC##99.CBL"
elif [ -f "CC##99.CBL" ]; then
  cp "CC##99.CBL" "//'${SSH_USERNAME}.CBL(${PROGRAM})'" && \
    echo "-> CC##99.CBL copied to ${SSH_USERNAME}.CBL(${PROGRAM})" || \
    echo "-> Failed to copy CC##99.CBL"
else
  echo "-> CC##99.CBL not found."
  exit 1
fi

# --- Submit JCL directly from USS ------------------------------
if [ -f "${PROGRAM}.JCL" ]; then
  submit "${PROGRAM}.JCL" && \
    echo "-> ${PROGRAM}.JCL submitted successfully" || \
    echo "-> Failed to submit ${PROGRAM}.JCL"
else
  echo "-> ${PROGRAM}.JCL not found — JCL step skipped."
fi

echo "mainframe_operations.sh completed successfully."
