#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# --- Privilege helper ---
# Run commands as root, using sudo when we are not root already.
if [ "$(id -u)" -eq 0 ]; then
    HAVE_ROOT=1
    as_root() { "$@"; }
elif command -v sudo >/dev/null 2>&1; then
    HAVE_ROOT=1
    as_root() { sudo "$@"; }
else
    HAVE_ROOT=0
    as_root() { echo "WARNING: cannot run as root (sudo unavailable): $*" >&2; return 1; }
fi

echo "==> Setting up dotfiles from $DOTFILES_DIR"

# --- Scripts to ~/.local/bin ---
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
LOCAL_BIN="$HOME/.local/bin"

echo "==> Linking scripts into $LOCAL_BIN"
mkdir -p "$LOCAL_BIN"

for script in "$SCRIPTS_DIR"/*; do
    name="$(basename "$script")"
    echo "    $name -> $LOCAL_BIN/$name"
    ln -sf "$script" "$LOCAL_BIN/$name"
    chmod +x "$script"
done

# --- Config folders to ~/.config ---
echo "==> Linking config folders into $HOME/.config"
for dir in nvim tmux fish; do
    src="$DOTFILES_DIR/$dir"
    dest="$HOME/.config/$dir"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "${dest}.bak"
        echo "WARNING: $dest existed, backed up to ${dest}.bak"
    fi
    echo "    $dir -> $dest"
    ln -sfn "$src" "$dest"
done

# --- .gitconfig to ~/.config/git/config ---
echo "==> Linking git config into $HOME/.config/git/config"
mkdir -p "$HOME/.config/git"
git_src="$DOTFILES_DIR/.gitconfig"
git_dest="$HOME/.config/git/config"
if [ -e "$git_dest" ] && [ ! -L "$git_dest" ]; then
    mv "$git_dest" "${git_dest}.bak"
    echo "WARNING: $git_dest existed, backed up to ${git_dest}.bak"
fi
ln -sfn "$git_src" "$git_dest"

# --- Autostart overrides to ~/.config/autostart ---
# A user-level .desktop file with the same name as a system one takes
# precedence; Discover's notifier is disabled here with Hidden=true.
echo "==> Linking autostart overrides into $HOME/.config/autostart"
mkdir -p "$HOME/.config/autostart"
for file in "$DOTFILES_DIR/autostart"/*; do
    name="$(basename "$file")"
    dest="$HOME/.config/autostart/$name"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "${dest}.bak"
        echo "WARNING: $dest existed, backed up to ${dest}.bak"
    fi
    echo "    $name -> $dest"
    ln -sfn "$file" "$dest"
done

# --- Chrony: NTS-only time sources ---
# Install our NTS drop-in into /etc/chrony.d/ and stop chronyd from also
# loading NTP servers handed out over DHCP.
#
# The drop-in is COPIED, not symlinked: chronyd runs as the unprivileged
# 'chrony' user and chronyd.service sets ProtectHome=yes, so it can never read
# a file under $HOME. /etc/chrony.d is also root-owned.
echo "==> Configuring chrony (NTS-only sources)"
CHRONY_DROPIN_SRC="$DOTFILES_DIR/chrony/10-nts.conf"
CHRONY_DROPIN_DEST="/etc/chrony.d/10-nts.conf"
CHRONY_CONF="/etc/chrony.conf"

if [ "$HAVE_ROOT" -eq 0 ]; then
    echo "WARNING: root privileges unavailable, skipping chrony configuration"
elif [ ! -d /etc/chrony.d ]; then
    echo "WARNING: /etc/chrony.d does not exist, skipping chrony configuration"
else
    echo "    installing $CHRONY_DROPIN_SRC -> $CHRONY_DROPIN_DEST"
    as_root rm -f "$CHRONY_DROPIN_DEST"
    as_root install -m 0644 -o root -g root "$CHRONY_DROPIN_SRC" "$CHRONY_DROPIN_DEST"

    if [ ! -f "$CHRONY_CONF" ]; then
        echo "WARNING: $CHRONY_CONF not found, skipping DHCP sourcedir disable"
    else
        # DHCP-provided NTP servers are injected via 'sourcedir /run/chrony-dhcp'
        # by the NetworkManager dispatcher. Comment that directive out (once).
        if as_root grep -qE '^[[:space:]]*sourcedir[[:space:]]+/run/chrony-dhcp' "$CHRONY_CONF"; then
            echo "    commenting out 'sourcedir /run/chrony-dhcp' in $CHRONY_CONF"
            as_root sed -i -E 's@^([[:space:]]*)(sourcedir[[:space:]]+/run/chrony-dhcp)@\1#\2@' "$CHRONY_CONF"
        else
            echo "    'sourcedir /run/chrony-dhcp' already disabled or absent"
        fi

        # The drop-in now provides the NTS servers, so comment out any copies
        # still living in the main config to avoid polling them twice.
        if as_root grep -qE '^[[:space:]]*server[[:space:]]+(ntp3\.fau\.de|time\.cloudflare\.com|paris\.time\.system76\.com)[[:space:]].*nts' "$CHRONY_CONF"; then
            echo "    commenting out duplicate NTS 'server' lines in $CHRONY_CONF"
            as_root sed -i -E 's@^([[:space:]]*)(server[[:space:]]+(ntp3\.fau\.de|time\.cloudflare\.com|paris\.time\.system76\.com)[[:space:]].*nts.*)$@\1#\2@' "$CHRONY_CONF"
        fi
    fi

    echo "    restarting chronyd"
    if ! as_root systemctl restart chronyd; then
        echo "WARNING: failed to restart chronyd"
    fi
fi

# --- Mask unused system services ---
# Masking links the unit to /dev/null so it can never be started, enabled, or
# pulled in as a dependency (even when a package tries to install/socket-activate
# it). This needs root; we use sudo when not already running as root.
MASKED_UNITS=(
    cups.service
    cups.socket
    cups-browsed.service
    avahi-daemon.service
    avahi-daemon.socket
    power-profiles-daemon.service
    systemd-rfkill.service
    systemd-rfkill.socket
)

echo "==> Masking unused system services"
if ! command -v systemctl >/dev/null 2>&1; then
    echo "    systemctl not found, skipping service masking"
elif [ "$HAVE_ROOT" -eq 0 ]; then
    echo "WARNING: root privileges unavailable, skipping service masking"
else
    for unit in "${MASKED_UNITS[@]}"; do
        state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
        if [ "$state" = "masked" ]; then
            echo "    [skip] $unit is already masked"
            continue
        fi
        echo "    [mask] $unit (currently: ${state:-not-found})"
        if ! as_root systemctl mask --now "$unit"; then
            echo "WARNING: failed to mask $unit"
        fi
    done
fi

echo "==> Done."
