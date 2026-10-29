# A TTY or SSH login skips Ly's setup.sh, the only place `.profile` is otherwise sourced.
if status is-login; and not set -q DOTFILES
    sh -c '. ~/.profile >/dev/null; env -0' | while read -lz entry
        set -l pair (string split -m1 = -- $entry)
        contains -- $pair[1] PWD SHLVL _; or set -gx $pair[1] $pair[2]
    end
end
