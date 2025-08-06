def _list-repo [
    repos: list<string>
    --explicit (-e)
    --version (-v)
    --columns (-c): int = 0
] {
    let all_packages = if ($repos | length) == 1 and ($repos | first) == "aur" {
        ^pacman -Qm | parse "{name} {version}"
    } else {
        $repos | par-each { |repo| ^paclist $repo | parse "{name} {version}" } | flatten
    }

    let items = if $explicit {
        let explicit_packages = (^pacman -Qe | parse "{name} {version}")
        $all_packages | join $explicit_packages name name | select name version
    } else {
        $all_packages
    }

    _handle-packages $items --version=$version --columns=$columns
}

def _handle-packages [
    items: table
    --version (-v)
    --columns (-c): int = 0
] {
    if $columns < 0 {
        error make { msg: "columns must be a non-negative integer." }
    }

    let fields = if $version { ["name", "version"] } else { ["name"] }

    match $columns {
        0 => {
            if $version {
                $items | each { |row| $"($row.name) ($row.version)" } | str join " "
            } else {
                $items | get name | str join " "
            }
        }
        1 => {
            $items | select ...$fields | table -i false
        }
        _ => {
            let selected_items = ($items | select ...$fields)
            let total_items = ($selected_items | length)
            let items_per_column = (($total_items / $columns) | math ceil)

            0..<$items_per_column | each { |row_idx|
                let row_data = (0..<$columns | each { |col_idx|
                    let item_idx = ($col_idx * $items_per_column + $row_idx)
                    if $item_idx < $total_items {
                        {data: ($selected_items | get $item_idx), idx: ($item_idx + 1)}
                    } else {
                        null
                    }
                })

                let result = ({})
                let result = (0..<$columns | reduce -f $result { |col_idx, acc|
                    let item_info = ($row_data | get -o $col_idx)
                    if ($item_info != null) {
                        let suffix = if $col_idx == 0 { "" } else { $".($col_idx)" }
                        let acc_with_id = ($acc | insert $"id($suffix)" $item_info.idx)
                        $fields | reduce -f $acc_with_id { |field_name, acc_inner|
                            let column_name = $"($field_name)($suffix)"
                            $acc_inner | insert $column_name ($item_info.data | get $field_name)
                        }
                    } else {
                        $acc
                    }
                })

                $result
            } | where { |row| 
                ($row | columns | length) > 0
            } | table -i false
        }
    }
}

def aur [
    --version (-v)
    --columns (-c): int = 0
] {
    _list-repo ["aur"] --version=$version --columns=$columns 
}

def chaotic [
    --version (-v)
    --columns (-c): int = 0
] {
    _list-repo ["chaotic-aur"] --explicit --version=$version --columns=$columns 
}

def native [
    --version (-v)
    --columns (-c): int = 0
] {
    _list-repo ["core", "extra", "multilib"] --explicit --version=$version --columns=$columns 
}

def pkg-version [
    ...packages: string
] {
    let installed_data = try {
        ^expac -Q '%n:%v' ...$packages 
        | lines 
        | where $it != "" 
        | parse "{name}:{version}"
    } catch {
        []
    }

    let repo_data = try {
        ^expac -S '%n:%v' ...$packages
        | lines
        | where $it != ""
        | parse "{name}:{version}"
    } catch {
        []
    }

    $packages | each { |pkg|
        let inst_versions = ($installed_data | where name == $pkg | get version)
        let repo_versions = ($repo_data | where name == $pkg | get version)

        let inst_ver = if ($inst_versions | length) > 0 {
            $inst_versions | sort | last
        } else {
            null
        }

        let repo_ver = if ($repo_versions | length) > 0 {
            $repo_versions | sort | last  
        } else {
            null
        }

        let status = if ($inst_ver != null) and ($repo_ver != null) {
            if $inst_ver == $repo_ver {
                "Up-to-date"
            } else {
                let cmp = try {
                    ^vercmp $inst_ver $repo_ver | str trim | into int
                } catch {
                    0
                }

                if $cmp < 0 {
                    "Update available"
                } else if $cmp > 0 {
                    "Newer than repo"
                } else {
                    "Up-to-date"
                }
            }
        } else if ($inst_ver != null) and ($repo_ver == null) {
            "AUR/local only"
        } else if ($inst_ver == null) and ($repo_ver != null) {
            "Not installed"
        } else {
            "Not found"
        }

        {
            name: $pkg,
            installed: ($inst_ver | default ""),
            repo: ($repo_ver | default ""),
            status: $status
        }
    }
}

