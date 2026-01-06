#!/bin/bash

# Define the source content
SOURCE_CODE="int main(void) { return 0; }"

# Determine the correct temp directory
# Windows bash usually uses $TEMP, Linux/macOS usually use $TMPDIR
TARGET_DIR="${TEMP:-${TMPDIR:-/tmp}}"
FILE_NAME="noop"

# Add .exe extension if we are on Windows
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    FILE_NAME="noop.exe"
fi

TARGET_PATH="$TARGET_DIR/$FILE_NAME"

echo "Creating source file..."
echo "$SOURCE_CODE" > noop.c

echo "Building with clang..."
if clang -O3 noop.c -o "$TARGET_PATH"; then
    echo "Success! Binary deployed to: $TARGET_PATH"
    
    # Clean up the source file
    rm noop.c
else
    echo "Error: Compilation failed."
    exit 1
fi

# Verify exit code
echo "Testing binary..."
"$TARGET_PATH"
if [ $? -eq 0 ]; then
    echo "Test passed: Binary exited with code 0."
else
    echo "Test failed: Binary returned non-zero exit code."
fi