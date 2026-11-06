#!/bin/bash

# --- 🛠️ CONFIGURATION ---
FORCE_CURRENT=false
INDEX_NAME=".fzf-index-files"
PRUNE_DIRS=(.git build tmp out node_modules dist sstate-cache)

# --- 📥 Parse Arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)
      FORCE_CURRENT=true
      shift
      ;;
    *)
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

TARGET_DIR="${TARGET_DIR:-$PWD}"

# --- 🔍 Try to find an existing index file unless forced ---
if ! $FORCE_CURRENT; then
  SEARCH_DIR="$TARGET_DIR"
  while [[ "$SEARCH_DIR" != "$HOME" && "$SEARCH_DIR" != "/" ]]; do
    if [[ -f "$SEARCH_DIR/$INDEX_NAME" ]]; then
      echo "[✔] Index already exists at: $SEARCH_DIR/$INDEX_NAME"
      exit 0
    fi
    SEARCH_DIR=$(dirname "$SEARCH_DIR")
  done
fi

# --- 🛠️ Build new index in TARGET_DIR ---
OUTPUT_FILE="$TARGET_DIR/$INDEX_NAME"
echo "[Building new index at: $OUTPUT_FILE]"

cd "$TARGET_DIR" || { echo "❌ Cannot cd into $TARGET_DIR"; exit 1; }

# --- 🔍 Build prune expression ---
PRUNE_EXPR=""
for dir in "${PRUNE_DIRS[@]}"; do
  PRUNE_EXPR+=" -name \"$dir\" -o"
done
PRUNE_EXPR="${PRUNE_EXPR::-2}" # remove trailing -o

# --- 🔍 Final command ---
FIND_CMD="find . -type d \\( $PRUNE_EXPR \\) -prune -false -o -type f"
eval "$FIND_CMD" > "$OUTPUT_FILE"

echo "[✔] Indexed $(wc -l < "$OUTPUT_FILE") files → $OUTPUT_FILE"

