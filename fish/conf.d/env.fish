set -x FULL_NAME (getent passwd $USER | cut -d: -f5 | cut -d, -f1)
set -x XDG_CONFIG_HOME $HOME/.config
set -x XDG_CACHE_HOME $HOME/.cache
set -x XDG_DATA_HOME $HOME/.local/share

set -x GTK2_RC_FILES $XDG_CONFIG_HOME/gtk-2.0

set -x CARGO_HOME $XDG_DATA_HOME/cargo
set -x CARGOBIN $CARGO_HOME/bin
set -x FNM_Path $XDG_DATA_HOME/fnm
