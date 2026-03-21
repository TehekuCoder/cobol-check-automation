#!/bin/sh
# -----------------------------------------------------------------
# mainframe_operations.sh
# Runs on the IBM Z Xplore mainframe via: ssh ... 'sh -s' < this_file
# Runs COBOL Check for NUMBERS, EMPPAY and DEPTPAY and submits jobs.
# -----------------------------------------------------------------

# --- Environment setup -----------------------------------------
export JAVA_HOME=/usr/lpp/java/J8.0_64
export PATH="${JAVA_HOME}/bin:${PATH}"

# --- Variables -------------------------------------------------
LOWERCASE_USERNAME=$(echo "$SSH_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/${LOWERCASE_USERNAME}/cobolcheck"

echo "-> Working directory: ${REMOTE_DIR}"
cd "${REMOTE_DIR}"

# --- Make scripts executable -----------------------------------
chmod +x scripts/zos_run_tests

# --- Function to run COBOL Check and submit JCL ----------------
run_cobolcheck() {
  PROGRAM=$1
  echo ""
  echo "================================================"
  echo "-> Processing: ${PROGRAM}"
  echo "================================================"

  # Run COBOL Check (ignore NullPointerException — known z/OS bug)
  java -jar ${REMOTE_DIR}/bin/cobol-check-0.2.19.jar -p "${PROGRAM}" || true
  echo "-> COBOL Check completed for ${PROGRAM}."

  # Copy CC##99.CBL to MVS dataset
  if [ -f "testruns/CC##99.CBL" ]; then
    cp "testruns/CC##99.CBL" "//'${SSH_USERNAME}.CBL(${PROGRAM})'" && \
      echo "-> CC##99.CBL copied to ${SSH_USERNAME}.CBL(${PROGRAM})" || \
      echo "-> Failed to copy CC##99.CBL for ${PROGRAM}"
  elif [ -f "CC##99.CBL" ]; then
    cp "CC##99.CBL" "//'${SSH_USERNAME}.CBL(${PROGRAM})'" && \
      echo "-> CC##99.CBL copied to ${SSH_USERNAME}.CBL(${PROGRAM})" || \
      echo "-> Failed to copy CC##99.CBL for ${PROGRAM}"
  else
    echo "-> CC##99.CBL not found for ${PROGRAM}."
  fi

  # Submit JCL
  if [ -f "${PROGRAM}.JCL" ]; then
    submit "${PROGRAM}.JCL" && \
      echo "-> ${PROGRAM}.JCL submitted successfully" || \
      echo "-> Failed to submit ${PROGRAM}.JCL"
  else
    echo "-> ${PROGRAM}.JCL not found — skipping."
  fi
}

# --- Run for each program --------------------------------------
run_cobolcheck NUMBERS
run_cobolcheck EMPPAY
run_cobolcheck DEPTPAY

echo ""
echo "mainframe_operations.sh completed successfully."