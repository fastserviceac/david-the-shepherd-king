#!/bin/zsh
/Applications/Godot.app/Contents/MacOS/Godot --path "$(cd "$(dirname "$0")" && pwd)" >/dev/null 2>&1 &
