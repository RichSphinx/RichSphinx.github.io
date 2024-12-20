#! /bin/env bash

# Search directory and encryption directory
SEARCH_DIR="htb/"
ENCRYPT_DIR="_site/htb"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if npm is installed
if ! command_exists npm; then
    echo "Error: npm is not installed. Please install npm to proceed."
    exit 1
fi

# Check if staticrypt is installed
if ! npm list -g staticrypt >/dev/null 2>&1 && ! npx staticrypt --version >/dev/null 2>&1; then
    echo "Error: staticrypt is not installed. Install it globally with 'npm install -g staticrypt' or use npx."
    exit 1
fi

# Search for Markdown files containing "frontKey:"
FILES=$(grep -rl "frontKey:" "$SEARCH_DIR" --include="*.md")

# Check if any files are found
if [ -z "$FILES" ]; then
    echo "No Markdown files containing 'frontKey:' found in $SEARCH_DIR"
    exit 0
fi

# Ensure the encryption directory exists
if [ ! -d "$ENCRYPT_DIR" ]; then
    echo "Error: Encryption directory $ENCRYPT_DIR does not exist."
    exit 1
fi

# Loop through each Markdown file and encrypt the corresponding HTML
for FILE in $FILES; do
    # Extract the password (value after "frontKey:")
    PASSWORD=$(grep "frontKey:" "$FILE" | sed -E 's/.*frontKey:[[:space:]]*//')

    if [ -z "$PASSWORD" ]; then
        echo "Warning: No password found in $FILE. Skipping."
        continue
    fi

    # Compute the relative path of the Markdown file and corresponding HTML file
    RELATIVE_PATH=$(realpath --relative-to="$SEARCH_DIR" "$FILE")
    HTML_FILE="${RELATIVE_PATH%.md}.html"
    TARGET_FILE="$ENCRYPT_DIR/$HTML_FILE"

    if [ ! -f "$TARGET_FILE" ]; then
        echo "Warning: Corresponding HTML file $TARGET_FILE not found. Skipping."
        continue
    fi

    # Encrypt the corresponding HTML file
    echo "Encrypting $TARGET_FILE with password: $PASSWORD"
    npx staticrypt "$TARGET_FILE" -p "$PASSWORD" -d "$ENCRYPT_DIR"/
done

echo "Encryption complete!"
