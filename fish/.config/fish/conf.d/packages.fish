# packages.fish - Fish Shell Package Utilities
# Version: 2.3.0
# Author: Anas
#
# Usage:
#   native   [-c N] [-v]    # List native packages
#   aur      [-c N] [-v]    # List AUR packages
#   chaotic  [-c N] [-v]    # List Chaotic-AUR packages
#   version  <pkg> ...      # Compare versions

# -- Configuration --
set -g _pkg_c_name (set_color green)
set -g _pkg_c_ver (set_color blue)
set -g _pkg_c_warn (set_color yellow)
set -g _pkg_c_err (set_color red)
set -g _pkg_c_rst (set_color normal)

# -- Helper Functions --

function __pkg_require_cmd --description "Check for required dependencies"
    for cmd in $argv
        if not type -q $cmd
            echo "$_pkg_c_err""Error: '$cmd' is required but not found.$_pkg_c_rst" >&2
            return 1
        end
    end
end

function __pkg_format_output --description "Format and print package lists"
    argparse 'c/columns=' v/verbose -- $argv
    set -l pkgs $argv

    if test (count $pkgs) -eq 0
        echo "$_pkg_c_warn""No packages found.$_pkg_c_rst"
        return
    end

    # 1. Data Preparation (Colorizing)
    set -l display_list
    if set -q _flag_verbose
        # Bulk fetch versions for speed: Input names -> Output "name version"
        set display_list (printf "%s\n" $pkgs | expac -Q "$_pkg_c_name%n$_pkg_c_rst $_pkg_c_ver%v$_pkg_c_rst" -)
    else
        # Just colorize names
        set display_list (printf "$_pkg_c_name%s$_pkg_c_rst\n" $pkgs)
    end

    # 2. Grid Printing
    set -l cols $_flag_columns
    if test -z "$cols"
        set cols 0
    end

    if test $cols -lt 2
        # Simple Layouts (0=Single Line, 1=List)
        test $cols -eq 0; and echo (string join " " $display_list)
        test $cols -eq 1; and printf "%s\n" $display_list
    else
        # Multi-column Layout
        # Scan for max visible width (ignoring ANSI codes) to align correctly
        set -l max_len 0
        for p in $display_list
            set -l len (string length --visible -- $p)
            test $len -gt $max_len; and set max_len $len
        end
        set -l width (math $max_len + 2)

        # Print the grid
        set -l i 0
        for p in $display_list
            set -l padding (math "$width - "(string length --visible -- $p))
            printf "%s%s" $p (string repeat -n $padding " ")

            set i (math $i + 1)
            if test $i -ge $cols
                echo
                set i 0
            end
        end
        test $i -ne 0; and echo
    end

    # Summary
    echo "$_pkg_c_warn""Total explicitly installed packages: $_pkg_c_ver"(count $pkgs)"$_pkg_c_rst"
end

function __run_list_cmd --description "Generic handler for listing commands"
    argparse 'c/columns=' v/verbose -- $argv
    set -l mode $argv[1]

    # Generate package list (NAMES ONLY)
    # Using 'comm' allows fast set operations without loops
    set -l pkg_list
    switch $mode
        case native
            # Native = Explicit Native (-Qneq) MINUS Chaotic
            if type -q paclist
                set pkg_list (comm -23 (pacman -Qneq | sort | psub) (paclist chaotic-aur 2>/dev/null | awk '{print $1}' | sort | psub))
            else
                set pkg_list (pacman -Qneq | sort)
            end
        case aur
            # AUR = Foreign (-Qmq)
            set pkg_list (pacman -Qmq | sort)
        case chaotic
            __pkg_require_cmd paclist; or return 1
            # Chaotic = Explicit (-Qeq) INTERSECT Chaotic
            set pkg_list (comm -12 (pacman -Qeq | sort | psub) (paclist chaotic-aur 2>/dev/null | awk '{print $1}' | sort | psub))
    end

    # Pass flags to formatter
    set -l flags
    set -q _flag_columns; and set -a flags -c $_flag_columns
    set -q _flag_verbose; and set -a flags -v

    __pkg_format_output $flags $pkg_list
end

# -- Main Commands --

function native --description 'List native packages'
    __run_list_cmd native $argv
end

function aur --description 'List AUR packages'
    __run_list_cmd aur $argv
end

function chaotic --description 'List Chaotic-AUR packages'
    __run_list_cmd chaotic $argv
end

function version --description "Compare installed version vs repo version"
    if test (count $argv) -eq 0
        echo "Usage: version <pkg1> [pkg2 ...]" >&2
        return 1
    end
    __pkg_require_cmd expac vercmp; or return 1

    # 1. Bulk Fetch (The Speed Fix)
    # We fetch ALL versions in two single calls. 
    # Format: "pkgname|version". Separator '|' avoids space issues.
    # stderr silenced so warnings about missing pkgs don't leak.
    set -l inst_list (expac -Q '%n|%v' $argv 2>/dev/null)
    set -l repo_list (expac -S '%n|%v' $argv 2>/dev/null)

    for pkg in $argv
        echo "$_pkg_c_rst------------------"
        echo "$_pkg_c_name$pkg$_pkg_c_rst:"

        # 2. Parsing (The Correctness Fix)
        # We search the bulk list for the line starting with "pkgname|"
        # 'string match' returns captured group (version) at index 2
        set -l inst (string match -r "^$pkg\|(.*)" -- $inst_list)[2]
        set -l repo (string match -r "^$pkg\|(.*)" -- $repo_list)[2]

        # 3. Comparison Logic
        if test -z "$inst"
            if test -n "$repo"
                echo "$_pkg_c_err""Not installed$_pkg_c_rst (Available in repos: $_pkg_c_ver$repo$_pkg_c_rst)"
            else
                echo "$_pkg_c_err""Package not found$_pkg_c_rst (Not installed and not in repos)"
            end
        else
            if test -z "$repo"
                echo "$_pkg_c_warn""Installed: $_pkg_c_ver$inst$_pkg_c_rst (Local/AUR)"
            else
                set -l cmp (vercmp $inst $repo)
                switch $cmp
                    case 0
                        echo "$_pkg_c_warn""Installed: $_pkg_c_ver$inst$_pkg_c_rst = $_pkg_c_ver$repo$_pkg_c_rst (Up-to-date)"
                    case -1
                        echo "$_pkg_c_warn""Installed: $_pkg_c_err$inst$_pkg_c_rst < $_pkg_c_ver$repo$_pkg_c_rst (Update Available)"
                    case 1
                        echo "$_pkg_c_warn""Installed: $_pkg_c_ver$inst$_pkg_c_rst > $_pkg_c_err$repo$_pkg_c_rst (Newer than repo)"
                end
            end
        end
    end
end
