# uv tool executables live outside ~/.local/bin
set -gx UV_TOOL_BIN_DIR ~/.local/share/uv/bin
fish_add_path -g ~/.local/share/uv/bin
