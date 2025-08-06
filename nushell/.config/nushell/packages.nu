def _list-repo [
  repos: list<string>     # list of repo names
  --explicit (-e)         # only explicitly installed?
  --version (-v)
  --columns (-c): int = 0
] {
  # Fetch all packages from each repo
  let all_packages = if ($repos | length) == 1 and ($repos | first) == "aur" {
    # Special case for AUR (foreign packages)
    ^pacman -Qm | parse "{name} {version}"
  } else {
    # For regular repositories, use paclist
    $repos | par-each { |repo| ^paclist $repo | parse "{name} {version}" } | flatten
  }

  let items = if $explicit {
    # Get explicitly installed packages and find intersection
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
      
      # Create a simple table with multiple columns
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
            # Insert id column first, then the other fields
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
