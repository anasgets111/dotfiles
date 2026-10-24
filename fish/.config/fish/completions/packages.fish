function __fish_packages_repos
    pacman-conf --repo-list 2>/dev/null
    printf "%s\n" aur native
end

complete -c packages -f
complete -c packages -s h -l help -d "Show help"
complete -c packages -s v -l version -d "Show versions and sync status"
complete -c packages -s r -l repo -x -a "(__fish_complete_list , __fish_packages_repos)" -d "Filter by repo"
complete -c packages -a "(__fish_complete_list , __fish_packages_repos)" -d Repository
