#!/bin/bash

# --- 🛠️ CONFIGURATION ---
TARGET_DIR=${1:-$PWD}
INDEX_NAME=".fzf-index-files"

# Folders to prune — edit as needed
PRUNE_DIRS=(
  .git
  build
  tmp
  out
  node_modules
  dist
  sstate-cache
)

# --- 🔍 Try to find an existing index file ---
SEARCH_DIR="$TARGET_DIR"
while [[ "$SEARCH_DIR" != "$HOME" && "$SEARCH_DIR" != "/" ]]; do
  if [[ -f "$SEARCH_DIR/$INDEX_NAME" ]]; then
    echo "[✔] Index already exists at: $SEARCH_DIR/$INDEX_NAME"
    exit 0
  fi
  SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

# --- 🛠️ Build new index in TARGET_DIR ---
OUTPUT_FILE="$TARGET_DIR/$INDEX_NAME"

echo "[Building new index at: $OUTPUT_FILE]"

cd "$TARGET_DIR" || { echo "❌ Cannot cd into $TARGET_DIR"; exit 1; }

# Build prune expression for `find`
PRUNE_EXPR=""
for dir in "${PRUNE_DIRS[@]}"; do
  PRUNE_EXPR+=" -name \"$dir\" -o"
done
PRUNE_EXPR="${PRUNE_EXPR::-2}" # remove trailing -o

# Final find command (quoted for safety)
FIND_CMD="find . -type d \\( $PRUNE_EXPR \\) -prune -false -o -type f"

# Run and write to index file
eval "$FIND_CMD" > "$OUTPUT_FILE"

echo "[✔] Indexed $(wc -l < "$OUTPUT_FILE") files → $OUTPUT_FILE"

