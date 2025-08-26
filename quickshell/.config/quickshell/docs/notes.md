# Quickshell Notes

## Toasts service

- Caps Lock LED state (useful for toasts):
  - Command: `cat /sys/class/leds/input\*::capslock/brightness`
  - Values: 0 = off, 1 = on
- for systray
  - QsMenuAnchor = styled by qt
  - QsMenuOpener = you style it

# Testing Notifications

`quickshell ipc call notifs send "Title" "Body" '{"appName":"demo"}'`
## normal (string)
`quickshell ipc call notifs send "Normal" "Default timeout" '{"appName":"demo","urgency":"normal"}'`

## low (shorter timeout)

`quickshell ipc call notifs send "Low" "Lower priority" '{"appName":"demo","urgency":"low"}'`

## critical (no auto-expire by default)

`quickshell ipc call notifs send "Critical" "Stays until dismissed" '{"appName":"demo","urgency":"critical"}'`

## numeric urgency (0=Low,1=Normal,2=Critical)

`quickshell ipc call notifs send "Numeric" "Urgency=2" '{"appName":"demo","urgency":2}'`

## never expire (explicit)

`quickshell ipc call notifs send "Persistent" "expireTimeout=0" '{"appName":"demo","expireTimeout":0}'`

## custom timeout (ms)

`quickshell ipc call notifs send "Custom TTL" "7.5s" '{"appName":"demo","expireTimeout":7500}'`

## actions as string pairs [id,title, id,title, ...]

`quickshell ipc call notifs send "With Actions" "Choose an action" '{"appName":"demo","actions":["default","Open","dismiss","Dismiss"]}'`

## actions as objects with optional iconName

`quickshell ipc call notifs send "Action Objects" "Icons too" '{"appName":"demo","actions":[{"id":"open","title":"Open","iconName":"document-open"},{"id":"snooze","title":"Snooze","iconName":"alarm"}]}'`

## themed icon name

`quickshell ipc call notifs send "Icon Test" "Using theme icon" '{"appName":"demo","appIcon":"mail-unread"}'`

## absolute icon path

`quickshell ipc call notifs send "Icon File" "From disk" '{"appName":"demo","appIcon":"file:///usr/share/icons/hicolor/64x64/apps/utilities-terminal.png"}'`

## content image

`quickshell ipc call notifs send "Image Content" "Screenshot preview" '{"appName":"demo","image":"file:///home/$USER/Pictures/sample.png"}'`

## allow simple tags; links sanitized

`quickshell ipc call notifs send "Markup" "<b>Bold</b> and <a href=\"https://example.com\">link</a>" '{"appName":"demo","urgency":"normal","bodyFormat":"markup"}'`
`quickshell ipc call notifs send "Build" "Passed ✅" '{"appName":"ci"}'`
`quickshell ipc call notifs send "Build" "Failed ❌" '{"appName":"ci","urgency":"critical"}'`
`quickshell ipc call notifs send "Message" "Ping" '{"appName":"chat"}'`

`quickshell ipc call notifs.list`
`quickshell ipc call notifs.actions "<id>"`
`quickshell ipc call notifs.reply "<id>" "Thanks!"`
`quickshell ipc call notifs.acknowledge "<id>"`
`quickshell ipc call notifs.dismiss "<id>"`
