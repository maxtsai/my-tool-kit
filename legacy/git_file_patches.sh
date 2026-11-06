#!/bin/bash

OUTPUT_DIR="PATCH_$(date +%Y%m%d_%H%M%S)"
TEMP_HASH_FILE="/tmp/relevant_hashes_$$" 

FILE_PATH="$1"

echo "🔍 Identifying, sorting, and deduplicating commits for: $FILE_PATH"

git log --pretty=format:'%H' --reverse -- "$FILE_PATH" > "$TEMP_HASH_FILE"

if [ ! -s "$TEMP_HASH_FILE" ]; then
    echo "No commits found modifying '$FILE_PATH'. Aborting."
    rm -f "$TEMP_HASH_FILE"
    exit 0
fi

mkdir -p "$OUTPUT_DIR"

i=1

while read HASH || [ -n "$HASH" ]; do
    if [ -z "$HASH" ]; then
        continue
    fi

    echo "Processing patch $i for commit: $HASH"

    git format-patch -1 "$HASH" \
        --output-directory "$OUTPUT_DIR" \
        --start-number "$i" \
        --subject-prefix "PATCH"

    i=$((i+1))
done < "$TEMP_HASH_FILE"

