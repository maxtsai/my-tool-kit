find . -name ".git" -type d -exec sh -c '
  for dir do
    repo_dir=$(dirname "$dir")
    remote=$(git -C "$repo_dir" remote get-url origin 2>/dev/null)
    if [ -n "$remote" ]; then
      echo "$repo_dir → $remote"
    fi
  done
' sh {} +

