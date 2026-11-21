#!/data/data/com.termux/files/usr/bin/bash
# ─────────────────────────────────────────────────────────────
#  Termux Beautify — modern hacker theme
#  https://github.com/JackRipper-ID/termux-beautify
#
#  Modern hacker look for Termux: adaptive login banner, phosphor
#  green palette, two-line prompt with git branch, aliases, keys.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

TB_VERSION="1.0.0"
MB="# >>> termux-beautify >>>"
ME="# <<< termux-beautify <<<"

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
TERMUX_DIR="$HOME/.termux"
MOTD_SH="$TERMUX_DIR/motd.sh"
COLORS="$TERMUX_DIR/colors.properties"
PROPS="$TERMUX_DIR/termux.properties"
BASHRC="$HOME/.bashrc"
BACKUP_ROOT="$HOME/.termux-beautify"
BACKUP_DIR="$BACKUP_ROOT/original"

DO_PACKAGES=1
DO_BANNER=1
DO_COLORS=1
DO_MATRIX=1
DO_ANIM=1
BANNER_STYLE="auto"   # auto | line | art
DRY_RUN=0

# ── palette (hacker: phosphor green + cyan) ──────────────────
GRN="\033[38;2;0;255;156m"
GRN2="\033[38;2;0;232;143m"
GRN3="\033[38;2;0;209;130m"
GRN4="\033[38;2;0;184;117m"
GRN5="\033[38;2;0;159;104m"
GRN6="\033[38;2;0;134;91m"
CYAN="\033[38;2;0;200;255m"
DIM="\033[38;2;110;140;130m"
WARN="\033[38;2;255;216;102m"
ERR="\033[38;2;255;95;86m"
OK="\033[38;2;0;255;156m"
RST="\033[0m"
BOLD="\033[1m"

# ── helpers ──────────────────────────────────────────────────
banner() {
  printf '\n'
  printf '%b%s%b\n' "$GRN"  '████████╗  ███████╗  ██████╗   ███╗   ███╗  ██╗   ██╗  ██╗  ██╗' "$RST"
  printf '%b%s%b\n' "$GRN2" '╚══██╔══╝  ██╔════╝  ██╔══██╗  ████╗ ████║  ██║   ██║  ╚██╗██╔╝' "$RST"
  printf '%b%s%b\n' "$GRN3" '   ██║     █████╗    ██████╔╝  ██╔████╔██║  ██║   ██║   ╚███╔╝ ' "$RST"
  printf '%b%s%b\n' "$GRN4" '   ██║     ██╔══╝    ██╔══██╗  ██║╚██╔╝██║  ██║   ██║   ██╔██╗ ' "$RST"
  printf '%b%s%b\n' "$GRN5" '   ██║     ███████╗  ██║  ██║  ██║ ╚═╝ ██║  ╚██████╔╝  ██╔╝ ██╗' "$RST"
  printf '%b%s%b\n' "$GRN6" '   ╚═╝     ╚══════╝  ╚═╝  ╚═╝  ╚═╝     ╚═╝   ╚═════╝   ╚═╝  ╚═╝' "$RST"
  printf '%b  BEAUTIFY%b %b·%b %bmodern hacker theme%b %b·%b %bv%s%b\n\n' \
    "$BOLD" "$RST" "$GRN3" "$RST" "$BOLD" "$RST" "$GRN3" "$RST" "$DIM" "$TB_VERSION" "$RST"
}

step()  { printf '\n%b▸%b %b%s%b\n' "$GRN" "$RST" "$BOLD" "$*" "$RST"; }
ok()    { printf '  %b✔%b %s\n' "$OK" "$RST" "$*"; }
warn()  { printf '  %b▲%b %s\n' "$WARN" "$RST" "$*"; }
die()   { printf '  %b✘%b %s\n' "$ERR" "$RST" "$*" >&2; exit 1; }
info()  { printf '  %b·%b %s\n' "$DIM" "$RST" "$*"; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  %b≈%b %s %b(dry-run)%b\n' "$DIM" "$RST" "$1" "$DIM" "$RST"
    return 0
  fi
  printf '  %b⟳%b %s\n' "$GRN3" "$RST" "$1"
  shift
  if ! "$@" >/dev/null 2>&1; then
    warn "skipped: $*"
    return 1
  fi
  return 0
}

state_value() {
  [ -f "$BACKUP_DIR/state" ] || { printf 'unknown'; return 0; }
  grep -m1 "^$1=" "$BACKUP_DIR/state" 2>/dev/null | cut -d= -f2 || printf 'unknown'
}

init_backup_state() {
  [ "$DRY_RUN" -eq 1 ] && return 0
  mkdir -p "$BACKUP_DIR"
  [ -f "$BACKUP_DIR/state" ] && return 0
  {
    if [ -f "$COLORS" ]; then echo "colors=present"; else echo "colors=absent"; fi
    if [ -f "$MOTD_SH" ]; then echo "motd_sh=present"; else echo "motd_sh=absent"; fi
  } > "$BACKUP_DIR/state"
}

backup_file() {
  local src="$1" key="${2:-}"
  [ -e "$src" ] || return 0
  if [ -n "$key" ] && [ -f "$BACKUP_DIR/state" ]; then
    case "$(state_value "$key")" in
      absent) return 0 ;;
    esac
  fi
  local dest="$BACKUP_DIR/$(basename "$src")"
  [ -e "$dest" ] && return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would back up $(basename "$src")"
    return 0
  fi
  cp -a "$src" "$dest"
  ok "backup: $(basename "$src")"
}

strip_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -qF "$MB" "$file" || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would rewrite $(basename "$file")"
    return 0
  fi
  awk -v b="$MB" -v e="$ME" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
  ' "$file" > "$file.tb.tmp" && mv "$file.tb.tmp" "$file"
}

# ── steps ────────────────────────────────────────────────────
check_env() {
  step "Checking environment"
  case "$PREFIX" in
    */com.termux/files/usr) ;;
    *) die "This is not a Termux environment (PREFIX=$PREFIX). Run it inside Termux." ;;
  esac
  [ -d "$PREFIX" ] || die "Prefix not found: $PREFIX"
  [ -z "${TERMUX_VERSION:-}" ] && warn "TERMUX_VERSION is not set — continuing anyway."
  ok "Termux prefix: $PREFIX"

  TB_DEVICE="$(getprop ro.product.model 2>/dev/null || true)"
  [ -n "$TB_DEVICE" ] || TB_DEVICE="android"
  TB_OS="$(getprop ro.build.version.release 2>/dev/null || true)"
  [ -n "$TB_OS" ] || TB_OS="Android"
  ok "device: $TB_DEVICE · $TB_OS"
}

install_packages() {
  step "Installing terminal packages"
  command -v pkg >/dev/null 2>&1 || { warn "pkg not found — skipping packages."; return 0; }
  local pkgs="git ncurses-utils bash-completion command-not-found less nano iproute2 procps"
  info "packages: $pkgs"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would run: pkg install -y $pkgs"
    return 0
  fi
  printf '  %b⟳%b running pkg install (this can take a while)\n' "$GRN3" "$RST"
  if pkg install -y $pkgs >/dev/null 2>&1; then
    ok "packages installed"
  else
    warn "pkg install had errors — rerun: pkg install -y $pkgs"
  fi
}

write_banner() {
  step "Writing the login banner"
  mkdir -p "$TERMUX_DIR"
  backup_file "$MOTD_SH" motd_sh

  if [ "$DRY_RUN" -eq 1 ]; then
    info "would write $MOTD_SH (style: $BANNER_STYLE, animation: $([ "$DO_ANIM" -eq 1 ] && echo on || echo off))"
    return 0
  fi

  if [ "$DO_BANNER" -eq 0 ]; then
    cat > "$MOTD_SH" <<'EMPTY_MOTD'
#!/data/data/com.termux/files/usr/bin/bash
# termux-beautify: banner disabled (--no-banner)
exit 0
EMPTY_MOTD
    chmod 755 "$MOTD_SH"
    ok "login banner cleared (shown empty)"
    return 0
  fi

  cat > "$MOTD_SH" <<'MOTD_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# termux-beautify banner — generated, edit install.sh instead

STYLE="__TB_STYLE__"   # auto | line | art
ANIM="__TB_ANIM__"     # 1 | 0

G=$'\e[38;2;0;255;156m'
G2=$'\e[38;2;0;232;143m'
G3=$'\e[38;2;0;209;130m'
G4=$'\e[38;2;0;184;117m'
G5=$'\e[38;2;0;159;104m'
G6=$'\e[38;2;0;134;91m'
FG=$'\e[38;2;200;255;220m'
C=$'\e[38;2;0;200;255m'
D=$'\e[38;2;110;140;130m'
R=$'\e[0m'
B=$'\e[1m'

cols=$(stty size 2>/dev/null | cut -d' ' -f2)
[[ "$cols" =~ ^[0-9]+$ ]] || cols=80

device=$(getprop ro.product.model 2>/dev/null); [ -n "$device" ] || device="android"
rel=$(getprop ro.build.version.release 2>/dev/null); [ -n "$rel" ] || rel="?"
kernel=$(uname -r 2>/dev/null)
uptime_txt=$(uptime 2>/dev/null | sed 's/.*up //; s/,.*//; s/^ *//')
storage=$(df -h "$HOME" 2>/dev/null | awk 'NR==2 { print $4" free" }')
wifi=""
if command -v ip >/dev/null 2>&1; then
  # interface names vary by ROM (wlan0, swlan0, ap0...)
  wifi=$(ip -4 -o addr show 2>/dev/null | awk '$2 ~ /^(wlan|swlan|ap|wifi)/ { print $4; exit }')
  [ -n "$wifi" ] || wifi=$(ip -4 -o addr show 2>/dev/null | awk '$2 != "lo" && $4 !~ /^127\./ { print $4; exit }')
fi

# animation only on a real terminal, and only if enabled at install time
anim=0
[ "$ANIM" = "1" ] && [ -t 1 ] && anim=1

repeat() { local n=$1 s=$2 out='' i; for ((i = 0; i < n; i++)); do out+=$s; done; printf '%s' "$out"; }

tw() {  # typewriter for an ASCII chunk
  local s="$1" c="$2" i=0
  while [ "$i" -lt "${#s}" ]; do
    printf '%s%s%s' "$c" "${s:$i:1}" "$R"
    i=$((i + 1))
    [ "$anim" -eq 1 ] && sleep 0.007
  done
}

pause() { [ "$anim" -eq 1 ] && sleep "${1:-0.04}"; }

CHARS="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#\$%&*+=<>/"
randch() { printf '%s' "${CHARS:$(( RANDOM % ${#CHARS} )):1}"; }

decrypt() {  # scramble each letter until it locks, then settle
  local word="$1" frames="${2:-6}" f i out locked bar len
  len=${#word}
  for ((f = 1; f <= frames; f++)); do
    locked=$(( len * f / frames ))
    out=""
    for ((i = 0; i < len; i++)); do
      if [ "$i" -lt "$locked" ]; then out+="${word:$i:1}"; else out+="$(randch)"; fi
    done
    if [ $((f % 2)) -eq 0 ]; then bar=$G; else bar=$G2; fi
    printf '\r  %s%s▌%s %s%s%s %s%s▌%s' "$bar" "$B" "$R" "$G$B" "$out" "$R" "$bar" "$B" "$R"
    sleep 0.035
  done
}

glitch() {  # short flicker before the word locks in
  [ "$anim" -eq 1 ] || return 0
  local word="TERMUX" k i pos out
  for k in 1 2 3; do
    out="$word"
    for i in 1 2 3; do
      pos=$(( RANDOM % ${#word} ))
      out="${out:0:pos}$(randch)${out:$(( pos + 1 ))}"
    done
    printf '\r  %s%s▌%s %s%s%s %s%s▌%s' "$G" "$B" "$R" "$D$B" "$out" "$R" "$G" "$B" "$R"
    sleep 0.05
  done
  printf '\r  %s%s▌%s %s%s%s %s%s▌%s' "$G" "$B" "$R" "$G$B" "$word" "$R" "$G" "$B" "$R"
}

rule() {  # gradient rule, drawn in eight steps
  local width=$1 seg i c drawn
  seg=$(( width / 8 )); [ "$seg" -lt 1 ] && seg=1
  for i in 1 2 3 4 5 6 7 8; do
    case $i in
      1|2) c=$G ;; 3) c=$G2 ;; 4) c=$G3 ;; 5) c=$G4 ;; 6) c=$G5 ;; *) c=$G6 ;;
    esac
    printf '%s%s%s' "$c" "$(repeat "$seg" '─')" "$R"
    [ "$anim" -eq 1 ] && sleep 0.022
  done
  drawn=$(( seg * 8 ))
  [ "$drawn" -lt "$width" ] && printf '%s%s%s' "$G6" "$(repeat $(( width - drawn )) '─')" "$R"
  printf '\n'
}

sweep() {  # bright segment travelling along the gradient rule
  [ "$anim" -eq 1 ] || return 0
  local width=$1 pos span=8 i out c step first=1
  step=$(( width / 10 )); [ "$step" -lt 2 ] && step=2
  for pos in $(seq 0 "$step" $(( width - span ))); do
    out="  "
    for ((i = 0; i < width; i++)); do
      if [ "$i" -ge "$pos" ] && [ "$i" -lt $(( pos + span )) ]; then c=$G; else c=$G6; fi
      out+="${c}─"
    done
    # lift onto the rule row once, then repaint it in place
    if [ "$first" -eq 1 ]; then printf '\033[1A'; first=0; fi
    printf '\r%s%s\033[0m' "$out" "$R"
    sleep 0.014
  done
  printf '\r  '
  local idx c2
  for ((i = 0; i < width; i++)); do
    idx=$(( i * 6 / width ))
    case $idx in
      0|1) c2=$G ;; 2) c2=$G2 ;; 3) c2=$G3 ;; 4) c2=$G4 ;; 5) c2=$G5 ;; *) c2=$G6 ;;
    esac
    printf '%s─' "$c2"
  done
  printf '%s\n' "$R"
}

pulse() {  # the two ▌ brackets breathe before the word decrypts
  [ "$anim" -eq 1 ] || return 0
  local i c
  for i in 1 2; do
    case $i in 1|3) c=$G ;; 2) c=$D ;; esac
    printf '\r  %s%s▌%s   %s%s▌%s' "$c" "$B" "$R" "$c" "$B" "$R"; sleep 0.09
  done
  printf '\r%*s\r' $(( cols )) ' '
}

blink() {  # two soft cursor blinks after the banner
  [ "$anim" -eq 1 ] || return 0
  local i
  for i in 1; do
    printf '  %s▊%s' "$G" "$R"; sleep 0.10
    printf '\r   \r'; sleep 0.06
  done
}

hint_typed() {  # the shortcut hint writes itself
  if [ "$anim" -eq 0 ] || [ "$cols" -lt 40 ]; then
    printf '%s\n' "  ${D}type ${R}${G}alias${R}${D} for shortcuts · ${R}${G}matrix${R}${D} for rain${R}"
    return 0
  fi
  printf '  '
  tw "type " "$D"
  tw "alias" "$G"
  tw " for shortcuts · " "$D"
  tw "matrix" "$G"
  tw " for rain" "$D"
  printf '\n'
}

line_banner() {
  local sub="  android terminal"
  [ "$cols" -lt 33 ] && sub="  android"

  if [ "$anim" -eq 1 ]; then
    pulse
    decrypt TERMUX 6
    glitch
  else
    printf '  %s%s▌%s %s%s%s %s%s▌%s' "$G" "$B" "$R" "$G$B" "TERMUX" "$R" "$G" "$B" "$R"
  fi
  tw "$sub" "$D"
  printf '\n'

  # keep one spare column so the rule can never wrap the terminal
  printf '  '
  rule $(( cols - 4 ))
  sweep $(( cols - 4 ))
}

art_banner() {
  local rows=(
    "${G}████████╗  ███████╗  ██████╗   ███╗   ███╗  ██╗   ██╗  ██╗  ██╗${R}"
    "${G2}╚══██╔══╝  ██╔════╝  ██╔══██╗  ████╗ ████║  ██║   ██║  ╚██╗██╔╝${R}"
    "${G3}   ██║     █████╗    ██████╔╝  ██╔████╔██║  ██║   ██║   ╚███╔╝ ${R}"
    "${G4}   ██║     ██╔══╝    ██╔══██╗  ██║╚██╔╝██║  ██║   ██║   ██╔██╗ ${R}"
    "${G5}   ██║     ███████╗  ██║  ██║  ██║ ╚═╝ ██║  ╚██████╔╝  ██╔╝ ██╗${R}"
    "${G6}   ╚═╝     ╚══════╝  ╚═╝  ╚═╝  ╚═╝     ╚═╝   ╚═════╝   ╚═╝  ╚═╝${R}"
  )
  local r
  for r in "${rows[@]}"; do
    printf '%s\n' "$r"
    [ "$anim" -eq 1 ] && sleep 0.035
  done
}

printf '\n'

if [ "$STYLE" = "line" ] || { [ "$STYLE" = "auto" ] && [ "$cols" -lt 66 ]; }; then
  line_banner
else
  art_banner
fi

printf '\n'
printf '%s\n' "  ${B}${G}${device}${R} ${D}·${R} ${D}Android ${rel}${R}"; pause 0.05
[ -n "$kernel" ] && { printf '%s\n' "  ${D}kernel  ${R}${C}${kernel}${R}"; pause 0.05; }
[ -n "$uptime_txt" ] && { printf '%s\n' "  ${D}uptime  ${R}${C}${uptime_txt}${R}${storage:+ ${D}·${R} ${C}${storage}${R}}"; pause 0.05; }
[ -n "$wifi" ] && { printf '%s\n' "  ${D}ip      ${R}${C}${wifi}${R}"; pause 0.05; }
blink
hint_typed

printf '\n'

MOTD_EOF
  sed -e "s/__TB_STYLE__/$BANNER_STYLE/" -e "s/__TB_ANIM__/$DO_ANIM/" "$MOTD_SH" > "$MOTD_SH.tmp" \
    && mv "$MOTD_SH.tmp" "$MOTD_SH"
  chmod 755 "$MOTD_SH"
  ok "banner: $MOTD_SH"
}

write_colors() {
  step "Writing terminal colors"
  if [ "$DO_COLORS" -eq 0 ]; then
    info "skipped (--keep-colors)"
    return 0
  fi
  backup_file "$COLORS" colors
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would write $COLORS"
    return 0
  fi
  mkdir -p "$TERMUX_DIR"
  cat > "$COLORS" <<'COLORS_EOF'
# termux-beautify — modern hacker theme
background = #05080a
foreground = #c8ffdc
cursor = #00ff9c

color0  = #05080a
color1  = #ff5f56
color2  = #00ff9c
color3  = #ffd866
color4  = #00c8ff
color5  = #b48cff
color6  = #5cffd1
color7  = #c8ffdc
color8  = #16241f
color9  = #ff7b72
color10 = #7dffb0
color11 = #ffe38a
color12 = #63d8ff
color13 = #d0b3ff
color14 = #9dffe0
color15 = #f2fff8
COLORS_EOF
  ok "colors: $COLORS"
}

write_props() {
  step "Tuning Termux app properties"
  strip_block "$PROPS"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would append the extra-keys block to $PROPS"
    return 0
  fi
  mkdir -p "$TERMUX_DIR"
  cat >> "$PROPS" <<'PROPS_EOF'

# >>> termux-beautify >>>
extra-keys = [['ESC','/','-','HOME','UP','END','PGUP'],['TAB','CTRL','ALT','LEFT','DOWN','RIGHT','PGDN']]
cursor-blink-rate = 600
terminal-margin-horizontal = 2
# <<< termux-beautify <<<
PROPS_EOF
  ok "extra keys + cursor settings"
}

write_bashrc() {
  step "Installing prompt and aliases"
  strip_block "$BASHRC"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would append the login block to $BASHRC"
    return 0
  fi

  touch "$BASHRC"
  {
    cat <<BASHRC_EOF

$MB
# hacker theme — prompt, aliases, git branch
export TERMUX_BEAUTIFY="$TB_VERSION"
export TB_DEVICE="$TB_DEVICE"
export TB_USER="termux"

# ── history ──────────────────────────────────────────────────
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth
HISTTIMEFORMAT='%F %T '
shopt -s histappend checkwinsize 2>/dev/null

# ── readline ─────────────────────────────────────────────────
bind '"\e[A": history-search-backward' 2>/dev/null
bind '"\e[B": history-search-forward' 2>/dev/null
bind 'set show-all-if-ambiguous on' 2>/dev/null
bind 'set completion-ignore-case on' 2>/dev/null

# ── colors ───────────────────────────────────────────────────
export CLICOLOR=1
export LS_COLORS='di=38;2;0;255;156:ln=38;2;0;200;255:so=38;2;180;140;255:pi=38;2;255;216;102:ex=38;2;125;255;176:bd=38;2;255;216;102:cd=38;2;255;216;102:su=38;2;255;95;86:sg=38;2;255;95;86:tw=38;2;255;216;102:ow=38;2;0;200;255'
export GREP_COLORS='ms=38;2;0;255;156:mc=38;2;0;255;156'
command -v less >/dev/null 2>&1 && export PAGER=less LESS='-R -F -X'

# ── aliases ──────────────────────────────────────────────────
alias ls='ls --color=auto'
alias l='ls -CF --color=auto'
alias ll='ls -lhA --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias h='history'
alias c='clear'
alias cls='clear'
alias update='pkg update -y && pkg upgrade -y'
alias install='pkg install'
alias search='pkg search'
alias df='df -h'
command -v free >/dev/null 2>&1 && alias free='free -h'
[ -x "\$PREFIX/bin/nano" ] && export EDITOR=nano

# ── prompt pieces ────────────────────────────────────────────
__tb_git() {
  command -v git >/dev/null 2>&1 || return 0
  local branch
  branch="\$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 0
  [ -n "\$branch" ] || return 0
  local mark=''
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    mark='\033[38;2;255;216;102m*\033[0m'
  fi
  printf '\033[38;2;0;255;156m─[\033[0m\033[38;2;0;200;255m%s%b\033[0m\033[38;2;0;255;156m]\033[0m' "\$branch" "\$mark"
}

PROMPT_COMMAND='__TB_RC=\$?'
__tb_rc() {
  [ "\${__TB_RC:-0}" -eq 0 ] && return 0
  printf '\033[38;2;255;95;86m─[✘ %d]\033[0m' "\$__TB_RC"
}

PROMPT_DIRTRIM=2
# every dynamic piece sits on line 1 so the editable line keeps a
# fixed width and readline never miscounts the prompt
PS1='\[\033[38;2;0;255;156m\]┌──[\[\033[0m\]\[\033[38;2;200;255;220m\]\${TB_USER}\[\033[38;2;90;120;110m\]@\[\033[0m\]\[\033[38;2;0;255;156m\]\${TB_DEVICE}\[\033[0m\]\[\033[38;2;0;255;156m\]]─[\[\033[0m\]\[\033[38;2;0;200;255m\]\w\[\033[0m\]\[\033[38;2;0;255;156m\]]\[\033[0m\]\$(__tb_git)\$(__tb_rc)\n\[\033[38;2;0;255;156m\]└─╼\[\033[0m\] \[\033[38;2;0;255;156m\]❯\[\033[0m\] '
BASHRC_EOF

    if [ "$DO_MATRIX" -eq 1 ]; then
    cat <<MATRIX_EOF

# ── matrix rain ──────────────────────────────────────────────
matrix() {
  local cols="\${1:-\$(tput cols 2>/dev/null || echo 80)}"
  printf '\033[?25l'
  trap 'printf "\033[0m\033[?25h\n"; return 0' INT TERM
  awk -v cols="\$cols" 'BEGIN{
    srand();
    chars="01ABCDEFGHIJKLMNOPQRSTUVWXYZ#\$%&*+=<>/";
    n=split(chars,c,"");
    g="\033[38;2;0;255;156m"; d="\033[38;2;0;130;90m"; r="\033[0m";
    while (1) {
      line="";
      for (i=0;i<cols;i++) {
        ch=c[int(rand()*n)+1];
        if (rand()<0.15) line=line g ch; else line=line d ch;
      }
      printf "%s%s\n", line, r;
      fflush();
    }
  }'
  printf '\033[?25h'
}
MATRIX_EOF
    fi

    cat <<TAIL_EOF
$ME
TAIL_EOF
  } >> "$BASHRC"
  ok "prompt installed in $BASHRC"
}

reload_app() {
  step "Applying settings"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would run termux-reload-settings"
    return 0
  fi
  if command -v termux-reload-settings >/dev/null 2>&1; then
    if run "termux-reload-settings" termux-reload-settings; then
      ok "Termux settings reloaded"
    fi
  else
    warn "termux-reload-settings not found — restart Termux to apply."
  fi
}

done_screen() {
  printf '\n'
  printf '%b╭──────────────────────────────────────────────╮%b\n' "$GRN" "$RST"
  printf '%b│%b  %bREADY%b                                       %b│%b\n' "$GRN" "$RST" "$BOLD" "$RST" "$GRN" "$RST"
  printf '%b╰──────────────────────────────────────────────╯%b\n' "$GRN" "$RST"
  printf '\n'
  printf '  %bnew shell%b   %bsource ~/.bashrc%b\n' "$BOLD" "$RST" "$DIM" "$RST"
  printf '  %bfull look%b   %brestart Termux (opens a new session)%b\n' "$BOLD" "$RST" "$DIM" "$RST"
  printf '  %bpreview%b     %bbash ~/.termux/motd.sh%b\n' "$BOLD" "$RST" "$DIM" "$RST"
  printf '  %beaster egg%b   %bmatrix%b\n' "$BOLD" "$RST" "$DIM" "$RST"
  printf '  %bbackups%b     %b%s%b\n' "$BOLD" "$RST" "$DIM" "$BACKUP_DIR" "$RST"
  printf '  %bundo%b        %bcurl -fsSL %s/uninstall.sh | bash%b\n' "$BOLD" "$RST" "$DIM" "${REPO_RAW:-https://raw.githubusercontent.com/JackRipper-ID/termux-beautify/main}" "$RST"
  printf '\n'
}

uninstall_all() {
  banner
  step "Reverting"

  local motd_state colors_state
  motd_state="$(state_value motd_sh)"
  colors_state="$(state_value colors)"

  if [ -f "$BACKUP_DIR/motd.sh" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      info "would restore your previous motd.sh"
    else
      cp -a "$BACKUP_DIR/motd.sh" "$MOTD_SH"
      chmod 755 "$MOTD_SH"
      ok "previous motd.sh restored"
    fi
  elif [ "$motd_state" = "absent" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      info "would remove motd.sh (the default banner returns)"
    else
      rm -f "$MOTD_SH"
      ok "custom banner removed (default Termux banner is back)"
    fi
  else
    if [ "$DRY_RUN" -eq 1 ]; then
      info "would remove motd.sh"
    else
      rm -f "$MOTD_SH"
      ok "custom banner removed"
    fi
  fi

  if [ "$colors_state" = "absent" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      info "would remove colors.properties"
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

  strip_block "$PROPS"
  strip_block "$BASHRC"
  [ "$DRY_RUN" -eq 1 ] || ok "shell config cleaned"

  if [ "$DRY_RUN" -eq 0 ] && command -v termux-reload-settings >/dev/null 2>&1; then
    termux-reload-settings >/dev/null 2>&1 || true
    ok "settings reloaded"
  fi

  printf '\n'
  info "backups kept in $BACKUP_DIR"
  printf '\n'
}

usage() {
  cat <<EOF
Termux Beautify v$TB_VERSION — modern hacker theme

Usage: install.sh [options]

Options:
  -h, --help            show this help
      --no-packages     skip pkg install
      --no-banner       keep the login banner empty
      --no-anim         no typing/fade animation on login
      --style <s>       banner style: auto (default), line, or art
      --no-matrix       do not add the matrix function
      --keep-colors     keep your current colors.properties
      --uninstall       revert everything
      --dry-run         show what would change, touch nothing

Examples:
  curl -fsSL ${REPO_RAW:-https://raw.githubusercontent.com/JackRipper-ID/termux-beautify/main}/install.sh | bash
  bash install.sh --dry-run
  bash install.sh --uninstall

Styles:
  auto   line banner on phones, block art on wide screens
  line   always the one-line ▌ TERMUX ▌ banner
  art    always the 6-row block art
EOF
}

main() {
  local do_uninstall=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --no-packages) DO_PACKAGES=0; shift ;;
      --no-banner) DO_BANNER=0; shift ;;
      --no-matrix) DO_MATRIX=0; shift ;;
      --no-anim) DO_ANIM=0; shift ;;
      --style) BANNER_STYLE="${2:-auto}"; shift 2 ;;
      --style=*) BANNER_STYLE="${1#*=}"; shift ;;
      --keep-colors) DO_COLORS=0; shift ;;
      --uninstall) do_uninstall=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      *) warn "Unknown option: $1"; shift ;;
    esac
  done

  case "$BANNER_STYLE" in
    auto|line|art) ;;
    *) BANNER_STYLE="auto" ;;
  esac

  banner

  if [ "$do_uninstall" -eq 1 ]; then
    uninstall_all
    exit 0
  fi

  check_env
  init_backup_state
  [ "$DO_PACKAGES" -eq 1 ] && install_packages
  write_banner
  write_colors
  write_props
  write_bashrc
  reload_app
  done_screen
}

main "$@"
