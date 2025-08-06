def _handle-packages [
  items: table
  --version (-v)
  --columns (-c): int = 1
] {
  if $version {
    $items | select name version
  } else {
    $items | select name
  }
}

def aur [
  --version (-v)
  --columns (-c): int = 1
] {
  let items = (^pacman -Qm | parse "{name} {version}")
  _handle-packages $items --version=$version --columns=$columns
}
