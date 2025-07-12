#!/bin/bash

# 使用方式提示
if [ -z "$1" ]; then
    echo "❌ Usage: $0 <cache-subdir-name>  (e.g., rel17 or rel18)"
    exit 1
fi

CACHE_NAME="$1"
CACHE_BASE="$HOME/yocto-cache/$CACHE_NAME"
DL_DIR_LINE="DL_DIR ?= \"${CACHE_BASE}/downloads\""
SSTATE_DIR_LINE="SSTATE_DIR ?= \"${CACHE_BASE}/sstate\""

# 建立 cache 目錄（若尚未存在）
mkdir -p "${CACHE_BASE}/downloads" "${CACHE_BASE}/sstate"
echo "📦 Ensured cache folders: $CACHE_BASE"

# 尋找所有 local.conf
#LOCAL_CONFS=$(find build -type f -path "build/*/conf/local.conf")
LOCAL_CONFS=$(find build/* -maxdepth 2 -type f -path "*/conf/local.conf")

if [ -z "$LOCAL_CONFS" ]; then
    echo "❌ Error: No local.conf found under build/*/conf/"
    exit 1
fi

# 對每個 local.conf 插入設定
for LOCAL_CONF in $LOCAL_CONFS; do
    echo "🔧 Updating $LOCAL_CONF"

    if ! grep -q '^DL_DIR' "$LOCAL_CONF"; then
        echo "$DL_DIR_LINE" >> "$LOCAL_CONF"
        echo "✅ Added DL_DIR"
    else
        echo "ℹ️  DL_DIR already exists"
    fi

    if ! grep -q '^SSTATE_DIR' "$LOCAL_CONF"; then
        echo "$SSTATE_DIR_LINE" >> "$LOCAL_CONF"
        echo "✅ Added SSTATE_DIR"
    else
        echo "ℹ️  SSTATE_DIR already exists"
    fi
done

