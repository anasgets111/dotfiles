

# let explicit: list<string> = (^pacman -Qqe | lines);
# let aur: list<string> = (^pacman -Qm | lines | each {|l| $l | split row ' ' | get 0});
# let chaotic: list<string> = (if (which paclist | is-not-empty) { ^paclist chaotic-aur | lines | each {|l| $l | split row ' ' | get 0} } else { [] });
# $explicit | where {|p| not ($p in ($aur ++ $chaotic)) }