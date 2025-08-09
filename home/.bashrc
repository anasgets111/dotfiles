
# If this is an interactive non-login bash, exec fish
if [ -t 1 ] && [ -z "$FISH_VERSION" ] && [ -z "$STAY" ]; then
  exec fish --login
fi

# If this is an interactive non-login bash, exec nushell, use $STAY to prevent it
# if [ -t 1 ] && [ -z "$NU_VERSION" ] && [ -z "$STAY" ]; then
#   exec nu --login
# fi

