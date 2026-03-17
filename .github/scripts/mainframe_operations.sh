#!/bin/bash

# mainframe_operations.sh
# Purpose: Execute COBOL-Check on USS and migrate artifacts to MVS datasets
# Usage: ./mainframe_operations.sh <USER_ID>

# Capture the first argument passed from the Zowe SSH command
USER_ID=$1

if [ -z "$USER_ID" ]; then
    echo "Error: No User ID provided. Usage: script.sh <USER_ID>"
    exit 1
fi

# --- Environment Setup ---
export JAVA_HOME=/usr/lpp/java/J8.0_64
export PATH=$PATH:$JAVA_HOME/bin
export PATH=$PATH:/usr/lpp/zowe/cli/node/bin

# Navigate to the work directory (absolute path for reliability)
WORKDIR="/z/$(echo $USER_ID | tr '[:upper:]' '[:lower:]')/cobolcheck"
cd "$WORKDIR" || { echo "Error: Path $WORKDIR not found"; exit 1; }

echo "Running in: $(pwd)"

# Ensure execution permissions for the tool and scripts
chmod +x cobolcheck
chmod +x scripts/linux_gnucobol_run_tests

# --- Execution Function ---
run_test_and_copy() {
    prog=$1
    echo "--------------------------------------------------"
    echo "Processing Program: $prog"

    # Run COBOL-Check
    ./cobolcheck -p "$prog"

    # Copy generated Test Driver (CC##99.CBL) to MVS Dataset
    if [ -f "CC##99.CBL" ]; then
        if cp "CC##99.CBL" "//'${USER_ID}.CBL($prog)'"; then
            echo "Successfully copied Driver to ${USER_ID}.CBL($prog)"
        else
            echo "Failed to copy Driver to MVS"
        fi
    fi

    # Copy JCL to MVS Dataset
    if [ -f "${prog}.JCL" ]; then
        if cp "${prog}.JCL" "//'${USER_ID}.JCL($prog)'"; then
            echo "Successfully copied JCL to ${USER_ID}.JCL($prog)"
        else
            echo "Failed to copy JCL to MVS"
        fi
    fi
}

# Run for all programs specified in the Lab
for program in NUMBERS EMPPAY DEPTPAY; do
    run_test_and_copy "$program"
done

echo "Mainframe operations completed."