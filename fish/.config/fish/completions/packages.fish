complete -c packages -s r -l repo -x -a '(pacman-conf --repo-list 2>/dev/null; printf "%s\n" aur native)' -d "Filter by repo (comma-separated)"
complete -c packages -s v -l version -d "Show versions and status"
