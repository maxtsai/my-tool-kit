#!/bin/bash

clear

FILE="$1"
PAGE_SIZE=20
OFFSET=0
SELECTED=0
LAST_COMMIT_HASH=""
CACHE_DIR="/tmp/git_diff_cache"
DIFF_SCROLL=0
CACHE_DIFF_LINES=()
SEARCH_STRING=""

mkdir -p "$CACHE_DIR"
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

get_terminal_height() {
    tput lines
}

cache_diff() {
    local hash="$1"
    local cache_file="$CACHE_DIR/$hash.diff"
    if [[ ! -f "$cache_file" ]]; then
        if [[ -n "$FILE" ]]; then
            git -c color.ui=always show "$hash" -- "$FILE" > "$cache_file"
        else
            git -c color.ui=always show "$hash" > "$cache_file"
        fi
    fi
    mapfile -t CACHE_DIFF_LINES < "$cache_file"
}

get_input() {
    IFS= read -rsn1 key 2>/dev/null
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.1 rest
        key+="$rest"
    fi
    echo "$key"
}

highlight_matches() {
    echo "$1"
}

prompt_search_string() {
    tput cup $(get_terminal_height) 0
    tput el
    echo -n "/"
    read -r SEARCH_STRING
    for i in "${!CACHE_DIFF_LINES[@]}"; do
        if [[ "${CACHE_DIFF_LINES[$i]}" == *"$SEARCH_STRING"* ]]; then
            DIFF_SCROLL=$i
            draw_diff_preview
            return
        fi
    done
    tput cup $(get_terminal_height) 0
    tput el
    echo "Not found: $SEARCH_STRING"
    sleep 1
}

draw_commit_list() {
    local mid=$(( $(get_terminal_height) / 2 ))
    if [[ -n "$FILE" ]]; then
	mapfile -t COMMITS < <(git log --pretty=format:'%h %<(16,trunc)%an %ad %<(80,trunc)%s' --date=short --skip=$OFFSET -n $PAGE_SIZE -- "$FILE")
    else
	mapfile -t COMMITS < <(git log --pretty=format:'%h %<(16,trunc)%an %ad %<(80,trunc)%s' --date=short --skip=$OFFSET -n $PAGE_SIZE)
    fi
    COUNT=${#COMMITS[@]}

    tput cup 0 0
    echo -e "\U1F4C4 Git History${FILE:+ of $FILE} [Branch: \033[1;33m$BRANCH_NAME\033[0m] — ↑ ↓ scroll | # to jump | Enter = view | n/p = page | j/k = scroll diff | / = search | c = clear | q = quit"
    echo

    for i in "${!COMMITS[@]}"; do
        if [[ "$i" -lt $((mid - 4)) ]]; then
            tput cup $((2 + i)) 0
            if [[ "$i" == "$SELECTED" ]]; then
                #echo -e "\033[1;33m👉 $((i + 1)). ${COMMITS[$i]}\033[0m"
		printf "\033[1;33m👉 %02d. %s\033[0m" $((i + 1)) "${COMMITS[$i]}"
            else
                #echo "   $((i + 1)). ${COMMITS[$i]}"
		printf "   %02d. %s" $((i + 1)) "${COMMITS[$i]}"
            fi
        fi
    done
}

draw_diff_preview() {
    local height=$(get_terminal_height)
    local mid=$((height / 2))

    [[ $SELECTED -ge $COUNT ]] && return
    commit_hash=$(echo "${COMMITS[$SELECTED]}" | awk '{print $1}')
    if [[ "$commit_hash" != "$LAST_COMMIT_HASH" ]]; then
        DIFF_SCROLL=0
        cache_diff "$commit_hash"
        LAST_COMMIT_HASH="$commit_hash"
    fi

    tput cup $((mid + 1)) 0
    printf "\033[J"
    local line_number=$((DIFF_SCROLL + 1))
    printf "\033[1;36m--- Code Diff Preview for %s (Lines %d+) ---\033[0m\n" "$commit_hash" "$line_number"

    local start_line=$DIFF_SCROLL
    local visible_lines=$((height - mid - 4))
    ((visible_lines < 5)) && visible_lines=5
    local end_line=$((DIFF_SCROLL + visible_lines))

    for ((i=start_line; i<end_line && i<${#CACHE_DIFF_LINES[@]}; i++)); do
        if [[ -n "$SEARCH_STRING" ]]; then
            highlight_matches "${CACHE_DIFF_LINES[$i]}" "$SEARCH_STRING"
        else
            echo -e "${CACHE_DIFF_LINES[$i]}"
        fi
    done
}

NUMBER_BUFFER=""
draw_commit_list
draw_diff_preview

while true; do
    key=$(get_input)
    case "$key" in
        g)  # Jump to top of diff
            DIFF_SCROLL=0
            draw_diff_preview
            ;;
        G)  # Jump to bottom of diff
	    half_height=$(( $(get_terminal_height) / 2 - 4 ))
	    ((half_height < 5)) && half_height=5
	    DIFF_SCROLL=$(( ${#CACHE_DIFF_LINES[@]} - half_height ))
	    ((DIFF_SCROLL < 0)) && DIFF_SCROLL=0

            draw_diff_preview
            ;;
        $'\x1b[A')  # UP
            NUMBER_BUFFER=""
            if [[ $SELECTED -gt 0 ]]; then
                ((SELECTED--))
            elif [[ $OFFSET -gt 0 ]]; then
                ((OFFSET--))
                SELECTED=0
            fi
            draw_commit_list
            draw_diff_preview
            ;;
        $'\x1b[B')  # DOWN
            NUMBER_BUFFER=""
            if [[ $SELECTED -lt $((COUNT - 1)) ]]; then
                ((SELECTED++))
            else
                ((OFFSET++))
                SELECTED=0
            fi
            draw_commit_list
            draw_diff_preview
            ;;
#        "")  # ENTER
#            NUMBER_BUFFER=""
#            [[ $SELECTED -lt $COUNT ]] && {
#                commit_hash=$(echo "${COMMITS[$SELECTED]}" | awk '{print $1}')
#                if [[ -n "$FILE" ]]; then
#                    git -c color.ui=always show "$commit_hash" -- "$FILE" | less -R
#                else
#                    git -c color.ui=always show "$commit_hash" | less -R
#                fi
#                draw_commit_list
#                draw_diff_preview
#            }
#            ;;
          "")
		if [[ "$NUMBER_BUFFER" =~ ^[0-9]+$ ]]; then
			JUMP=$((NUMBER_BUFFER - 1))
			if [[ "$JUMP" -ge 0 && "$JUMP" -lt $COUNT ]]; then
				SELECTED=$JUMP
				draw_commit_list
				draw_diff_preview
			fi
			else
				[[ $SELECTED -lt $COUNT ]] && {
				commit_hash=$(echo "${COMMITS[$SELECTED]}" | awk '{print $1}')
				if [[ -n "$FILE" ]]; then
					git -c color.ui=always show "$commit_hash" -- "$FILE" | less -R
				else
					git -c color.ui=always show "$commit_hash" | less -R
			fi
			draw_commit_list
			draw_diff_preview
			}
		fi
		NUMBER_BUFFER=""
		;;

        [nN])  # NEXT PAGE
            NUMBER_BUFFER=""
            ((OFFSET += PAGE_SIZE))
            SELECTED=0
            draw_commit_list
            draw_diff_preview
            ;;
        [pP])  # PREVIOUS PAGE
            NUMBER_BUFFER=""
            ((OFFSET -= PAGE_SIZE))
            [[ $OFFSET -lt 0 ]] && OFFSET=0
            SELECTED=0
            draw_commit_list
            draw_diff_preview
            ;;
        [jJ])  # SCROLL DIFF DOWN
            NUMBER_BUFFER=""
	    half_height=$(( $(get_terminal_height) / 2 - 4 ))
	    ((half_height < 5)) && half_height=5
	    max_scroll=$(( ${#CACHE_DIFF_LINES[@]} - half_height ))
	    ((max_scroll < 0)) && max_scroll=0

            if (( DIFF_SCROLL + 5 < max_scroll )); then
                ((DIFF_SCROLL += 5))
            else
                DIFF_SCROLL=$max_scroll
            fi
            draw_diff_preview
            ;;
        [kK])  # SCROLL DIFF UP
            NUMBER_BUFFER=""
            if (( DIFF_SCROLL - 5 > 0 )); then
                ((DIFF_SCROLL -= 5))
            else
                DIFF_SCROLL=0
            fi
            draw_diff_preview
            ;;
        /)  # SEARCH IN DIFF
            NUMBER_BUFFER=""
            prompt_search_string
            ;;
        [cC])  # CLEAR SCREEN
            tput clear
            draw_commit_list
            draw_diff_preview
            ;;
        q)
            tput cnorm
            tput clear
            exit 0
            ;;
        [0-9])
            NUMBER_BUFFER+="$key"
            ;;
        *)
            NUMBER_BUFFER=""
            ;;
    esac
done

