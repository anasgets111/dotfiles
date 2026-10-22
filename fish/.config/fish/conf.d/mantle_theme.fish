# Mantle's wallpaper colours (`themes/mantle.theme`), re-chosen at the first prompt after it changes.
status is-interactive; or return
function __mantle_theme --on-event fish_prompt
    set -l stamp (path mtime $__fish_config_dir/themes/mantle.theme)
    test "$stamp" = "$__mantle_theme_stamp"; and return
    set -g __mantle_theme_stamp $stamp
    fish_config theme choose mantle
end
