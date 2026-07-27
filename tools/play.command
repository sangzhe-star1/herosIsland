#!/bin/bash
# Double-click me. Serves the web build so the iPad can open it over wifi.
#
# The child's tablet and this Mac have to be on the same wifi. The address it
# prints goes into Safari on the iPad; the game runs in the browser, full
# screen, no App Store and no cable.
#
# Ctrl-C in this window stops it.
cd "$(dirname "$0")/../build/web" || { echo "No build yet. Export the Web preset first."; exit 1; }
IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo localhost)
echo
echo "  小英雄成长岛 is running."
echo
echo "  On this Mac:      http://localhost:8000/index.html"
echo "  On the iPad:      http://$IP:8000/index.html"
echo
echo "  In Safari, tap the share button and 'Add to Home Screen' to get a"
echo "  full-screen icon with no address bar."
echo
echo "  Ctrl-C here to stop."
echo
python3 -m http.server 8000
