#!/bin/bash

# --- Input Validation ---
if [ -z "$1" ]; then
    echo "❌ Usage: $0 <cache-subdir-name> (e.g., rel17 or rel18)"
    exit 1
fi

CACHE_NAME="$1"
CACHE_BASE="$HOME/yocto-cache/$CACHE_NAME"
DL_DIR_LINE="DL_DIR ?= \"${CACHE_BASE}/downloads\""
SSTATE_DIR_LINE="SSTATE_DIR ?= \"${CACHE_BASE}/sstate\""

# --- CPU Core Calculation ---
# Get the total number of logical CPU cores
CPU_CORES=$(nproc)

# Calculate the optimal parallel job limit (half the cores, minimum 2)
# The '-j' in PARALLEL_MAKE needs to be slightly higher than BB_NUMBER_THREADS
BB_THREADS=$(( (CPU_CORES + 1) / 8 ))  # Round up division by 2
MAKE_JOBS=$(( (CPU_CORES + 1) / 2 ))        # Set PARALLEL_MAKE slightly higher

# Ensure a minimum value for stability, even on single-core systems
if [ "$BB_THREADS" -lt 2 ]; then
    BB_THREADS=2
    MAKE_JOBS=3
fi

BB_THREADS_LINE="BB_NUMBER_THREADS ?= \"$BB_THREADS\""
MAKE_JOBS_LINE="PARALLEL_MAKE ?= \"-j $MAKE_JOBS\""

echo "🧠 System has $CPU_CORES CPU cores. Setting parallelism to:"
echo "    BB_NUMBER_THREADS = $BB_THREADS"
echo "    PARALLEL_MAKE   = -j $MAKE_JOBS"

# --- Cache Directory Setup ---
mkdir -p "${CACHE_BASE}/downloads" "${CACHE_BASE}/sstate"
echo "📦 Ensured cache folders: $CACHE_BASE"

# --- Configuration File Search ---
LOCAL_CONFS=$(find build/* -maxdepth 2 -type f -path "*/conf/local.conf")

if [ -z "$LOCAL_CONFS" ]; then
    echo "❌ Error: No local.conf found under build/*/conf/"
    exit 1
fi

# --- Update local.conf Files ---
for LOCAL_CONF in $LOCAL_CONFS; do
    echo "---"
    echo "🔧 Updating $LOCAL_CONF"

    # Function to update or add a variable
    update_variable() {
        local VAR_LINE="$1"
        local VAR_NAME=$(echo "$VAR_LINE" | awk '{print $1}')

        # 1. Check if the variable exists (without comment or space)
        if grep -q "^[[:space:]]*${VAR_NAME}" "$LOCAL_CONF"; then
            # 2. If it exists, overwrite it (using sed for precision)
            sed -i "/^[[:space:]]*${VAR_NAME}/c\\${VAR_LINE}" "$LOCAL_CONF"
            echo "✅ Overwrote ${VAR_NAME} to use calculated value."
        else
            # 3. If it does not exist, append it
            echo "$VAR_LINE" >> "$LOCAL_CONF"
            echo "✅ Added ${VAR_NAME}"
        fi
    }

    # Apply Cache Settings
    update_variable "$DL_DIR_LINE"
    update_variable "$SSTATE_DIR_LINE"

    # Apply Parallelism Settings
    update_variable "$BB_THREADS_LINE"
    update_variable "$MAKE_JOBS_LINE"
done

echo "---"
echo "🎉 Configuration update complete."
