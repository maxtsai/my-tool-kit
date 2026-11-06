#!/bin/bash
set -e

# Shared cache path (NFS mount). Override with:
# ./set_yocto_cache.sh /mnt/nfs/yocto-cache
CACHE_BASE="${1:-$HOME/yocto-cache}"
CPU_CORES=$(nproc)

# Yocto parallelism
BB_THREADS=$(( CPU_CORES / 4 ))
MAKE_JOBS=$(( CPU_CORES / 2 ))
(( BB_THREADS < 2 )) && BB_THREADS=2
(( MAKE_JOBS < 2 )) && MAKE_JOBS=2
(( BB_THREADS > 20 )) && BB_THREADS=20
(( MAKE_JOBS > 32 )) && MAKE_JOBS=32

mkdir -p "$CACHE_BASE/downloads" "$CACHE_BASE/sstate"

LOCAL_CONFS=$(find build/* -path "*/conf/local.conf" -maxdepth 2 -type f 2>/dev/null)
[ -z "$LOCAL_CONFS" ] && { echo "No build/*/conf/local.conf found"; exit 1; }

update_var() {
    local file="$1" name="$2" line="$3"
    local re="^[[:space:]]*(export[[:space:]]+)?${name}[[:space:]]*(\\?=|=)"

    if grep -Eq "$re" "$file"; then
        sed -Ei "\@${re}@c\\${line}" "$file"
    else
        echo "$line" >> "$file"
    fi
}

# --- Yocto common settings ---
for conf in $LOCAL_CONFS; do
    touch "$(dirname "$conf")/sanity.conf"

    update_var "$conf" DL_DIR \
        'DL_DIR ?= "'"$CACHE_BASE"'/downloads"'
    update_var "$conf" SSTATE_DIR \
        'SSTATE_DIR ?= "'"$CACHE_BASE"'/sstate"'
    update_var "$conf" BB_NUMBER_THREADS \
        'BB_NUMBER_THREADS ?= "'"$BB_THREADS"'"'
    update_var "$conf" PARALLEL_MAKE \
        'PARALLEL_MAKE ?= "-j '"$MAKE_JOBS"'"'

    echo "Updated Yocto settings: $conf"
done

# --- Platform-specific settings ---
for conf in $LOCAL_CONFS; do
    echo "Updated platform settings: $conf"
done

echo "Cache: $CACHE_BASE"
echo "BB_NUMBER_THREADS=$BB_THREADS, PARALLEL_MAKE=-j$MAKE_JOBS"
