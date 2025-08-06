def _handle-packages [
  items: table
  --version (-v)
  --columns (-c): int = 0
] {
  if $columns < 0 {
    print "Error: columns must be a non-negative integer."
    return
  }
  
  let fields = if $version { ["name", "version"] } else { ["name"] }
  let selected_items = ($items | select ...$fields)
  
  match $columns {
    0 => {
      if $version {
        $selected_items | each { |row| $"($row.name) ($row.version)" } | str join " "
      } else {
        $selected_items | get name | str join " "
      }
    }
    1 => {
      $selected_items | table -i false
    }
    _ => {
      let total_items = ($selected_items | length)
      let items_per_column = (($total_items / $columns) | math ceil)
      
      let chunks = ($selected_items 
        | enumerate 
        | each { |row| 
            $row.item | insert "id" ($row.index + 1)
          }
        | chunks $items_per_column)
      
      # Pad chunks to ensure exactly $columns columns
      let padded_chunks = if ($chunks | length) < $columns {
        $chunks | append (0..(($columns - ($chunks | length)) - 1) | each { |_| [] })
      } else {
        $chunks
      }
      
      0..($items_per_column - 1) | each { |row_idx|
        let row_data = ($padded_chunks | each { |chunk| $chunk | get -o $row_idx })
        
        $row_data | enumerate | reduce -f {} { |item, acc|
          let col_idx = $item.index
          let data = $item.item
          
          if ($data == null) {
            $acc
          } else {
            let suffix = if $col_idx == 0 { "" } else { $".($col_idx)" }
            (["id"] | append $fields) | reduce -f $acc { |field_name, acc_inner|
              let column_name = $"($field_name)($suffix)"
              $acc_inner | insert $column_name ($data | get $field_name)
            }
          }
        }
      } | where { |row| 
        ($row | values | any { |val| $val != null })
      } | table -i false
    }
  }
}

def aur [
  --version (-v)
  --columns (-c): int = 0
] {
  let items = (^pacman -Qm | parse "{name} {version}")
  _handle-packages $items --version=$version --columns=$columns 
}

def chaotic [
  --version (-v)
  --columns (-c): int = 0
] {
  # Get all packages from chaotic-aur repository
  let chaotic_packages = (^paclist chaotic-aur | parse "{name} {version}")
  
  # Get all explicitly installed packages
  let explicit_packages = (^pacman -Qe | parse "{name} {version}")
  
  # Find intersection: packages that are both from chaotic-aur AND explicitly installed
  let items = ($chaotic_packages | join $explicit_packages name name)
  
  _handle-packages $items --version=$version --columns=$columns 
}

def native [
  --version (-v)
  --columns (-c): int = 0
] {
  # Get all packages from official repositories (core, extra, multilib)
  let core_packages = (^paclist core | parse "{name} {version}")
  let extra_packages = (^paclist extra | parse "{name} {version}")
  let multilib_packages = (^paclist multilib | parse "{name} {version}")
  
  # Combine all official repo packages
  let official_packages = ($core_packages | append $extra_packages | append $multilib_packages)
  
  # Get all explicitly installed packages
  let explicit_packages = (^pacman -Qe | parse "{name} {version}")
  
  # Find intersection: packages that are both from official repos AND explicitly installed
  let items = ($official_packages | join $explicit_packages name name)
  
  _handle-packages $items --version=$version --columns=$columns 
}
