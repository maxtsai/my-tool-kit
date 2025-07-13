#!/bin/bash

# --- 🛠️ CONFIGURATION ---
TARGET_DIR=${1:-$PWD}
OUTPUT_FILE=~/.fzf-index-files

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

echo "[Building fzf file index in: $TARGET_DIR]"

cd "$TARGET_DIR" || { echo "❌ Cannot cd into $TARGET_DIR"; exit 1; }

# Build prune expression correctly
PRUNE_EXPR=""
for dir in "${PRUNE_DIRS[@]}"; do
  PRUNE_EXPR+="-name \"$dir\" -o "
done
# Trim trailing -o
PRUNE_EXPR="${PRUNE_EXPR::-4}"

# Final find command
FIND_CMD="find $(pwd) -type d \\( $PRUNE_EXPR \\) -prune -false -o -type f"

# Debug print (optional)
# echo "[DEBUG] Command: $FIND_CMD"

# Run and output
eval "$FIND_CMD" > "$OUTPUT_FILE"

echo "[✔] Indexed $(wc -l < "$OUTPUT_FILE") files → $OUTPUT_FILE"

