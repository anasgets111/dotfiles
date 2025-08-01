
# If this is an interactive non-login bash, exec fish
if [ -t 1 ] && [ -z "$FISH_VERSION" ]; then
  exec fish --login
fi

