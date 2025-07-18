#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 <filename> <line1|line1-line2> [more lines...]"
    exit 1
fi

FILE="$1"
shift
declare -A LINE_MAP

# Parse input arguments: ranges and individual lines
for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]+-[0-9]+$ ]]; then
        IFS='-' read -r start end <<< "$arg"
        for ((i=start; i<=end; i++)); do
            LINE_MAP[$i]=1
        done
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
        LINE_MAP[$arg]=1
    else
        echo "Invalid line spec: $arg"
        exit 1
    fi
done

# Build comma-separated line list
LINE_LIST=$(IFS=, ; echo "${!LINE_MAP[*]}")

awk -v lines="$LINE_LIST" '
BEGIN {
    n = split(lines, L, ",");
    for (i = 1; i <= n; i++) {
        target[L[i]] = 1;
    }
}
function repeat_tab(n,    out, i) {
    out = "";
    for (i = 0; i < n; i++) out = out "\t";
    return out;
}
{
    if (FNR in target) {
        # Step 1: Fix space-before-tab and trailing space
        gsub(/ *\t/, "\t");
        sub(/[ \t]+$/, "");

        # Step 2: Normalize leading indentation width
        match($0, /^[ \t]*/);
        indent = substr($0, 1, RLENGTH);
        rest = substr($0, RLENGTH + 1);

        width = 0;
        for (i = 1; i <= length(indent); i++) {
            c = substr(indent, i, 1);
            width += (c == "\t") ? (8 - (width % 8)) : 1;
        }

        tab_count = int(width / 8);
        print repeat_tab(tab_count) rest;
    } else {
        print;
    }
}
' "$FILE" > "$FILE.fixed" && mv "$FILE.fixed" "$FILE"

echo "[✔] Indentation normalized on lines: $LINE_LIST"

