#!/bin/bash

# mainframe_operations.sh
# Purpose: Run COBOL-Check on USS and copy generated artifacts to MVS

# --- 1. Set up Environment ---
export JAVA_HOME=/usr/lpp/java/J8.0_64
export PATH=$PATH:$JAVA_HOME/bin
export PATH=$PATH:/usr/lpp/zowe/cli/node/bin

# Verify Java version for the log
echo "Checking environment..."
java -version

# Set Mainframe User ID (Ensure NO space after '=')
ZOWE_USERNAME="Z88469"

# --- 2. Prepare Directory ---
# Navigate to the cobolcheck directory in USS
cd "$HOME/cobol-check" || { echo "Error: Could not find cobolcheck directory"; exit 1; }
echo "Current directory: $(pwd)"

# Ensure the cobolcheck launcher and scripts are executable
chmod +x cobolcheck
chmod +x scripts/linux_gnucobol_run_tests
echo "Permissions updated for cobolcheck and test scripts."

# --- 3. Test Execution Function ---
run_cobolcheck() {
    program=$1
    echo "--------------------------------------------------"
    echo "Starting COBOL-Check for: $program"

    # Run COBOL-Check
    # -p specifies the program name to be tested
    ./cobolcheck -p "$program"
    echo "COBOL-Check execution finished for $program."

    # --- 4. Artifact Migration (USS to MVS) ---
    
    # Check if the Test Driver (CC##99.CBL) was generated
    if [ -f "CC##99.CBL" ]; then
        echo "Test driver CC##99.CBL found. Copying to PDS..."
        # Copying from USS to MVS PDS Member
        if cp "CC##99.CBL" "//'${ZOWE_USERNAME}.CBL($program)'"; then
            echo "Success: Copied CC##99.CBL to ${ZOWE_USERNAME}.CBL($program)"
        else
            echo "Error: Failed to copy CC##99.CBL to MVS"
        fi
    else
        echo "Warning: CC##99.CBL not found for $program. Check test suite (.cut file)."
    fi

    # Check and copy the JCL file
    if [ -f "${program}.JCL" ]; then
        echo "JCL file found. Copying to PDS..."
        if cp "${program}.JCL" "//'${ZOWE_USERNAME}.JCL($program)'"; then
            echo "Success: Copied ${program}.JCL to ${ZOWE_USERNAME}.JCL($program)"
        else
            echo "Error: Failed to copy ${program}.JCL to MVS"
        fi
    else
        echo "Note: ${program}.JCL not found in USS."
    fi
}

# --- 5. Main Execution Loop ---
# Iterating through the programs defined in Lab 2 & 3
for program in NUMBERS EMPPAY DEPTPAY; do
    run_cobolcheck "$program"
done

echo "--------------------------------------------------"
echo "Mainframe operations completed successfully."
