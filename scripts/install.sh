#!/usr/bin/env bash
set -euo pipefail

src_dir="${1:?Usage: install.sh <skills-source-dir>}"
dest="$HOME/.claude/skills/venom"

if [[ -L "$dest" ]]; then
    echo "Removing existing symlink: $dest"
    rm "$dest"
elif [[ -d "$dest" ]]; then
    echo "ERROR: $dest exists and is not a symlink. Remove it manually."
    exit 1
fi

mkdir -p "$(dirname "$dest")"
ln -s "$src_dir/venom" "$dest"
echo "Installed: $dest -> $src_dir/venom"
