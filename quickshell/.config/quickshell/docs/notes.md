# Quickshell Notes

## Toasts service

- Caps Lock LED state (useful for toasts):
  - Command: `cat /sys/class/leds/input\*::capslock/brightness`
  - Values: 0 = off, 1 = on
- for systray
  - QsMenuAnchor = styled by qt
  - QsMenuOpener = you style it
