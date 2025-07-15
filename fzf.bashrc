# === fzf.bashrc ===


# Fuzzy open file using vi
vf() {
  local dir="$PWD"
  local index_file=""
  while [[ "$dir" != "$HOME" && "$dir" != "/" ]]; do
    if [[ -f "$dir/.fzf-index-files" ]]; then
      index_file="$dir/.fzf-index-files"
      break
    fi
    dir=$(dirname "$dir")
  done

  # 若找不到，預設為 ~/.fzf-index-files
  [[ -z "$index_file" ]] && index_file="$HOME/.fzf-index-files"

  if [[ ! -f "$index_file" ]]; then
    echo "❌ No index file found."
    return 1
  fi

  local file
  file=$(cat "$index_file" | fzf)
  [[ -n "$file" ]] && vi "$file"
}


# Fuzzy cd into a directory
fcd() {
  local dir
  dir=$(find . -type d \( -name .git -o -name build -o -name tmp -o -name sstate-cache \) -prune -false -o -type d | fzf)
  [ -n "$dir" ] && cd "$dir"
}

# Fuzzy search text in files, then open in vi at that line
fsearch() {
  local match
  match=$(rg --no-heading --line-number --color=never "$1" 2>/dev/null | fzf)
  [ -z "$match" ] && return

  local file="${match%%:*}"              # part before first colon = filename
  local line_and_rest="${match#*:}"      # part after first colon
  local line="${line_and_rest%%:*}"      # extract line number only

  if [ -f "$file" ]; then
    vi "+${line}" "$file"
  else
    echo "File not found: $file"
  fi
}

# 開啟 Git 專案內的 tracked 檔案
gitf() {
  local file
  file=$(git ls-files | fzf)
  [ -n "$file" ] && vi "$file"
}

# 使用 tig 檢視 log
gitlog() {
  tig log
}

# 使用 tig blame 檢視某檔案（fzf 選擇）
gitblame() {
  local file
  file=$(git ls-files | fzf)
  [ -n "$file" ] && tig blame "$file"
}

# fuzzy 切換 Git 分支
gitswitch() {
  local branch
  branch=$(git branch --all | grep -v 'HEAD' | sed 's/remotes\///' | sort -u | fzf)
  [ -n "$branch" ] && git checkout "$branch"
}


vhelp() {
  cat <<'EOF'

🎯 FZF Command Reference (for Max)

  vupdate       → Refresh the file index (absolute paths, skips .git/build/etc)
  vf / vfind     → Fuzzy-pick a file from the index and open in vi
  vseek <term>   → Fuzzy-search text via ripgrep and jump to line in vi
  fcd            → Fuzzy cd into any subdirectory (ignores build/tmp/.git)
  gitf           → Fuzzy-pick a Git-tracked file and open in vi
  gitlog         → Browse commit history using tig
  gitblame       → Fuzzy-pick a file and view `tig blame`
  gitswitch      → Fuzzy-pick and switch Git branch

Tips:
  - Use Ctrl+C or ESC to cancel out of fzf
  - Use Ctrl+D / Ctrl+U to page down/up in fzf
  - Run `vupdate` again after switching projects to refresh file paths

EOF
}

# Convenient aliases
alias vfind='vf'
alias vcd='fcd'
alias vseek='fsearch'
alias vupdate='/home/max/bin/update_fzf_index.sh'

