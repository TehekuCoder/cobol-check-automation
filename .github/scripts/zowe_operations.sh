#!/bin/bash
# zowe_operations.sh - Runs on GitHub Runner

# Lowercase for USS paths
LOWERCASE_USERNAME=$(echo "$ZOWE_USERNAME" | tr '[:upper:]' '[:lower:]')
REMOTE_DIR="/z/$LOWERCASE_USERNAME/cobolcheck"

# Zowe connection parameters (saves you from having to create a profile)
ZOWE_ARGS="--host $ZOWE_HOST --port $ZOWE_PORT --user $ZOWE_USERNAME --pass $ZOWE_PASSWORD --reject-unauthorized false"

echo "Check the directory on the mainframe..."
if ! zowe zos-files list uss-files "$REMOTE_DIR" $ZOWE_ARGS &>/dev/null; then
  echo "Create directory $REMOTE_DIR..."
  zowe zos-files create uss-directory "$REMOTE_DIR" $ZOWE_ARGS
fi

echo "Upload files..."
# The *.jar wildcard prevents errors during version updates!
zowe zos-files upload dir-to-uss "./cobol-check" "$REMOTE_DIR" \
  --recursive \
  --binary-files "*.jar" \
  $ZOWE_ARGS

echo "Upload successful."
