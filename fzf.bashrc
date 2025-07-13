# === fzf.bashrc ===


# Fuzzy open file using vi
vf() {
  local file
  file=$(cat "${HOME}/.fzf-index-files" 2>/dev/null | fzf)
  [ -n "$file" ] && vi "$file"
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

# Convenient aliases
alias vfind='vf'
alias vcd='fcd'
alias vseek='fsearch'
alias vupdate='/home/max/bin/update_fzf_index.sh'

