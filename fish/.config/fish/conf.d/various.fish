# WezTerm sends custom Ctrl/Shift+Backspace sequences.
bind ctrl-delete 'commandline -f kill-word'
bind \e\[7\;5~ 'commandline -f backward-kill-word'
bind shift-delete 'commandline -f kill-line'
bind \e\[7\;2~ 'commandline -f backward-kill-line'

function sail
    set -l executable "$PWD/sail"
    test -x "$executable"; or set executable vendor/bin/sail
    if not test -x "$executable"
        echo "sail: no executable found in ./ or vendor/bin/" >&2
        return 1
    end
    "$executable" $argv
end

function backup --argument filename
    cp -- "$filename" "$filename.bak"
end

function copy
    if test (count $argv) -eq 2; and test -d "$argv[1]"
        cp -r -- (string trim --right --chars=/ -- $argv[1]) "$argv[2]"
    else
        cp -- $argv
    end
end

function ssh --wraps=ssh
    if set -q KITTY_WINDOW_ID; and type -q kitty
        echo "Using Kitty SSH kitten" >&2
        command kitty +kitten ssh $argv
    else
        echo "Using standard SSH" >&2
        command ssh $argv
    end
end

function sendText
    set -l filename $argv[1] file.txt
    set -l expiry (date --date='10 minutes' +%s%3N)
    curl -F "file=@-;filename=$filename[1]" -F "secret=1" -F "expires=$expiry" https://0x0.st
end
