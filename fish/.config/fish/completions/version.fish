# Provide package name completions:
complete -f -c version -a "(pacman -Ssq)" -d "Repository packages"
