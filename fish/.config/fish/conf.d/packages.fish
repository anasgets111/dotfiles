if type -q pacman
    # packages: list explicitly installed packages grouped by repository
    # Usage: packages [-r|--repo <repo[,repo...]>] [-v|--version] [-h|--help] [repo...]
    function packages
        argparse h/help 'r/repo=+' v/version -- $argv; or return

        if set -q _flag_h
            printf "Usage: packages [-r|--repo <repo[,...]>] [-v|--version] [-h|--help] [repo...]\n"
            printf "  -r, --repo <repo[,...]>  Filter by repo (native = core,extra,multilib; aur = foreign)\n"
            printf "  -v, --version            Show versions and sync status (✓ synced, ⬆ outdated, + ahead, • foreign)\n"
            printf "  -h, --help               Show this help\n"
            return 0
        end

        command -q expac; or begin
            echo "Error: missing required command: expac" >&2
            return 1
        end

        set -l local_lines (pacman -Qe)
        test -n "$local_lines"; or begin
            echo "No explicit packages" >&2
            return 1
        end

        # 1. Resolve repos, targets, and terminal capabilities
        set -l repos (pacman-conf --repo-list) aur
        set -l targets (string split -n ',' -- (string replace -r '\bnative\b' 'core,extra,multilib' -- $_flag_r $argv))

        set -l tty 0
        set -l c_name ""
        set -l c_ver ""
        set -l c_warn ""
        set -l c_dim ""
        set -l c_rst ""
        if isatty stdout
            set tty 1
            if set -q TERM; and test "$TERM" != dumb
                set c_name (set_color green)
                set c_ver (set_color blue)
                set c_warn (set_color yellow)
                set c_dim (set_color brblack)
                set c_rst (set_color normal)
            end
        end

        # 2. Fetch local and sync metadata (both ordered alphabetically by package name)
        set -l l_names (string split -f 1 ' ' -- $local_lines)
        set -l l_vers (string split -f 2 ' ' -- $local_lines)
        set -l sync_lines (expac -S -1 '%n\t%r\t%v' $l_names 2>/dev/null)
        set -l s_names (string split -f 1 \t -- $sync_lines)
        set -l s_repos (string split -f 2 \t -- $sync_lines)
        set -l s_vers (string split -f 3 \t -- $sync_lines)

        set -l si 1
        set -l all_repos
        set -l m_repos
        set -l m_names
        set -l m_vers
        set -l m_sts
        set -l updates 0

        for i in (seq (count $l_names))
            set -l name $l_names[$i]
            set -l lv $l_vers[$i]
            set -l r aur
            set -l rv $lv
            if test "$s_names[$si]" = "$name"
                set r $s_repos[$si]
                set rv $s_vers[$si]
                set si (math $si + 1)
            end
            set -a all_repos $r
            set -q targets[1]; and not contains -- $r $targets; and continue

            if test $tty -eq 0
                set -a m_names (set -q _flag_v; and printf "%s\t%s\t%s\t%s\t%s" $r $name $lv $rv $r; or printf "%s\t%s" $r $name)
                continue
            end

            set -a m_repos $r
            set -a m_names $name
            if set -q _flag_v
                if test "$r" = aur
                    set -a m_sts "$c_warn•$c_rst "
                    set -a m_vers $lv
                else if test "$lv" = "$rv"
                    set -a m_sts "$c_name✓$c_rst "
                    set -a m_vers $lv
                else
                    set updates (math $updates + 1)
                    if test (vercmp "$lv" "$rv") -lt 0
                        set -a m_sts "$c_warn⬆$c_rst "
                        set -a m_vers "$lv -> $rv"
                    else
                        set -a m_sts "$c_warn+$c_rst "
                        set -a m_vers "$lv ($rv)"
                    end
                end
            end
        end

        if not set -q m_names[1]
            echo "No packages found in: "(string join ", " $targets) >&2
            return 1
        end

        # 3. Piped output: plain records, no headers or footer
        if test $tty -eq 0
            for r in $repos
                string replace -rf -- "^$r\t" "" $m_names
            end
            return 0
        end

        # 4. Interactive TTY: vectorized cell padding and repo grid sections
        set -l d_names (string shorten -m (set -q _flag_v; and echo 24; or echo 28) -- $m_names)
        set -l w_n (math "max(0, "(string join , (string length --visible -- $d_names))")")
        set -l pad_names (string pad -r -w $w_n -- "$c_name"$d_names"$c_rst")

        set -l w_v 0
        set -l pad_vers
        if set -q _flag_v
            set -l d_vers (string shorten -m 26 -- $m_vers)
            set w_v (math "max(0, "(string join , (string length --visible -- $d_vers))")")
            set pad_vers " "(string pad -r -w $w_v -- "$c_ver"$d_vers"$c_rst")
        end

        set -l tagged_cells
        for i in (seq (count $m_names))
            set -a tagged_cells "$m_repos[$i]"\t"$m_sts[$i]$pad_names[$i]$pad_vers[$i]"
        end

        set -l cols $COLUMNS
        test -n "$cols"; or set cols 100
        set -l cell_w (set -q _flag_v; and math "2 + $w_n + 1 + $w_v"; or echo $w_n)
        set -l per_row (math "max(1, floor(($cols + 2) / ($cell_w + 2)))")

        set -l sections 0
        set -l alt_idx 0
        set -l cycle magenta red cyan blue
        set -l breakdown

        for r in $repos
            set -l total_r (count (string match -- $r $all_repos))
            test $total_r -eq 0; and continue

            set -l rc ""
            if test -n "$c_rst"
                switch $r
                    case core
                        set rc (set_color -o cyan)
                    case extra
                        set rc (set_color -o blue)
                    case multilib
                        set rc (set_color -o green)
                    case aur
                        set rc (set_color -o yellow)
                    case '*'
                        set alt_idx (math "($alt_idx % 4) + 1")
                        set rc (set_color -o $cycle[$alt_idx])
                end
            end
            set -a breakdown "$rc$r$c_rst $total_r"

            set -l cells (string replace -rf -- "^$r\t" "" $tagged_cells)
            set -l cnt (count $cells)
            test $cnt -eq 0; and continue
            test $sections -gt 0; and echo
            set sections (math $sections + 1)
            printf "%s%s%s %s(%d)%s\n" $rc $r $c_rst $c_dim $cnt $c_rst

            for i in (seq 1 $per_row $cnt)
                set -l end_i (math "min($cnt, $i + $per_row - 1)")
                echo (string trim -r -- (string join "  " $cells[$i..$end_i]))
            end
        end

        set -l count_str "$c_ver"(count $m_names)"$c_rst"
        set -q targets[1]; and set count_str "$count_str/"(count $l_names)
        set -l upd_str ""
        test $updates -gt 0; and set upd_str " $c_warn($updates out of sync)$c_rst"
        printf "\n%sExplicit:%s %s%s %s[%s%s%s]%s\n" \
            $c_warn $c_rst $count_str $upd_str $c_dim $c_rst (string join " $c_dim·$c_rst " $breakdown) $c_dim $c_rst
    end
end
