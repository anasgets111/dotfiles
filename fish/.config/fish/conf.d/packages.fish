if type -q pacman
    # packages: list explicitly installed packages (by repo)
    # Usage: packages [-r|--repo <repo[,repo...]>] [-v|--version]
    function packages
        set -l c_name (set_color green)
        set -l c_ver (set_color blue)
        set -l c_warn (set_color yellow)
        set -l c_rst (set_color normal)
        set -l missing
        for cmd in expac vercmp
            command -q $cmd; or set -a missing $cmd
        end
        if test (count $missing) -gt 0
            echo "Error: missing required commands: "(string join ", " $missing)
            return 1
        end
        argparse 'r/repo=+' v/version -- $argv || return

        set -l detected (pacman-conf --repo-list)
        set -l repos $argv
        set -l check_aur 0
        set -l auto 0
        set -l used_native 0
        set -l used_aur 0
        if set -q _flag_r
            set repos (string split ',' -- $_flag_r)
        else if test (count $repos) -eq 0
            set repos $detected
            set check_aur 1
            set used_aur 1
            set used_native 1
            set auto 1
        end

        set -l target
        for r in $repos
            switch $r
                case aur
                    set check_aur 1
                    set used_aur 1
                case native
                    set used_native 1
                    set -a target core extra multilib
                case '*'
                    set -a target $r
            end
        end
        set target (printf '%s\n' $target | sort -u)
        set target (string match -r '.+' -- $target)

        set -l installed (pacman -Qqe)
        test -z "$installed"; and begin
            echo "No explicit packages" >&2
            return 1
        end
        set -l repo_re (string join '|' -- $target)
        test -z "$repo_re"; and set repo_re '^$' || set repo_re '^('$repo_re')$'

        set -l fmt_local '%n'
        set -l fmt_repo '%r\t%n'
        if set -q _flag_v
            set fmt_local '%n\t%v'
            set fmt_repo '%r\t%n\t%v'
        end
        set -l local_list (expac -Q $fmt_local $installed)
        set -l repo_list (expac -S $fmt_repo $installed 2>/dev/null)
        set -l sep (printf '\x1f')
        set -l info (printf '%s\n%s\n' $local_list $repo_list | awk -F'\t' -v regex="$repo_re" -v check_aur="$check_aur" -v verbose="$_flag_v" -v sep="$sep" '
            NF==0 { next }
            NF==1 || (verbose && NF==2) { name=$1; local_ver[name]=$(NF); next }
            { repo=$1; name=$2; seen[name]=1; if(repo~regex && !printed[name]++) print name (verbose ? sep local_ver[name] sep $3 : "") }
            END{ if(check_aur) for(pkg in local_ver) if(!seen[pkg]) print pkg (verbose ? sep local_ver[pkg] sep local_ver[pkg] : "") }
        ' | sort)

        set -l pkg_count (count $info)
        if test $pkg_count -eq 0
            set -l searched $target
            test $check_aur -eq 1; and set -a searched aur
            echo "No packages found in: "(string join ", " $searched)
            return 1
        end

        if set -q _flag_v
            set -l statuses
            set -l names
            set -l locals
            set -l w_name 0
            set -l w_local 0
            for pkg in $info
                set -l f (string split $sep -- $pkg)
                set -l name $f[1]
                set -l lver $f[2]
                set -l rver $f[3]
                set -l st "✓"
                if test "$lver" != "$rver"
                    set st "+"
                    test (vercmp "$lver" "$rver") -lt 0; and set st "⬆"
                end
                test (string length --visible -- $name) -gt 24; and set name (string sub -s 1 -l 24 -- $name)
                set -a statuses $st
                set -a names $name
                set -a locals $lver
                set -l ln (string length --visible -- $name)
                test $ln -gt $w_name; and set w_name $ln
                set -l lv (string length --visible -- $lver)
                test $lv -gt $w_local; and set w_local $lv
            end
            set -l triplets
            for i in (seq (count $names))
                set -l st $statuses[$i]
                set -l nm $names[$i]
                set -l lv $locals[$i]
                set -l stc $c_warn
                test "$st" = "✓"; and set stc $c_name
                set -l name_pad (string repeat -n (math "$w_name - "(string length --visible -- $nm)) " ")
                set -l local_pad (string repeat -n (math "max(0, $w_local - "(string length --visible -- $lv)" - 1)") " ")
                set -a triplets (printf "%s%s%s %s%s%s%s %s%s%s%s" $stc $st $c_rst $c_name $nm $c_rst $name_pad $c_ver $lv $c_rst $local_pad)
            end
            set -l per_row 3
            set -l total (count $triplets)
            set -l i 1
            while test $i -le $total
                set -l end (math "$i + $per_row - 1")
                test $end -gt $total; and set end $total
                echo (string join "  " $triplets[$i..$end])
                set i (math "$end + 1")
            end
        else
            set -l display
            for pkg in $info
                set -a display "$c_name"(string split \t -- $pkg)[1]"$c_rst"
            end
            echo (string join " " $display)
        end

        set -l repo_parts
        for repo in $target
            set -l color $c_ver
            if test $used_native -eq 1
                switch $repo
                    case core extra multilib
                        set color $c_name
                end
            end
            set -a repo_parts "$color$repo$c_rst"
        end
        set -l repo_label (string join "," $repo_parts)
        set -l repo_prefix ""
        test $auto -eq 1; and set repo_prefix "$c_warn""auto:""$c_rst"

        set -l detected_target (printf '%s\n' $detected | sort -u)
        set -l detected_re (string join '|' -- $detected_target)
        test -z "$detected_re"; and set detected_re '^$' || set detected_re '^('$detected_re')$'
        set -l local_names (printf '%s\n' $local_list | awk -F'\t' '{print $1}')
        set -l detected_info (printf '%s\n%s\n' $local_names $repo_list | awk -F'\t' -v regex="$detected_re" -v check_aur="$check_aur" '
            NF==0 { next }
            NF==1 { name=$1; local_seen[name]=1; next }
            { repo=$1; name=$2; if(repo~regex && local_seen[name] && !printed[name]++) { print name; seen[name]=1 } }
            END{ if(check_aur) for(pkg in local_seen) if(!seen[pkg]) print pkg }
        ' | sort)
        set -l detected_count (count $detected_info)

        set -l detected_parts
        for repo in $detected_target
            set -l color $c_ver
            switch $repo
                case core extra multilib
                    set color $c_name
            end
            set -a detected_parts "$color$repo$c_rst"
        end
        set -l detected_label (string join "," $detected_parts)
        test $check_aur -eq 1; and set detected_label "$detected_label,$c_warn""aur""$c_rst"

        set -l used_label "$repo_prefix$repo_label"
        if test $used_aur -eq 1
            test -n "$repo_label"; and set used_label "$used_label "
            set used_label "$used_label$c_warn""aur""$c_rst"
        end

        if test $auto -eq 1
            printf '\n%sExplicit packages:%s %s%d%s (repos: %s)\n' $c_warn $c_rst $c_ver $pkg_count $c_rst $detected_label
        else
            printf '\n%sExplicit packages:%s %s%d%s (used: %s) | %sDetected repos:%s %s%d%s (detected: %s)\n' \
                $c_warn $c_rst $c_ver $pkg_count $c_rst $used_label $c_warn $c_rst $c_ver $detected_count $c_rst $detected_label
        end
    end
end
