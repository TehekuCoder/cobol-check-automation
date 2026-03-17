#!/bin/bash

# zowe_operations.sh
# Purpose: Upload local files to USS using Zowe CLI and environment variables

# Check if variables are available
if [ -z "$ZOWE_USERNAME" ]; then
    echo "Error: ZOWE_USERNAME environment variable is not set."
    exit 1
fi

# Convert username to lowercase for the USS path convention
LOWER_USER=$(echo "$ZOWE_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/$LOWER_USER/cobolcheck"
ZOWE_ARGS="--host $ZOWE_HOST --user $ZOWE_USERNAME --pass $ZOW_PASSWORD --port $ZOWE_PORT --reject-unauthorized false"

echo "Target directory on Mainframe: $REMOTE_DIR"

# 1. Ensure the directory exists
zowe zos-files create uss-directory "$REMOTE_DIR" $ZOWE_ARGS || echo "Directory might already exist."

# 2. Upload the COBOL-Check tool and source files
# We use a wildcard for JAR files to avoid version mismatch errors
zowe zos-files upload dir-to-uss "./cobol-check" "$REMOTE_DIR" \
  --recursive \
  --binary-files "*.jar" \
  $ZOWE_ARGS

# 3. CRITICAL: Upload the mainframe-side script itself
# This ensures the latest version of the logic is always available on the host
zowe zos-files upload file-to-uss ".github/scripts/mainframe_operations.sh" "$REMOTE_DIR/mainframe_operations.sh" $ZOWE_ARGS

echo "Upload process finished successfully."