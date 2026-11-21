#!/data/data/com.termux/files/usr/bin/bash
# ─────────────────────────────────────────────────────────────
#  Termux Beautify — uninstaller
#  https://github.com/JackRipper-ID/termux-beautify
# ─────────────────────────────────────────────────────────────
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
TERMUX_DIR="$HOME/.termux"
MOTD_SH="$TERMUX_DIR/motd.sh"
COLORS="$TERMUX_DIR/colors.properties"
PROPS="$TERMUX_DIR/termux.properties"
BASHRC="$HOME/.bashrc"
BACKUP_ROOT="$HOME/.termux-beautify"
BACKUP_DIR="$BACKUP_ROOT/original"
MB="# >>> termux-beautify >>>"
ME="# <<< termux-beautify <<<"

GRN="\033[38;2;0;255;156m"
DIM="\033[38;2;110;140;130m"
WARN="\033[38;2;255;216;102m"
RST="\033[0m"
BOLD="\033[1m"

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

step() { printf '\n%b▸%b %b%s%b\n' "$GRN" "$RST" "$BOLD" "$*" "$RST"; }
ok()   { printf '  %b✔%b %s\n' "$GRN" "$RST" "$*"; }
warn() { printf '  %b▲%b %s\n' "$WARN" "$RST" "$*"; }
info() { printf '  %b·%b %s\n' "$DIM" "$RST" "$*"; }

printf '\n%b  TERMUX BEAUTIFY%b %b·%b %buninstall%b\n' "$BOLD" "$RST" "$GRN" "$RST" "$DIM" "$RST"

strip_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -qF "$MB" "$file" || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would clean $(basename "$file")"
    return 0
  fi
  awk -v b="$MB" -v e="$ME" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
  ' "$file" > "$file.tb.tmp" && mv "$file.tb.tmp" "$file"
}

# older installs used timestamped folders, so fall back to the newest
if [ ! -d "$BACKUP_DIR" ] && [ -d "$BACKUP_ROOT" ]; then
  BACKUP_DIR="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'backup-*' 2>/dev/null | sort | tail -n 1)"
fi

state_value() {
  [ -n "${BACKUP_DIR:-}" ] && [ -f "$BACKUP_DIR/state" ] || { printf 'unknown'; return 0; }
  grep -m1 "^$1=" "$BACKUP_DIR/state" 2>/dev/null | cut -d= -f2 || printf 'unknown'
}

step "Reverting"

# ── login banner ─────────────────────────────────────────────
motd_state="$(state_value motd_sh)"
if [ -f "$BACKUP_DIR/motd.sh" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would restore your previous motd.sh"
  else
    cp -a "$BACKUP_DIR/motd.sh" "$MOTD_SH"
    chmod 755 "$MOTD_SH"
    ok "previous banner restored"
  fi
else
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would remove the custom banner"
  else
    rm -f "$MOTD_SH"
    ok "custom banner removed (the default Termux banner is back)"
  fi
fi
[ "$motd_state" = "unknown" ] && warn "no state file — the banner was handled by inspection"

# ── terminal colors ──────────────────────────────────────────
colors_state="$(state_value colors)"
if [ "$colors_state" = "absent" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would remove colors.properties (it did not exist before)"
  else
    rm -f "$COLORS"
    ok "colors.properties removed"
  fi
elif [ -f "$BACKUP_DIR/colors.properties" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would restore your previous colors.properties"
  else
    cp -a "$BACKUP_DIR/colors.properties" "$COLORS"
    ok "previous colors restored"
  fi
else
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would remove colors.properties"
  else
    rm -f "$COLORS"
    ok "custom colors removed"
  fi
fi

# ── app properties + shell config ────────────────────────────
strip_block "$PROPS"
strip_block "$BASHRC"
[ "$DRY_RUN" -eq 1 ] || ok "shell config cleaned"

if [ "$DRY_RUN" -eq 0 ] && command -v termux-reload-settings >/dev/null 2>&1; then
  termux-reload-settings >/dev/null 2>&1 || true
  ok "settings reloaded"
fi

printf '\n'
info "backups kept in $BACKUP_ROOT"
info "delete them with: rm -rf $BACKUP_ROOT"
printf '\n'
