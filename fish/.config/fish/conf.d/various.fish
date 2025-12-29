## User key bindings
function fish_user_key_bindings
    # Bind Ctrl+Delete to delete the next word
    bind \e\[3\;5~ 'commandline -f kill-word'
    bind \b 'commandline -f backward-kill-word'

end

function sail
    if test -f sail
        sh sail $argv
    else
        sh vendor/bin/sail $argv
    end
end

## Backup Function
function backup --argument filename
    cp $filename $filename.bak
end

## Copy Function
function copy
    set count (count $argv)
    if test "$count" = 2 and test -d "$argv[1]"
        set from (string trim --right '/' -- $argv[1])
        set to $argv[2]
        cp -r "$from" "$to"
    else
        cp $argv
    end
end

function sendText
    # Use the first argument as the filename; default to file.txt if not provided
    if test (count $argv) -gt 0
        set filename $argv[1]
    else
        set filename "file.txt"
    end

    # Get current epoch time (seconds) and compute expiry in ms (current time*1000 + 600000)
    set epoch (date +%s)
    set expiry (math "($epoch * 1000) + 600000")

    # Upload data from standard input, with secret=1 and expires set as calculated
    curl -F "file=@-;filename=$filename" -F "secret=1" -F "expires=$expiry" https://0x0.st
end
