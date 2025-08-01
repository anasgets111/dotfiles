# packages.fish - Fish Shell Package Utilities
# Title: packages.fish
# Version: 1.0.0
# Author: Anas
#
# Description:
#   A collection of fish shell functions to list and compare installed packages,
#   including native packages, AUR packages, and Chaotic-AUR packages.
#
# Usage:
#   native   [-c N] [-v]    # List native packages
#   aur      [-c N] [-v]    # List AUR packages
#   chaotic  [-c N] [-v]    # List Chaotic-AUR packages
#   version  <pkg1> [pkg2 …] # Compare installed vs repo versions
#
# Examples:
#   native -c 3          # Display native packages in 3 columns without versions
#   aur -v               # Display AUR packages with versions, one per line
#   chaotic -c 2 -v      # Display Chaotic-AUR packages in 2 columns with versions
#   version git vim      # Compare versions of 'git' and 'vim'

# __pad -- Pad string to specified width accounting for ANSI escape sequences
# Arguments:
#   str   : The input string (may include ANSI color codes)
#   width : The total width to pad the string to
# Output:
#   Prints the padded string, ensuring correct alignment in tables.
# Example:
#   __pad "test" 10
function __pad --description "Pad string to specified width accounting for ANSI escape sequences" --argument-names str width
    set len (string length -- (string replace -ra '\\e\[[0-9;]*m' '' -- $str))
    set pad (math $width - $len)
    if test $pad -lt 0
        set pad 0
    end
    printf "%s%s" $str (string repeat -n $pad ' ')
end

# __print_multi_columns -- Helper to print packages in multiple columns
# Arguments:
#   cols : Number of columns for layout
#   pkgs : Array of package strings to display
# Output:
#   Arranges and prints the package list into the specified number of columns.
# Example:
#   __print_multi_columns 3 pkg1 pkg2 pkg3 pkg4 pkg5 pkg6
function __print_multi_columns --description "Helper to print packages in multiple columns" --argument-names cols pkgs
    set -l cols $argv[1]
    set -l pkgs $argv[2..]
    set -l max 0
    for p in $pkgs
        set clen (string length -- (string replace -ra '\\e\[[0-9;]*m' '' -- $p))
        if test $clen -gt $max
            set max $clen
        end
    end
    set width (math $max + 2)
    set i 1
    for p in $pkgs
        __pad $p $width
        if test $i -ge $cols
            echo
            set i 1
        else
            set i (math $i + 1)
        end
    end
    if test $i -ne 1
        echo
    end
end

# __print_packages -- Display package list in specified column layout
# Arguments:
#   cols : Column layout mode (0 = single line, 1 = one per line, >1 = multi columns)
#   pkgs : Array of package strings (with optional version info)
# Output:
#   Formats and prints the package list according to the column setting.
# Example:
#   __print_packages 2 pkg1 pkg2 pkg3 pkg4
function __print_packages --description "Display package list in specified column layout" --argument-names cols pkgs
    set -l cols $argv[1]
    set -e argv[1]
    set -l pkgs $argv

    switch $cols
        case 0
            printf "%s " $pkgs
            echo
        case 1
            printf "%s\n" $pkgs
        case '*'
            if test $cols -gt 1
                __print_multi_columns $cols $pkgs
            else
                printf "Invalid column count: %s\n" $cols >&2
                return 1
            end
    end
end

# __get_packages_generic -- Fetch and format package lists from a command output
# Arguments:
#   showver : Flag (0 = hide versions, 1 = show versions)
#   color   : ANSI color code for package names
#   cmd     : Command and arguments to list packages (e.g., pacman -Qm)
# Output:
#   Reads each line of command output, extracts name and version, applies coloring,
#   and prints the formatted list.
function __get_packages_generic --description \
  "Fetch and format package lists from a command output" \
  --argument-names showver color cmd

    # pull args apart
    set -l showver  $argv[1]
    set -l color    $argv[2]
    set -l cmd      $argv[3]
    set -l cmd_args $argv[4..-1]

    set -l output

    # iterate lines in the same process (no subshell)
    for line in ($cmd $cmd_args 2>/dev/null)
        if test -z "$line"
            continue
        end

        # split into name + version
        set -l parts (string split ' ' -- $line)
        if test (count $parts) -lt 2
            continue
        end
        set -l name $parts[1]
        set -l ver  $parts[2]

        if test $showver -eq 1
            set -a output \
                (printf "%s%s%s %s%s%s" \
                    $color $name $RESET $BLUE $ver $RESET)
        else
            set -a output (printf "%s%s%s" $color $name $RESET)
        end
    end

    # only print if we actually got something
    if test (count $output) -gt 0
        printf "%s\n" $output
    end
end

# __get_aur -- List AUR packages installed on the system
# Arguments:
#   showver : Flag to show versions (0/1)
# Output:
#   Prints installed AUR packages in green; hides or shows version based on flag.
# Example:
#   aur -v
function __get_aur --description "List AUR packages installed on the system" --argument-names showver
    set showver $argv[1]
    __get_packages_generic $showver $GREEN pacman -Qm
end

# __get_chaotic -- List Chaotic-AUR packages installed on the system
# Arguments:
#   showver : Flag to show versions (0/1)
# Output:
#   Requires paclist; prints Chaotic-AUR packages in green.
# Example:
#   chaotic -v
function __get_chaotic --description "List *explicitly* installed Chaotic-AUR pkgs" \
    --argument-names showver

    set -l showver $argv[1]

    __require_cmd paclist "paclist (pacman-contrib) required for Chaotic-AUR"
    or return

    # all explicitly installed pkgs, regardless of repo
    set -l explicit (pacman -Qqe)

    # all installed Chaotic-AUR pkgs (explicit + deps)
    set -l chaotic_all \
        (paclist chaotic-aur 2>/dev/null | awk '{print $1}')

    # filter to only those in both sets → explicitly installed Chaotic
    set -l chaotic_explicit
    for pkg in $explicit
        if contains $pkg $chaotic_all
            set chaotic_explicit $chaotic_explicit $pkg
        end
    end

    test (count $chaotic_explicit) -eq 0; and return

    if test $showver -eq 1
        for pkg in (printf "%s\n" $chaotic_explicit | sort)
            set -l line (pacman -Q --color never $pkg)
            set -l name (string split ' ' -- $line)[1]
            set -l ver  (string split ' ' -- $line)[2]
            printf "%s%s%s %s%s%s\n" \
                $GREEN $name $RESET $BLUE $ver $RESET
        end
    else
        for pkg in (printf "%s\n" $chaotic_explicit | sort)
            printf "%s%s%s\n" $GREEN $pkg $RESET
        end
    end
end

# __get_native -- Get explicitly installed native packages (excluding AUR/Chaotic)
# Arguments:
#   showver : Flag to show versions (0/1)
# Output:
#   Lists native packages; excludes AUR and Chaotic-AUR; displays versions if requested.
# Example:
#   native -v
function __get_native --description "Get explicitly installed packages excluding AUR and Chaotic-AUR" --argument-names showver
    set showver $argv[1]
    set explicit (pacman -Qqe)
    set exclude (pacman -Qm | awk '{print $1}')
    if type -q paclist
        set exclude $exclude (paclist chaotic-aur 2>/dev/null | awk '{print $1}')
    end

    set natives
    for pkg in $explicit
        if not contains $pkg $exclude
            set natives $natives $pkg
        end
    end
    test (count $natives) -eq 0; and return

    if test $showver -eq 1
        for line in (pacman -Q --color never $natives)
            set name (string split ' ' -- $line)[1]
            set ver (string split ' ' -- $line)[2]
            printf "%s%s%s %s%s%s\n" $GREEN $name $RESET $BLUE $ver $RESET
        end
    else
        for name in $natives
            printf "%s%s%s\n" $GREEN $name $RESET
        end
    end
end

# __require_cmd -- Ensure a required command is available
# Arguments:
#   cmd  : Command to check in PATH
#   desc : Description to display if missing
# Output:
#   Prints error message and returns non-zero if the command is not found.
function __require_cmd --description "Ensure a required command is available, or display an error" --argument-names cmd desc
    if not type -q $cmd
        printf "$__NO_PACKAGES" "$desc" "$RESET" >&2
        return 1
    end
end

# __usage -- Display usage instructions for a package category command
# Arguments:
#   command : Name of the category command (native, aur, chaotic)
# Output:
#   Prints the usage synopsis and option descriptions.
function __usage --description "Display usage instructions for a package category command" --argument-names command
    printf "%sUsage:%s  %s [%s-c%s %sN%s] [%s-v%s]\n" $YELLOW $RESET $argv[1] $BLUE $RESET $RED $RESET $BLUE $RESET
    printf "  %s-c%s %sN%s   columns (0 = single line, 1 = one per line)\n  %s-v%s     show versions\n" $BLUE $RESET $RED $RESET $BLUE $RESET
end

# __run_category -- Parse options and execute a package-listing category
# Arguments:
#   category : One of 'native', 'aur', or 'chaotic'
# Output:
#   Parses -c and -v flags, calls the corresponding __get_* function, then prints
#   the package list and a summary count.
function __run_category --description "Parse options and execute category-specific package listing" --argument-names category
    set -l cols 0
    set -l showver 0
    set -l args $argv[2..]
    while set -q args[1]
        switch $args[1]
            case -c
                test (count $args) -lt 2; and __usage $category; and return 1
                set cols $args[2]
                set args $args[3..]
            case -v
                set showver 1
                set args $args[2..]
            case '*'
                __usage $category
                return 1
        end
    end
    switch $category
        case native
            set pkgs (__get_native  $showver)
        case aur
            set pkgs (__get_aur     $showver)
        case chaotic
            set pkgs (__get_chaotic $showver)
    end

    if test (count $pkgs) -eq 0
        printf "$__NO_PACKAGES" $category $RESET
        return
    end

    __print_packages $cols $pkgs
    printf "%sTotal explicitly installed %s packages:%s %d\n" $YELLOW $category $BLUE (count $pkgs)
end

# native -- List native packages
# Usage:
#   native [-c N] [-v]
# See also: __run_category
function native --description 'List native packages'
    __run_category native $argv
end

# aur -- List AUR packages
# Usage:
#   aur [-c N] [-v]
# See also: __run_category
function aur --description 'List aur packages'
    __run_category aur $argv
end

# chaotic -- List Chaotic-AUR packages
# Usage:
#   chaotic [-c N] [-v]
# See also: __run_category
function chaotic --description 'List chaotic packages'
    __run_category chaotic $argv
end

# version -- Compare installed version(s) with repository versions for given packages
# Arguments:
#   packages : One or more package names to compare
# Output:
#   Requires expac and vercmp; prints installed and repo versions and indicates
#   whether an update is available or if the installed version is newer.
# Usage:
#   version <pkg1> [pkg2 …]
# Example:
#   version fish vi
function version --description "Compare installed version(s) with repository version(s) for given packages" --argument-names packages
    # handle help flag
    if contains -- "$argv[1]" -h --help
        printf "%sUsage:%s version [-h|--help] <pkg1> [pkg2 …]\n" $YELLOW $RESET
        printf "  %sDescription:%s Compare installed version(s) (if any) with repository version(s) (if any)\n" $YELLOW $RESET
        printf "  %s-h%s, %s--help%s    Show this help message\n" $BLUE $RESET $BLUE $RESET
        return
    end
    __require_cmd expac "expac required for retrieving package version data"
    __require_cmd vercmp "vercmp required for comparing package versions"
    set -l SEPARATOR "$BLUE--------------$RESET"
    if test (count $argv) -eq 0
        printf "%sUsage: version <pkg1> [pkg2 …]%s\n" $RED $RESET >&2
        return 1
    end

    # retrieve all installed and repo versions
    set inst_data (expac -Q '%n:%v' $argv 2>/dev/null)
    set repo_data (expac -S '%n:%v' $argv 2>/dev/null)

    for pkg in $argv
        printf "%s%s:%s\n" $GREEN $pkg $RESET

        # extract versions for this package
        set -l inst_list (string match -r "^$pkg:.*" $inst_data | string replace -r "^$pkg:" "")
        set -l repo_list (string match -r "^$pkg:.*" $repo_data | string replace -r "^$pkg:" "")

        # pick highest version if multiple
        if test (count $inst_list) -gt 1
            set inst (printf "%s\n" $inst_list | sort -V | tail -n1)
        else
            set inst $inst_list
        end

        if test (count $repo_list) -gt 1
            set repo (printf "%s\n" $repo_list | sort -V | tail -n1)
        else
            set repo $repo_list
        end

        # compare and display
        if test -n "$inst" -a -n "$repo"
            if test "$inst" = "$repo"
                printf "%sInstalled:%s %s = %s%s %s(Up-to-date)%s\n" $YELLOW $BLUE $inst $BLUE $repo $YELLOW $RESET
            else
                set cmp (vercmp $inst $repo | string trim)
                switch $cmp
                    case -1
                        printf "%sInstalled:%s %s < %s%s (Update available!)%s\n" $YELLOW $RED $inst $BLUE $repo $RESET
                    case 1
                        printf "%sInstalled:%s %s > %s%s (Newer than repo)%s\n" $YELLOW $BLUE $inst $RED $repo $RESET
                end
            end
        else if test -n "$inst"
            printf "%sInstalled:%s %s%s%s %s(AUR or locally installed package)%s\n" $YELLOW $RESET $BLUE "$inst" $RESET $YELLOW $RESET
        else if test -n "$repo"
            printf "%sNot installed%s (Available in repos: %s%s)%s\n" $RED $YELLOW $BLUE $repo $RESET
        else
            printf "%sPackage not found%s (Not installed and not in repos)\n" $RED $YELLOW
        end

        printf "%s%s%s\n" $SEPARATOR
    end
end

