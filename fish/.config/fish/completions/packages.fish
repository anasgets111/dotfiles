# Completions for packages

function __packages_repos
    set -l repos (pacman-conf --repo-list 2>/dev/null)
    printf '%s\n' $repos aur native
end

complete -c packages -s r -l repo -x -a "(__packages_repos)" -d "Filter by repo (comma-separated)"
complete -c packages -s v -l version -d "Show versions and status"
