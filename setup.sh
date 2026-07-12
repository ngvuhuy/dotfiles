#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Scripts to ~/.local/bin ---
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$LOCAL_BIN"

for script in "$SCRIPTS_DIR"/*; do
    name="$(basename "$script")"
    ln -sf "$script" "$LOCAL_BIN/$name"
    chmod +x "$script"
done

# --- Config folders to ~/.config ---
for dir in nvim tmux fish; do
    src="$DOTFILES_DIR/$dir"
    dest="$HOME/.config/$dir"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "${dest}.bak"
        echo "WARNING: $dest existed, backed up to ${dest}.bak"
    fi
    ln -sfn "$src" "$dest"
done

# --- .gitconfig to ~/.config/git/config ---
mkdir -p "$HOME/.config/git"
git_src="$DOTFILES_DIR/.gitconfig"
git_dest="$HOME/.config/git/config"
if [ -e "$git_dest" ] && [ ! -L "$git_dest" ]; then
    mv "$git_dest" "${git_dest}.bak"
    echo "WARNING: $git_dest existed, backed up to ${git_dest}.bak"
fi
ln -sfn "$git_src" "$git_dest"
