VERSION="3.5"
shopt -u patsub_replacement 2>/dev/null   # keep "&" literal in ${var//x/y}
BASE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
ANDROID_JAR="$PREFIX/share/aapt/android.jar"
CONF="$BASE/config.conf"
LOG="$BASE/build.log"
HIST="$BASE/history.log"
CACHE="$BASE/.cache"
PROFILES="$BASE/profiles"
KSPASS_FILE="$BASE/.ks_pass"
KS="$BASE/cio.keystore"
STEPLOG="$BASE/steps.log"
KEYS="$BASE/.keys"
LINKS="$BASE/links.log"

# ───────────── colors ─────────────
R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; M=$'\e[35m'
B=$'\e[1m'; D=$'\e[2m'; N=$'\e[0m'

# ───────────── defaults ─────────────
URL="https://example.com"
APP_NAME="My Web App"
PACKAGE="com.cioid.webapp"
PROJECT="MyWebApp"
ICON=""
COLOR="#1565C0"
SPLASH_TYPE="color"       # none | color | image | video
SPLASH_VALUE="#FFFFFF"    # hex color, file path or link
VERSION_NAME="1.0"
VERSION_CODE="1"
FULLSCREEN=0
ORIENT="auto"             # auto | portrait | landscape
KEEP_ON=0
ALLOW_DOWNLOAD=1
ALLOW_UPLOAD=1
SPLASH_MS=1500
SPLASH_FADE=1
OPTIMIZE=1
SHOW_CMD=1
KEEP_SRC=0
LAST_OUT=""
ASSUME_YES=0
PROGRESS_BAR=1
ALLOW_ZOOM=0
LOCK_DOMAIN=0
EXIT_CONFIRM=1
DESKTOP=0
USER_AGENT=""
NAME_WITH_VER=0
NOTIFY=1
LIVE=0
THEME="cyan"
WEB_PERMS=0
SECURE_MODE=0
CDN_TTL="24h"       # 1h | 12h | 24h | 72h
CDN_HOST="auto"      # auto | litterbox | 0x0 | tmpfiles
CDN_AUTO=0
BANNER_STYLE="auto"   # auto | big | medium | mini | off
BANNER_ANIM=1
BUILD_ANIM=1         # animated build progress
AUTO_TOOLS=1         # auto-install missing tools on first use
WZ_DEPTH=2           # webzip crawl depth 1-3
WZ_MAXMB=50          # webzip size cap (MB)
# runtime-only flags (not saved)
SOC_ONLY=""; SOC_SAVE=0; SOC_JSON=0; WZ_WAYBACK=0; WZ_OUT=""; WZ_ALLOW_LOCAL="${WZ_ALLOW_LOCAL:-0}"; LAST_ZIP=""; JAR_QUIET=0; SPIN_LOG=""; CUR_PID=""; BAR_W=16
BANNER_SHOWN=0; WAKE=0; AUTO_UPLOAD=0; ARG2=""; DRY=0; BATCH=0; AUTO_SHARE=0; AUTO_INSTALL=0; REFRESH=0
SUB=""; ARG=""; FIX_FLAG=""

CONFIG_VARS=(URL APP_NAME PACKAGE PROJECT ICON COLOR SPLASH_TYPE SPLASH_VALUE
  VERSION_NAME VERSION_CODE FULLSCREEN ORIENT KEEP_ON ALLOW_DOWNLOAD ALLOW_UPLOAD
  SPLASH_MS SPLASH_FADE OPTIMIZE SHOW_CMD KEEP_SRC LAST_OUT
  PROGRESS_BAR ALLOW_ZOOM LOCK_DOMAIN EXIT_CONFIRM DESKTOP USER_AGENT NAME_WITH_VER NOTIFY LIVE THEME WEB_PERMS SECURE_MODE CDN_TTL CDN_HOST CDN_AUTO BANNER_STYLE BANNER_ANIM BUILD_ANIM AUTO_TOOLS WZ_DEPTH WZ_MAXMB)

save_config() { : > "$CONF"; local v; for v in "${CONFIG_VARS[@]}"; do printf '%s=%q\n' "$v" "${!v}" >> "$CONF"; done; }
load_config() { [ -f "$CONF" ] && source "$CONF"; return 0; }

USE_COLOR=1; WHITE=""; GRAD=(51 45 39 33 27 21)
apply_theme() {
  case "$THEME" in
    green)   C=$'\e[32m'; M=$'\e[33m'; GRAD=(157 121 84 48 41 35) ;;
    magenta) C=$'\e[35m'; M=$'\e[36m'; GRAD=(219 213 207 171 135 99) ;;
    yellow)  C=$'\e[33m'; M=$'\e[35m'; GRAD=(226 220 214 208 202 196) ;;
    blue)    C=$'\e[34m'; M=$'\e[36m'; GRAD=(117 81 75 69 63 57) ;;
    mono)    C="";         M="";        GRAD=(255 252 249 246 243 240) ;;
    *)       THEME="cyan"; C=$'\e[36m'; M=$'\e[35m'; GRAD=(87 51 45 39 33 27) ;;
  esac
  USE_COLOR=1; WHITE=$'\e[1;97m'
  if [ -n "$NO_COLOR" ] || [ ! -t 1 ] || [ "$TERM" = dumb ]; then
    USE_COLOR=0; WHITE=""; R=""; G=""; Y=""; C=""; M=""; B=""; D=""; N=""
  fi
}

# ───────────── ui helpers ─────────────
W=46
repeat_str() { local i out=""; for ((i=0; i<$2; i++)); do out+="$1"; done; printf '%s' "$out"; }
hr()   { printf '%s%s%s\n' "$D" "$(repeat_str '─' "$W")" "$N"; }
ok()   { echo "  ${G}✔${N} $*"; }
warn() { echo "  ${Y}!${N} $*"; }
bad()  { echo "  ${R}✘${N} $*"; }
info() { echo "  ${C}»${N} $*"; }
pause(){ [ -t 0 ] && read -r -p "${D}Press Enter...${N}" _; }
onoff(){ [ "$1" = 1 ] && echo "${G}ON ${N}" || echo "${R}OFF${N}"; }

status_chip() {
  local c miss=0 n
  for c in java ecj aapt2 apksigner zip; do command -v "$c" >/dev/null 2>&1 || miss=1; done
  { command -v d8 >/dev/null 2>&1 || command -v dx >/dev/null 2>&1; } || miss=1
  [ -f "$ANDROID_JAR" ] || miss=1
  n=0; [ -f "$HIST" ] && n="$(wc -l < "$HIST" | tr -d ' ')"
  if [ "$miss" = 0 ]; then printf '%s● Ready%s' "$G" "$N"; else printf '%s○ Setup needed%s %s(run: doctor --fix)%s' "$R" "$N" "$D" "$N"; fi
  printf '  %s│ theme: %s │ builds: %s%s' "$D" "$THEME" "$n" "$N"
}

# ───────────── banner / logo ─────────────
BIG_CIO=(
  ' ██████╗██╗ ██████╗ '
  '██╔════╝██║██╔═══██╗'
  '██║     ██║██║   ██║'
  '██║     ██║██║   ██║'
  '╚██████╗██║╚██████╔╝'
  ' ╚═════╝╚═╝ ╚═════╝ '
)
BIG_WEB=(
  '██╗    ██╗███████╗██████╗ ██████╗  █████╗ ██████╗ ██╗  ██╗'
  '██║    ██║██╔════╝██╔══██╗╚════██╗██╔══██╗██╔══██╗██║ ██╔╝'
  '██║ █╗ ██║█████╗  ██████╔╝ █████╔╝███████║██████╔╝█████╔╝ '
  '██║███╗██║██╔══╝  ██╔══██╗ ╚═══██╗██╔══██║██╔═══╝ ██╔═██╗ '
  '╚███╔███╔╝███████╗██████╔╝██████╔╝██║  ██║██║     ██║  ██╗'
  ' ╚══╝╚══╝ ╚══════╝╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝'
)
MED_CIO=(
  '╔═╗ ╦ ╔═╗'
  '║   ║ ║ ║'
  '╚═╝ ╩ ╚═╝'
)
MED_WEB=(
  '╦ ╦ ╔═╗ ╔╗  ╔═╗ ╔═╗ ╔═╗ ╦╔═'
  '║║║ ║╣  ╠╩╗  ═╣ ╠═╣ ╠═╝ ╠╩╗'
  '╚╩╝ ╚═╝ ╚═╝ ╚═╝ ╩ ╩ ╩   ╩ ╩'
)

term_cols()  { local c="${COLUMNS:-}"; [ -n "$c" ] || c="$(tput cols 2>/dev/null)"; [[ "$c" =~ ^[0-9]+$ ]] || c=50; echo "$c"; }
term_rows()  { local r="${LINES:-}";   [ -n "$r" ] || r="$(tput lines 2>/dev/null)"; [[ "$r" =~ ^[0-9]+$ ]] || r=24; echo "$r"; }
fg()         { if [ "$USE_COLOR" = 1 ]; then printf '\e[38;5;%sm' "$1"; fi; }

grad_rule() { # rainbow-ish rule in the theme gradient
  local cols w seg rem k len out=""
  cols="$(term_cols)"; w=$(( cols > 62 ? 60 : cols - 3 )); [ "$w" -lt 18 ] && w=18
  seg=$(( w / 6 )); rem=$(( w - seg * 6 ))
  for k in 0 1 2 3 4 5; do
    len=$seg; [ "$k" -eq 5 ] && len=$(( seg + rem ))
    out+="$(fg "${GRAD[k]}")$(repeat_str '━' "$len")"
  done
  printf ' %s%s\n' "$out" "$N"
}

logo_rows() { # logo_rows big|medium : white "CIO" + gradient "WEB3APK"
  local style="$1" i n gi a b pause=0
  if [ "$BANNER_ANIM" = 1 ] && [ "$BANNER_SHOWN" != 1 ] && [ -t 1 ]; then pause=1; fi
  if [ "$style" = big ]; then n=6; else n=3; fi
  for ((i=0; i<n; i++)); do
    if [ "$style" = big ]; then a="${BIG_CIO[i]}"; b="${BIG_WEB[i]}"; gi=$i
    else a="${MED_CIO[i]}"; b="${MED_WEB[i]}"; gi=$(( i * 2 + 1 )); fi
    printf ' %s%s%s %s%s%s\n' "$WHITE" "$a" "$N" "$(fg "${GRAD[gi]}")" "$b" "$N"
    if [ "$pause" = 1 ]; then sleep 0.05; fi
  done
}

is_ready() {
  local c
  for c in java ecj aapt2 apksigner zip; do command -v "$c" >/dev/null 2>&1 || return 1; done
  { command -v d8 >/dev/null 2>&1 || command -v dx >/dev/null 2>&1; } || return 1
  [ -f "$ANDROID_JAR" ]
}

info_bar() { # tidy rows of facts (ASCII padding only, so columns always line up)
  local a n=0 sym st cols
  a="$(fg "${GRAD[1]}")"; cols="$(term_cols)"
  [ -f "$HIST" ] && n="$(wc -l < "$HIST" | tr -d ' ')"
  if is_ready; then sym="${G}●${N}"; st="Ready"; else sym="${R}○${N}"; st="Setup"; fi
  if [ "$cols" -lt 48 ]; then   # narrow phone screen: 3 short rows
    printf ' %s▌%s %-9s %s▌%s Dev Cio-ID\n' "$a" "$N" "v$VERSION" "$a" "$N"
    printf ' %s▌%s %s %-6s %s▌%s builds %s\n' "$a" "$N" "$sym" "$st" "$a" "$N" "$n"
    printf ' %s▌%s %-9s %s▌%s CDN %s/%s\n' "$a" "$N" "$THEME" "$a" "$N" "$CDN_HOST" "$CDN_TTL"
  else
    printf ' %s▌%s %-10s %s▌%s %-14s %s▌%s theme %s%s%s\n' "$a" "$N" "v$VERSION" "$a" "$N" "Dev Cio-ID" "$a" "$N" "$C" "$THEME" "$N"
    printf ' %s▌%s %s %-8s %s▌%s %-14s %s▌%s CDN %s%s/%s%s\n' "$a" "$N" "$sym" "$st" "$a" "$N" "builds $n" "$a" "$N" "$C" "$CDN_HOST" "$CDN_TTL" "$N"
  fi
  if ! is_ready; then printf ' %s  tools install on first use (or: cioweb3apk setup)%s\n' "$D" "$N"; fi
}

banner_full() { # header of the main menu / preview
  local style="${1:-$BANNER_STYLE}" cols rows
  if [ -t 1 ] && [ "$BATCH" != 1 ]; then clear; fi
  cols="$(term_cols)"; rows="$(term_rows)"
  if [ "$style" = auto ]; then
    if [ "$cols" -ge 50 ]; then style=card; else style=mini; fi
  fi
  if [ "$style" = card ] && [ "$cols" -lt 49 ]; then style=mini; fi
  case "$style" in
    card) banner_card ;;
    big|medium)
      echo; logo_rows "$style"
      printf ' %s✦%s %sWebsite → APK Builder%s  %s·  Termux Edition%s\n' "$(fg "${GRAD[0]}")" "$N" "$B" "$N" "$D" "$N"
      grad_rule; info_bar; grad_rule ;;
    mini) banner_compact_line; grad_rule; info_bar ;;
    *)    banner_compact_line; grad_rule ;;
  esac
  BANNER_SHOWN=1
}

tab() { # tab BG FG TEXT
  if [ "$USE_COLOR" = 1 ]; then printf '\e[48;5;%sm\e[38;5;%sm %s \e[0m' "$1" "$2" "$3"
  else printf '[%s]' "$3"; fi
}

CARD_IW=45
card_row() { # card_row SIDE_COLOR LEFT LEFT_VIS RIGHT RIGHT_VIS   (VIS = visible columns)
  local sc="$1" left="$2" lv=$3 right="$4" rv=$5 pad
  pad=$(( CARD_IW - lv - rv )); [ "$pad" -lt 0 ] && pad=0
  printf ' %s│%s%s%*s%s%s│%s\n' "$sc" "$N" "$left" "$pad" "" "$right" "$sc" "$N"
}
card_cell() { printf ' %s●%s %-12.12s' "$1" "$N" "$2"; }   # always 15 columns

banner_card() { # framed card with a per-letter gradient title
  local anim=0 i ch n=0 rv pad s0 s1 s2 s3 s4 s5 dot st opt letters="CIOWEB3APK"
  if [ "$BANNER_ANIM" = 1 ] && [ "$BANNER_SHOWN" != 1 ] && anim_on; then anim=1; fi
  if [ -f "$HIST" ]; then n="$(wc -l < "$HIST" | tr -d ' ')"; fi
  s0="$(fg "${GRAD[0]}")"; s1="$(fg "${GRAD[1]}")"; s2="$(fg "${GRAD[2]}")"
  s3="$(fg "${GRAD[3]}")"; s4="$(fg "${GRAD[4]}")"; s5="$(fg "${GRAD[5]}")"
  if is_ready; then dot="$G"; st="Ready"; else dot="$R"; st="Setup"; fi
  if [ "$OPTIMIZE" = 1 ]; then opt="opt ON"; else opt="opt OFF"; fi
  printf ' %s╭%s╮%s\n' "$s0" "$(repeat_str '─' "$CARD_IW")" "$N"
  if [ "$anim" = 1 ]; then sleep 0.05; fi
  printf ' %s│%s %s▟█▙%s  ' "$s1" "$N" "$s1" "$N"
  for ((i=0; i<10; i++)); do
    ch="${letters:i:1}"
    printf '%s%s%s%s' "$B" "$(fg "${GRAD[i*5/9]}")" "$ch" "$N"
    if [ "$i" -lt 9 ]; then printf ' '; fi
    if [ "$anim" = 1 ]; then sleep 0.03; fi
  done
  rv=$(( ${#VERSION} + 2 )); pad=$(( CARD_IW - 25 - rv ))
  printf '%*s%sv%s %s%s│%s\n' "$pad" "" "$D" "$VERSION" "$N" "$s1" "$N"
  if [ "$anim" = 1 ]; then sleep 0.05; fi
  card_row "$s2" " ${s2}▜█▛${N}  ${B}Website${N} ${s1}→${N} ${B}APK${N} ${D}·${N} Social ${D}·${N} WebZip" 37 "" 0
  printf ' %s├%s┤%s\n' "$s3" "$(repeat_str '─' "$CARD_IW")" "$N"
  if [ "$anim" = 1 ]; then sleep 0.05; fi
  card_row "$s4" "$(card_cell "$dot" "$st")$(card_cell "${s2}" "builds $n")$(card_cell "${s3}" "CDN $CDN_TTL")" 45 "" 0
  card_row "$s4" "$(card_cell "${s1}" "dev Cio-ID")$(card_cell "${s2}" "theme $THEME")$(card_cell "${s3}" "$opt")" 45 "" 0
  printf ' %s╰%s╯%s\n' "$s5" "$(repeat_str '─' "$CARD_IW")" "$N"
  if ! is_ready; then printf ' %s tools install themselves on first use (or: cioweb3apk setup)%s\n' "$D" "$N"; fi
}
banner_compact_line() { # coloured "tabs"
  local st
  if is_ready; then st="$(tab 28 255 '● Ready')"; else st="$(tab 124 255 '○ Setup')"; fi
  printf ' %s %s %s %s\n' "$(tab "${GRAD[5]}" 255 '◆ CioWeb3Apk')" "$(tab "${GRAD[3]}" 16 "v$VERSION")" "$st" "$(tab 238 250 "$THEME")"
}

banner() { # compact header used on every sub-screen
  if [ -t 1 ] && [ "$BATCH" != 1 ]; then clear; fi
  banner_compact_line
  grad_rule
}

bar() { # bar n total
  local n=$1 t=$2 w=20 f
  f=$(( n * w / t ))
  printf '[%s%s] %d/%d' "$(repeat_str '█' "$f")" "$(repeat_str '░' $((w-f)))" "$n" "$t"
}

ask() { # ask "Label" VAR
  local cur="${!2}" v
  read -r -p "${Y}$1${N} ${D}[${cur}]${N}: " v
  [ -n "$v" ] && printf -v "$2" '%s' "$v"
  return 0
}

ask_yn() { # ask_yn "Question" -> 0 if yes
  [ "$ASSUME_YES" = 1 ] && return 0
  [ -t 0 ] || return 1
  local a; read -r -p "${Y}$1${N} ${D}(y/n)${N}: " a
  [ "$a" = "y" ] || [ "$a" = "Y" ]
}

show_config() {
  echo "${B} Project${N}"
  printf "  %-11s %s\n" "URL"      "$URL"
  printf "  %-11s %s\n" "App Name" "$APP_NAME"
  printf "  %-11s %s\n" "Package"  "$PACKAGE"
  printf "  %-11s %s\n" "Project"  "$PROJECT  (v$VERSION_NAME / $VERSION_CODE)"
  printf "  %-11s %s\n" "Icon"     "${ICON:-default (generated)}"
  printf "  %-11s %s\n" "Color"    "$COLOR"
  printf "  %-11s %s\n" "Loading"  "$SPLASH_TYPE $( [ "$SPLASH_TYPE" = none ] || echo "($SPLASH_VALUE)")"
  echo "${B} Features${N}"
  printf "  Fullscreen %s Download %s Upload %s KeepOn %s\n" "$(onoff $FULLSCREEN)" "$(onoff $ALLOW_DOWNLOAD)" "$(onoff $ALLOW_UPLOAD)" "$(onoff $KEEP_ON)"
  printf "  Progress %s Zoom %s DomainLock %s Exit2x %s\n" "$(onoff $PROGRESS_BAR)" "$(onoff $ALLOW_ZOOM)" "$(onoff $LOCK_DOMAIN)" "$(onoff $EXIT_CONFIRM)"
  printf "  Orient ${C}%s${N}  Desktop %s  Optimizer %s\n" "$ORIENT" "$(onoff $DESKTOP)" "$(onoff $OPTIMIZE)"
  printf "  WebPerms %s  Secure %s  CDN %s%s%s/%s\n" "$(onoff $WEB_PERMS)" "$(onoff $SECURE_MODE)" "$C" "$CDN_HOST" "$N" "$CDN_TTL"
  if [ -n "$LAST_OUT" ] && [ -f "$LAST_OUT" ]; then
    printf "  ${D}Last build: %s (%s)${N}\n" "$(basename "$LAST_OUT")" "$(fmt_size "$LAST_OUT")"
  fi
}

equiv_cmd() { # the CLI command that equals the current config
  local c="cioweb3apk build --url '$URL' --name '$APP_NAME' --pkg $PACKAGE --project $PROJECT --color $COLOR"
  [ -n "$ICON" ] && c+=" --icon '$ICON'"
  if [ "$SPLASH_TYPE" = none ]; then c+=" --splash none"; else c+=" --splash $SPLASH_TYPE:$SPLASH_VALUE"; fi
  c+=" --version $VERSION_NAME --code $VERSION_CODE --orient $ORIENT"
  [ "$FULLSCREEN" = 1 ] && c+=" --fullscreen"
  [ "$KEEP_ON" = 1 ] && c+=" --keep-on"
  [ "$LOCK_DOMAIN" = 1 ] && c+=" --lock-domain"
  [ "$ALLOW_ZOOM" = 1 ] && c+=" --zoom"
  [ "$DESKTOP" = 1 ] && c+=" --desktop"
  [ "$WEB_PERMS" = 1 ] && c+=" --web-perms"
  [ "$SECURE_MODE" = 1 ] && c+=" --secure"
  [ "$CDN_AUTO" = 1 ] && c+=" --upload --ttl $CDN_TTL"
  [ "$OPTIMIZE" = 0 ] && c+=" --no-opt"
  printf '%s' "$c"
}

# ───────────── validation / escaping ─────────────
JAVA_KW=" abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public return short static strictfp super switch synchronized this throw throws transient try void volatile while true false null "

norm_color() { # "abc" "#abc" "1565c0" "#1565C0" -> "#RRGGBB"; anything else unchanged
  local c="${1^^}"; c="${c#\#}"
  if [[ "$c" =~ ^[0-9A-F]{3}$ ]]; then c="${c:0:1}${c:0:1}${c:1:1}${c:1:1}${c:2:1}${c:2:1}"; fi
  if [[ "$c" =~ ^([0-9A-F]{6}|[0-9A-F]{8})$ ]]; then printf '#%s' "$c"; else printf '%s' "$1"; fi
}
darken() { # darken "#RRGGBB" [percent]
  local c="${1#\#}" p="${2:-15}" r g b
  r=$((16#${c:0:2})); g=$((16#${c:2:2})); b=$((16#${c:4:2}))
  printf '#%02X%02X%02X' $((r*(100-p)/100)) $((g*(100-p)/100)) $((b*(100-p)/100))
}
valid_color() { [[ "$1" =~ ^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$ ]]; }
valid_pkg() {
  [[ "$1" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]] || return 1
  local seg; for seg in ${1//./ }; do [[ "$JAVA_KW" == *" $seg "* ]] && return 1; done
  return 0
}
is_link() { [[ "$1" =~ ^https?:// ]]; }

jesc() { local v="$1"; v="${v//\\/\\\\}"; v="${v//\"/\\\"}"; printf '%s' "$v"; }
xesc() {
  local v="$1" sq="'" dq='"'
  v="${v//&/&amp;}"; v="${v//</&lt;}"; v="${v//>/&gt;}"
  v="${v//\\/\\\\}"; v="${v//$sq/\\$sq}"; v="${v//$dq/\\$dq}"
  v="${v//@/\\@}"; v="${v//\?/\\?}"
  printf '%s' "$v"
}
b2j() { [ "$1" = 1 ] && echo true || echo false; }

validate_config() { # prints problems, returns 1 on fatal errors
  local e=0 re
  URL="${URL// /}"
  [[ "$URL" =~ ^https?:// ]] || URL="https://$URL"
  re='^https?://[^[:space:]"\\<>]+$'
  [[ "$URL" =~ $re ]] || { bad "Invalid URL: $URL"; e=1; }
  [ -n "$APP_NAME" ] || { bad "App name is empty"; e=1; }
  [ ${#APP_NAME} -gt 30 ] && warn "App name is long (${#APP_NAME} chars), may be cut on launcher"
  valid_pkg "$PACKAGE" || { bad "Invalid package: $PACKAGE (example: com.cioid.app, no Java keywords)"; e=1; }
  PROJECT="$(printf '%s' "$PROJECT" | tr -c 'A-Za-z0-9_-' '_')"; [ -n "$PROJECT" ] || PROJECT="MyWebApp"
  COLOR="$(norm_color "$COLOR")"; valid_color "$COLOR" || { bad "Invalid ColorPrimaryDark: $COLOR (use #RRGGBB)"; e=1; }
  VERSION_NAME="$(printf '%s' "$VERSION_NAME" | tr -c 'A-Za-z0-9._-' '_')"; [ -n "$VERSION_NAME" ] || VERSION_NAME="1.0"
  [[ "$VERSION_CODE" =~ ^[0-9]+$ ]] || { warn "Version code reset to 1"; VERSION_CODE=1; }
  if ! { [[ "$SPLASH_MS" =~ ^[0-9]+$ ]] && [ "$SPLASH_MS" -le 10000 ]; }; then warn "Splash time reset to 1500 ms"; SPLASH_MS=1500; fi
  case "$ORIENT" in auto|portrait|landscape) ;; *) warn "Orientation reset to auto"; ORIENT=auto ;; esac
  case "$SPLASH_TYPE" in
    none) ;;
    color) SPLASH_VALUE="$(norm_color "$SPLASH_VALUE")"; valid_color "$SPLASH_VALUE" || { warn "Splash color invalid, using #FFFFFF"; SPLASH_VALUE="#FFFFFF"; } ;;
    image|video)
      if ! is_link "$SPLASH_VALUE"; then
        local f="${SPLASH_VALUE/#\~/$HOME}"
        [ -f "$f" ] || { bad "Splash file not found: $SPLASH_VALUE"; e=1; }
        if [ -f "$f" ] && [ "$SPLASH_TYPE" = video ] && [ "$(stat -c%s "$f" 2>/dev/null || echo 0)" -gt 15728640 ]; then
          warn "Video is >15MB, APK will be big (use a shorter/smaller video)"
        fi
      fi ;;
    *) warn "Unknown splash type, using color"; SPLASH_TYPE=color; SPLASH_VALUE="#FFFFFF" ;;
  esac
  if [ -n "$ICON" ] && ! is_link "$ICON"; then
    [ -f "${ICON/#\~/$HOME}" ] || { bad "Icon file not found: $ICON"; e=1; }
  fi
  case "$PACKAGE" in
    android.*|com.android.*|com.google.*|com.whatsapp*|com.facebook.*|com.instagram.*)
      warn "Package '$PACKAGE' looks reserved - install may fail or clash with a real app" ;;
  esac
  if have_im; then
    local chk
    if [ -n "$ICON" ] && ! is_link "$ICON"; then
      chk="${ICON/#\~/$HOME}"
      if [ -f "$chk" ] && ! imident -quiet "$chk" >/dev/null 2>&1; then bad "Icon is not a valid image: $ICON"; e=1; fi
    fi
    if [ "$SPLASH_TYPE" = image ] && ! is_link "$SPLASH_VALUE"; then
      chk="${SPLASH_VALUE/#\~/$HOME}"
      if [ -f "$chk" ] && ! imident -quiet "$chk" >/dev/null 2>&1; then bad "Loading image is not a valid image"; e=1; fi
    fi
  fi
  if [ "$SPLASH_TYPE" = video ] && ! is_link "$SPLASH_VALUE"; then
    case "${SPLASH_VALUE,,}" in *.mp4|*.3gp|*.webm|*.mkv) ;; *) warn "Video should be .mp4 (H.264) for best compatibility" ;; esac
  fi
  return $e
}

check_url() {
  is_link "$URL" || return 0
  command -v curl >/dev/null 2>&1 || return 0
  local code
  code="$(curl -o /dev/null -s -L -m 8 -w '%{http_code}' -A 'Mozilla/5.0' "$URL" 2>/dev/null)"
  case "$code" in
    2*|3*) ok "URL reachable (HTTP $code)" ;;
    000)   warn "Cannot reach $URL now (offline/blocked). APK will still build." ;;
    *)     warn "URL answered HTTP $code - check the address" ;;
  esac
  if [[ "$URL" == http://* ]]; then warn "URL uses http:// (traffic is not encrypted)"; fi
  return 0
}

# ───────────── android.jar (Android API stubs) ─────────────
JAR_URLS=(
  "https://github.com/Sable/android-platforms/raw/master/android-28/android.jar"
  "https://github.com/Reginer/aosp-android-jar/raw/main/android-33/android.jar"
)
JAR_ZIP_URL="https://dl.google.com/android/repository/platform-28_r06.zip"
JAR_MISSING=0

find_android_jar() { # look in the usual places (aapt package layout differs between versions)
  local c
  for c in "$BASE/lib/android.jar" "$PREFIX/share/aapt/android.jar" "$PREFIX/share/java/android.jar" \
           "$PREFIX/lib/android.jar" "$PREFIX"/opt/android-sdk/platforms/*/android.jar \
           "$HOME/android-sdk/platforms/*/android.jar" "$HOME/android.jar"; do
    if [ -s "$c" ]; then ANDROID_JAR="$c"; return 0; fi
  done
  c="$(find "$PREFIX/share" "$PREFIX/lib" "$PREFIX/opt" -maxdepth 5 -name android.jar 2>/dev/null | head -n1)"
  if [ -n "$c" ]; then ANDROID_JAR="$c"; return 0; fi
  return 1
}

valid_jar() { # real android.jar = zip, > 5 MB, contains android/app/Activity.class
  local f="$1"
  [ -s "$f" ] || return 1
  [ "$(stat -c%s "$f" 2>/dev/null || echo 0)" -gt 5000000 ] || return 1
  [ "$(head -c2 "$f")" = "PK" ] || return 1
  if command -v unzip >/dev/null 2>&1; then unzip -l "$f" 2>/dev/null | grep -q "android/app/Activity.class" || return 1; fi
  return 0
}

install_jar() { mkdir -p "$BASE/lib" && cp "$1" "$BASE/lib/android.jar" && ANDROID_JAR="$BASE/lib/android.jar"; }

jar_cmd() { # jar [PATH|LINK]  -> find, download or install android.jar
  if [ "$JAR_QUIET" != 1 ]; then banner; echo "${B} android.jar (Android API stubs)${N}"; hr; fi
  mkdir -p "$BASE/lib" "$CACHE"
  local tmp="$CACHE/android.jar.tmp" u src
  if [ -n "$SUB" ]; then
    if is_link "$SUB"; then
      info "Downloading $SUB"
      curl -fL -m 900 -o "$tmp" "$(normalize_link "$SUB")" || { bad "Download failed"; return 1; }
      src="$tmp"
    else
      src="${SUB/#\~/$HOME}"; [ -f "$src" ] || { bad "File not found: $SUB"; return 1; }
    fi
    valid_jar "$src" || { bad "Not a valid android.jar (must be a >5 MB zip containing android/app/Activity.class)"; return 1; }
    install_jar "$src" && ok "Installed: $ANDROID_JAR"; rm -f "$tmp"; return 0
  fi
  if find_android_jar && valid_jar "$ANDROID_JAR" && [ "$REFRESH" != 1 ]; then ok "Already available: $ANDROID_JAR"; return 0; fi
  command -v curl >/dev/null 2>&1 || { bad "curl missing (pkg install curl)"; return 1; }
  for u in "${JAR_URLS[@]}"; do
    info "Downloading android.jar ${D}(one time, ~30-60 MB)${N}"
    if [ "$SHOW_CMD" = 1 ]; then echo "${D}  \$ curl -fL -o android.jar $u${N}"; fi
    if SPIN_LOG="$CACHE/jar.log" spin_run "Downloading android.jar" curl -fL -m 900 -o "$tmp" "$u" && valid_jar "$tmp"; then
      install_jar "$tmp"; rm -f "$tmp"; ok "Installed: $ANDROID_JAR"; return 0
    fi
    warn "That source failed, trying the next one"; rm -f "$tmp"
  done
  if command -v unzip >/dev/null 2>&1; then
    info "Trying the official Android SDK platform package (large download)"
    if [ "$SHOW_CMD" = 1 ]; then echo "${D}  \$ curl -fL -o platform.zip $JAR_ZIP_URL${N}"; fi
    rm -rf "$CACHE/jarx"; mkdir -p "$CACHE/jarx"
    if SPIN_LOG="$CACHE/jar.log" spin_run "Downloading SDK package" curl -fL -m 1800 -o "$CACHE/platform.zip" "$JAR_ZIP_URL" \
       && unzip -j -o "$CACHE/platform.zip" '*/android.jar' -d "$CACHE/jarx" >/dev/null 2>&1 \
       && valid_jar "$CACHE/jarx/android.jar"; then
      install_jar "$CACHE/jarx/android.jar"; rm -rf "$CACHE/platform.zip" "$CACHE/jarx"; ok "Installed: $ANDROID_JAR"; return 0
    fi
    rm -rf "$CACHE/platform.zip" "$CACHE/jarx"
  else
    info "Tip: pkg install unzip  (enables the official-SDK fallback)"
  fi
  bad "Could not download android.jar automatically."
  echo "  Manual: get any android.jar (API 28+), then run:"
  echo "    ${B}cioweb3apk jar /path/to/android.jar${N}   or   ${B}cioweb3apk jar https://direct-link/android.jar${N}"
  return 1
}

# ───────────── tool bootstrap (install once, automatically) ─────────────
tool_group() { # "command[|alt]:package ..."
  case "$1" in
    build)  echo "java:openjdk-17 keytool:openjdk-17 ecj:ecj aapt2:aapt2 aapt:aapt apksigner:apksigner dx|d8:dx zip:zip unzip:unzip magick|convert:imagemagick curl:curl" ;;
    core)   echo "curl:curl" ;;
    social) echo "python3|python:python" ;;
    webzip) echo "wget:wget zip:zip curl:curl python3|python:python" ;;
    share)  echo "termux-share:termux-api" ;;
    serve)  echo "python3|python:python" ;;
    git)    echo "git:git" ;;
    extras) echo "git:git qrencode:qrencode pngquant:pngquant" ;;
  esac
}

have_cmd() { local c; for c in ${1//|/ }; do command -v "$c" >/dev/null 2>&1 && return 0; done; return 1; }

ensure_tools() { # ensure_tools GROUP...  -> installs only what is missing, with animation
  local group pair c p x seen missing=() pkgs=() lg="$BASE/setup.log"
  for group in "$@"; do
    for pair in $(tool_group "$group"); do
      c="${pair%%:*}"; p="${pair##*:}"
      if ! have_cmd "$c"; then
        missing+=("${c%%|*}"); seen=0
        for x in "${pkgs[@]}"; do [ "$x" = "$p" ] && seen=1; done
        [ "$seen" = 0 ] && pkgs+=("$p")
      fi
    done
  done
  [ "${#pkgs[@]}" -eq 0 ] && return 0
  if [ "$AUTO_TOOLS" != 1 ]; then bad "Missing: ${missing[*]}  → pkg install ${pkgs[*]}   ${D}(auto-install is OFF)${N}"; return 1; fi
  if ! command -v pkg >/dev/null 2>&1; then bad "'pkg' not found (not Termux?). Install manually: ${pkgs[*]}"; return 1; fi
  info "Preparing tools ${D}(only the first time)${N}: ${pkgs[*]}"
  : > "$lg"; SPIN_LOG="$lg"
  if ! spin_run "Installing ${pkgs[*]}" env DEBIAN_FRONTEND=noninteractive pkg install -y "${pkgs[@]}"; then
    warn "Install failed - refreshing package lists and retrying"
    spin_run "Updating package lists" env DEBIAN_FRONTEND=noninteractive pkg update -y
    if ! spin_run "Installing ${pkgs[*]} (retry)" env DEBIAN_FRONTEND=noninteractive pkg install -y "${pkgs[@]}"; then
      SPIN_LOG=""
      bad "Could not install: ${pkgs[*]}"; tail -n 6 "$lg" | sed 's/^/    /'
      echo "  ${Y}Tip:${N} run ${B}termux-change-repo${N} to choose a working mirror, then try again."
      return 1
    fi
  fi
  SPIN_LOG=""
  for group in "$@"; do
    for pair in $(tool_group "$group"); do have_cmd "${pair%%:*}" || { bad "Still missing: ${pair%%:*}"; return 1; }; done
  done
  ok "Tools ready: ${pkgs[*]}"
  date '+%F %T' > "$BASE/.tools_ok"
  return 0
}

ensure_jar() {
  find_android_jar
  valid_jar "$ANDROID_JAR" && return 0
  if [ "$AUTO_TOOLS" != 1 ]; then bad "android.jar missing → run: cioweb3apk jar"; return 1; fi
  info "Preparing android.jar ${D}(one time, needed to compile)${N}"
  JAR_QUIET=1 jar_cmd
}

need_deps() { ensure_tools build || return 1; ensure_jar || return 1; return 0; }

setup_all() { # install EVERYTHING once: build tools, social, webzip, share, extras + android.jar
  banner; echo "${B} Setup - install everything once${N}"; hr
  local rc=0
  ensure_tools build core social webzip share extras serve git || rc=1
  ensure_jar || rc=1
  hr
  if [ "$rc" -eq 0 ]; then
    ok "Everything is installed. You will not need to install anything again."
    info "Build, social, webzip, share and upload now run straight away."
  else
    warn "Some tools are missing - see messages above, then run: cioweb3apk setup"
  fi
  return $rc
}

# ───────────── private API keys (optional) ─────────────
key_get() { # key_get NAME -> prints value (file is parsed, never executed)
  [ -f "$KEYS" ] || return 1
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "${line%%=*}" = "$1" ]; then printf '%s' "${line#*=}"; return 0; fi
  done < "$KEYS"
  return 1
}
key_set() { # key_set NAME VALUE
  ( umask 077; touch "$KEYS" )
  { grep -v "^$1=" "$KEYS" 2>/dev/null; printf '%s=%s\n' "$1" "$2"; } > "$KEYS.tmp"
  chmod 600 "$KEYS.tmp"; mv "$KEYS.tmp" "$KEYS"
}
key_name() { case "$1" in youtube|yt) echo YT_API_KEY ;; github|gh) echo GITHUB_TOKEN ;; *) echo "" ;; esac; }
keys_cmd() { # keys set youtube KEY | keys rm youtube | keys list
  local n v mask
  case "$SUB" in
    set)
      n="$(key_name "$ARG")"; v="$ARG2"
      [ -n "$n" ] || { bad "Usage: keys set youtube|github KEY"; return 1; }
      [[ "$v" =~ ^[A-Za-z0-9_.-]{8,200}$ ]] || { bad "That does not look like a valid key"; return 1; }
      key_set "$n" "$v"; ok "Saved $n  ${D}(file .keys, owner-only; never uploaded or exported)${N}" ;;
    rm|delete)
      n="$(key_name "$ARG")"; [ -n "$n" ] || { bad "Usage: keys rm youtube|github"; return 1; }
      if [ -f "$KEYS" ]; then grep -v "^$n=" "$KEYS" > "$KEYS.tmp"; mv "$KEYS.tmp" "$KEYS"; fi
      ok "Removed $n" ;;
    *)
      banner; echo "${B} API keys (optional)${N}"; hr
      for n in YT_API_KEY GITHUB_TOKEN; do
        if v="$(key_get "$n")"; then mask="${v:0:4}…${v: -2}"; ok "$n  ${D}$mask${N}"; else info "$n  ${D}not set${N}"; fi
      done
      echo "  ${D}YouTube: free key from Google Cloud Console (YouTube Data API v3)${N}"
      echo "  ${D}GitHub : optional token = higher rate limit${N}"
      echo "  ${D}Usage  : cioweb3apk keys set youtube <KEY>${N}" ;;
  esac
}

# ───────────── ImageMagick 6/7 wrappers ─────────────
have_im() { command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; }
imconv()  { if command -v magick >/dev/null 2>&1; then magick "$@"; else convert "$@"; fi; }
imident() { if command -v magick >/dev/null 2>&1; then magick identify "$@"; else identify "$@"; fi; }

make_default_icon() { # coloured gradient square with the app initial (falls back to a plain colour)
  local out="$1" sz="${2:-192}" ini c2
  ini="$(printf '%s' "$APP_NAME" | tr -cd 'A-Za-z0-9' | cut -c1 | tr 'a-z' 'A-Z')"; [ -n "$ini" ] || ini="W"
  if [[ "$COLOR" =~ ^#[0-9A-F]{6}$ ]]; then
    c2="$(darken "$COLOR" 35)"
    if imconv -size "${sz}x${sz}" "gradient:${COLOR}-${c2}" -gravity center -fill white -pointsize $(( sz * 55 / 100 )) -annotate 0 "$ini" "PNG32:$out" 2>/dev/null; then return 0; fi
    if imconv -size "${sz}x${sz}" "gradient:${COLOR}-${c2}" "PNG32:$out" 2>/dev/null; then return 0; fi
  fi
  imconv -size "${sz}x${sz}" "xc:$COLOR" "PNG32:$out"
}

# ───────────── dependencies / doctor ─────────────
MISSING_PKGS=()
add_missing() { local p; for p in "${MISSING_PKGS[@]}"; do [ "$p" = "$1" ] && return; done; MISSING_PKGS+=("$1"); }

doctor() {
  local fix="${1:-}"; local bads=0
  MISSING_PKGS=(); JAR_MISSING=0
  banner; echo "${B} Doctor - environment check${N}"; hr
  [ -d /data/data/com.termux ] && ok "Termux detected" || warn "Not running inside Termux (build may fail)"
  ok "bash ${BASH_VERSION%%(*}"

  if command -v java >/dev/null 2>&1; then ok "java: $(java -version 2>&1 | head -1)"
  else bad "java missing  ${D}→ pkg install openjdk-17${N}"; add_missing openjdk-17; bads=$((bads+1)); fi

  local pair c p
  for pair in keytool:openjdk-17 ecj:ecj aapt2:aapt2 apksigner:apksigner zip:zip; do
    c="${pair%%:*}"; p="${pair##*:}"
    if command -v "$c" >/dev/null 2>&1; then ok "$c"
    else bad "$c missing  ${D}→ pkg install $p${N}"; add_missing "$p"; bads=$((bads+1)); fi
  done

  if command -v d8 >/dev/null 2>&1; then ok "dexer: d8"
  elif command -v dx >/dev/null 2>&1; then ok "dexer: dx"
  else bad "dx/d8 missing  ${D}→ pkg install dx${N}"; add_missing dx; bads=$((bads+1)); fi

  if find_android_jar && valid_jar "$ANDROID_JAR"; then ok "android.jar ${D}($ANDROID_JAR)${N}"
  else
    bad "android.jar missing  ${D}→ run: cioweb3apk jar${N}"; JAR_MISSING=1; bads=$((bads+1))
    if command -v dpkg >/dev/null 2>&1; then
      local pj; pj="$(dpkg -L aapt 2>/dev/null | grep -i 'jar' | head -n2)"
      [ -n "$pj" ] && info "aapt package files: $pj"
    fi
  fi

  echo "${B} Optional${N}"
  command -v unzip     >/dev/null 2>&1 && ok "unzip (jar check)" || warn "unzip missing (optional) → pkg install unzip"
  command -v zipalign  >/dev/null 2>&1 && ok "zipalign (aligned APK)" || warn "zipalign not found (APK still works)"
  have_im && ok "imagemagick (icon/image optimizer)" || { warn "imagemagick missing → pkg install imagemagick"; add_missing imagemagick; }
  command -v curl      >/dev/null 2>&1 && ok "curl (icon/splash from link)" || { warn "curl missing → pkg install curl"; add_missing curl; }
  command -v ffmpeg    >/dev/null 2>&1 && ok "ffmpeg (video optimizer)" || warn "ffmpeg missing (video used as is)"
  command -v git      >/dev/null 2>&1 && ok "git (update command)" || warn "git missing → pkg install git"
  command -v python   >/dev/null 2>&1 && ok "python (Wi-Fi share)" || warn "python missing → pkg install python (for 'serve')"
  command -v pngquant >/dev/null 2>&1 && ok "pngquant (smaller PNG)" || warn "pngquant missing (optional) → pkg install pngquant"
  command -v termux-wake-lock >/dev/null 2>&1 && ok "wake-lock (keeps build alive)" || warn "termux-wake-lock missing (pkg install termux-tools)"
  command -v qrencode >/dev/null 2>&1 && ok "qrencode (QR code)" || warn "qrencode missing (optional) → pkg install qrencode"
  command -v termux-share >/dev/null 2>&1 && ok "termux-api (share to WhatsApp)" || { warn "termux-api missing → pkg install termux-api (+ Termux:API app)"; add_missing termux-api; }

  echo "${B} Storage & system${N}"
  local od; od="$(get_outdir quiet)"
  mkdir -p "$od" 2>/dev/null
  if [ -d "$od" ] && [ -w "$od" ]; then ok "Output folder: $od"
  else bad "Output folder not writable: $od  ${D}→ run termux-setup-storage${N}"; bads=$((bads+1)); fi
  local free; free="$(df -k "$HOME" 2>/dev/null | awk 'NR==2{print int($4/1024)}')"
  if [ -n "$free" ]; then
    if [ "$free" -ge 300 ]; then ok "Free space: ${free} MB"; else warn "Low free space: ${free} MB"; fi
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -sI -m 5 https://www.google.com >/dev/null 2>&1 && ok "Internet OK" || warn "No internet (only needed for links/deps)"
  fi
  if [ -f "$KS" ]; then ok "Keystore exists ${D}(backup: cioweb3apk keystore backup)${N}"; else info "Keystore will be created on first build"; fi

  echo "${B} Config${N}"
  if validate_config; then ok "Config valid"; else bads=$((bads+1)); fi
  check_url

  hr
  if [ "$bads" -eq 0 ]; then echo "${G}${B} All good - ready to build!${N}"
  else echo "${R}${B} $bads problem(s) found${N}"; fi
  if [ ${#MISSING_PKGS[@]} -gt 0 ] && command -v pkg >/dev/null 2>&1; then
    echo "${D} Missing packages: ${MISSING_PKGS[*]}${N}"
    if [ "$fix" = "--fix" ] || ask_yn "Install missing packages now?"; then
      echo "${D}\$ pkg install -y ${MISSING_PKGS[*]}${N}"
      pkg install -y "${MISSING_PKGS[@]}"
    fi
  fi
  if [ "$JAR_MISSING" = 1 ]; then
    if [ "$fix" = "--fix" ] || ask_yn "Download android.jar now?"; then jar_cmd && bads=$((bads-1)); fi
  fi
  return $bads
}


# ───────────── files ─────────────
is_png() { [ "$(head -c 4 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "89504e47" ]; }

UA_STR='Mozilla/5.0 (Linux; Android 13) CioWeb3Apk'
FETCH_CTYPE=""; FETCH_TYPE=""

normalize_link() { # turn common "share" links into DIRECT file links
  local u="$1" id rest from="/blob/"
  case "$u" in
    *drive.google.com/file/d/*)
      id="${u#*/file/d/}"; id="${id%%/*}"; id="${id%%\?*}"
      u="https://drive.google.com/uc?export=download&id=$id" ;;
    *drive.google.com/open\?id=*|*drive.google.com/uc\?*id=*)
      id="${u#*id=}"; id="${id%%&*}"
      u="https://drive.google.com/uc?export=download&id=$id" ;;
    *://imgur.com/*|*://www.imgur.com/*)
      id="${u##*/}"; id="${id%%\?*}"
      if [[ "$id" =~ ^[A-Za-z0-9]{5,8}$ ]] && [[ "$u" != */a/* ]] && [[ "$u" != */gallery/* ]]; then u="https://i.imgur.com/$id.png"; fi ;;
    *://github.com/*/blob/*)
      rest="${u#*://github.com/}"
      u="https://raw.githubusercontent.com/${rest/$from//}" ;;
    *dropbox.com/*)
      u="${u/www.dropbox.com/dl.dropboxusercontent.com}"; u="${u/\?dl=0/}"; u="${u/&dl=0/}" ;;
  esac
  printf '%s' "$u"
}

img_type() { # detect real file type from magic bytes
  local h; h="$(head -c 12 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  case "$h" in
    89504e47*) echo png ;;
    ffd8ff*) echo jpg ;;
    47494638*) echo gif ;;
    52494646????????57454250) echo webp ;;
    424d*) echo bmp ;;
    3c3f786d6c*|3c737667*) echo svg ;;
    3c*) echo html ;;
    *) echo unknown ;;
  esac
}

fetch_url() { # fetch_url URL DEST   (limits: 25MB, 90s, follows redirects)
  local url="$1" out="$2" meta rc code
  if ! command -v curl >/dev/null 2>&1; then ensure_tools core >&2 || { echo "curl missing" >&2; return 1; }; fi
  meta="$(curl -sL -m 90 --max-filesize 26214400 -A "$UA_STR" -o "$out" -w '%{http_code} %{content_type}' "$url" 2>/dev/null)"; rc=$?
  code="${meta%% *}"; FETCH_CTYPE="${meta#* }"
  if [ "$rc" -ne 0 ] || [ "$code" = "000" ]; then
    echo "Cannot download: no internet, blocked, or file bigger than 25 MB ($url)" >&2; return 1
  fi
  case "$code" in
    2*) ;;
    401|403) echo "Access denied (HTTP $code): the link is private or blocks apps" >&2; return 1 ;;
    404) echo "Not found (HTTP 404): check the link" >&2; return 1 ;;
    *) echo "Server answered HTTP $code" >&2; return 1 ;;
  esac
  return 0
}

fetch_image() { # fetch_image LINK DEST  (validates it is a real image)
  local out="$2" url t
  url="$(normalize_link "$1")"
  fetch_url "$url" "$out" || return 1
  t="$(img_type "$out")"
  case "$t" in
    png|jpg|gif|webp|bmp) ;;
    html) echo "That link opens a WEB PAGE, not a picture. Use a DIRECT image link (ends with .png .jpg .webp). Tip: long-press the image > copy image address." >&2; return 1 ;;
    svg) echo "SVG is not supported. Convert it to PNG first." >&2; return 1 ;;
    *) if have_im && imident -quiet "$out" >/dev/null 2>&1; then t=image
       else echo "Downloaded file is not a valid image (server said: ${FETCH_CTYPE:-unknown})" >&2; return 1; fi ;;
  esac
  FETCH_TYPE="$t"
  return 0
}

resolve_input() { # resolve_input SRC [image|video|any] -> echoes local file path
  local src="${1/#\~/$HOME}" kind="${2:-any}" nsrc out
  if is_link "$src"; then
    nsrc="$(normalize_link "$src")"
    mkdir -p "$CACHE/dl"
    out="$CACHE/dl/$(printf '%s' "$nsrc" | md5sum | cut -c1-12)"
    if [ -s "$out" ] && [ "$REFRESH" != 1 ] && [ -z "$(find "$out" -mmin +1440 2>/dev/null)" ]; then echo "$out"; return 0; fi
    if [ "$kind" = image ]; then
      fetch_image "$nsrc" "$out" || { rm -f "$out"; return 1; }
    else
      fetch_url "$nsrc" "$out" || { rm -f "$out"; return 1; }
      if [ "$kind" = video ] && [ "$(img_type "$out")" = html ]; then
        echo "That link is a web page, not a direct video file (.mp4)." >&2; rm -f "$out"; return 1
      fi
    fi
    echo "$out"
  else
    [ -f "$src" ] || { echo "File not found: $src" >&2; return 1; }
    if [ "$kind" = image ] && [ "$(img_type "$src")" = html ]; then echo "That file is not an image: $src" >&2; return 1; fi
    echo "$src"
  fi
}

icon_check() { # icon_check LINK|PATH -> prints result, returns 0 if usable
  local src="$1" path n dim w h size t
  mkdir -p "$CACHE"
  if is_link "$src"; then ensure_tools core || return 1; fi
  if is_link "$src"; then
    n="$(normalize_link "$src")"
    if [ "$n" != "$src" ]; then info "Converted to direct link: ${D}$n${N}"; fi
    info "Downloading icon..."
  fi
  if ! path="$(resolve_input "$src" image 2>"$CACHE/.err")"; then bad "$(cat "$CACHE/.err")"; return 1; fi
  t="$(img_type "$path")"; [ "$t" = unknown ] && t="image"
  size="$(du -h "$path" | cut -f1)"
  dim=""
  if have_im; then dim="$(imident -quiet -format '%w %h' "${path}[0]" 2>/dev/null)"; fi
  if [ -n "$dim" ]; then
    read -r w h <<< "$dim"
    ok "Image OK: $t, ${w}x${h}px, $size"
    if [ "$w" -lt 192 ] || [ "$h" -lt 192 ]; then warn "Small image (${w}x${h}). 512x512 PNG looks sharpest."; fi
    if [ "$w" -ne "$h" ]; then warn "Not square: it will be centered with transparent padding."; fi
  else
    ok "Image OK: $t, $size"
  fi
  return 0
}

icon_wizard() {
  banner; echo "${B} Icon from direct image link${N}"; hr
  echo "  ${D}Paste a DIRECT link to a PNG/JPG/WEBP (ends with .png .jpg ...).${N}"
  echo "  ${D}Also converted automatically: imgur.com/ID, GitHub blob,${N}"
  echo "  ${D}Google Drive and Dropbox share links. Or type a file path.${N}"
  echo "  ${D}Enter = cancel   '-' = back to default icon${N}"
  local i src
  for i in 1 2 3; do
    read -r -p "${Y}Link or path${N}: " src
    [ -z "$src" ] && return 0
    if [ "$src" = "-" ]; then ICON=""; save_config; ok "Icon reset to default"; return 0; fi
    REFRESH=1
    if icon_check "$src"; then ICON="$src"; REFRESH=0; save_config; ok "Icon saved"; return 0; fi
    REFRESH=0; warn "Try again ($i/3)"
  done
  return 1
}

icon_cmd() {
  case "$SUB" in
    ""|help) info "Usage: icon set LINK|PATH   icon test LINK|PATH   icon reset" ;;
    reset)   ICON=""; save_config; ok "Icon reset to default" ;;
    test)    [ -n "$ARG" ] || { bad "Usage: icon test LINK|PATH"; return 1; }; REFRESH=1; icon_check "$ARG" ;;
    set)     [ -n "$ARG" ] || { bad "Usage: icon set LINK|PATH"; return 1; }
             REFRESH=1; if icon_check "$ARG"; then ICON="$ARG"; save_config; ok "Icon saved"; else return 1; fi ;;
    *)       REFRESH=1; if icon_check "$SUB"; then ICON="$SUB"; save_config; ok "Icon saved"; else return 1; fi ;;
  esac
}

preflight_assets() { # download + validate remote assets BEFORE the long build
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$CACHE"
  if [ -n "$ICON" ] && is_link "$ICON"; then icon_check "$ICON" || return 1; fi
  if [ "$SPLASH_TYPE" = image ] && is_link "$SPLASH_VALUE"; then
    resolve_input "$SPLASH_VALUE" image >/dev/null 2>"$CACHE/.err" || { bad "Loading image: $(cat "$CACHE/.err")"; return 1; }
    ok "Loading image link OK"
  fi
  if [ "$SPLASH_TYPE" = video ] && is_link "$SPLASH_VALUE"; then
    resolve_input "$SPLASH_VALUE" video >/dev/null 2>"$CACHE/.err" || { bad "Loading video: $(cat "$CACHE/.err")"; return 1; }
    ok "Loading video link OK"
  fi
  return 0
}

get_outdir() {
  local d="$HOME/storage/downloads"
  if [ ! -d "$d" ] && [ "$1" != quiet ] && command -v termux-setup-storage >/dev/null 2>&1; then
    termux-setup-storage >&2; sleep 4
  fi
  [ -d "$d" ] && { echo "$d"; return; }
  [ -d /sdcard/Download ] && [ -w /sdcard/Download ] && { echo /sdcard/Download; return; }
  mkdir -p "$BASE/output"; echo "$BASE/output"
}

# ───────────── build engine ─────────────
STEP_N=0; STEP_T=8

log_section() { awk '/^=== /{buf=""} {buf=buf $0 "\n"} END{printf "%s",buf}' "$LOG" 2>/dev/null; }

hint() { # probable fix, based ONLY on the step that failed
  local l="$CACHE/.hint"; mkdir -p "$CACHE"
  log_section | grep -v "deprecated in IMv7" | tail -n 40 > "$l"
  echo "${Y}${B} Possible fix:${N}"
  if grep -qiE "expected reference but got|raw string" "$l"; then echo "  A generated resource has the wrong value type (tool bug) → cioweb3apk update, then rebuild"
  elif grep -qiE "attribute .* not found|resource .* not found" "$l"; then echo "  android.jar is old/incomplete → cioweb3apk jar --refresh (or pkg upgrade aapt aapt2)"
  elif grep -qiE "unsupported class file|bad class file|major version" "$l"; then echo "  Java version mismatch → pkg install openjdk-17 dx ecj"
  elif grep -qiE "cannot find symbol|cannot be resolved" "$l"; then echo "  android.jar API too old → cioweb3apk jar --refresh"
  elif grep -qiE "keytool|keystore" "$l"; then echo "  Delete cio.keystore and rebuild"
  elif grep -qiE "mirror|unable to locate package|failed to fetch|Err:" "$l"; then echo "  Package mirror problem → termux-change-repo, then: pkg update"
  elif grep -qiE "permission denied|read-only file system" "$l"; then echo "  Storage permission → run: termux-setup-storage"
  elif grep -qiE "ssl|certificate" "$l"; then echo "  SSL problem → pkg upgrade ca-certificates curl"
  elif grep -qiE "No space left" "$l"; then echo "  Storage full → cioweb3apk clean"
  elif grep -qiE "OutOfMemory|heap space" "$l"; then echo "  Low RAM → close other apps, then retry"
  elif grep -qiE "Download failed|could not resolve|curl:" "$l"; then echo "  Check your link / internet connection"
  elif grep -qiE "unable to open image|no decode delegate|improper image header|magick:" "$l"; then echo "  Image problem → use a valid PNG/JPG, or: pkg install imagemagick"
  else echo "  Run: cioweb3apk doctor   then send build.log if still failing"; fi
}

# ───────────── animation engine ─────────────
SPIN_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
anim_on() { [ "$BUILD_ANIM" = 1 ] && [ "$USE_COLOR" = 1 ] && [ -t 1 ]; }

gbar() { # gbar DONE TOTAL PULSE  -> gradient progress bar ( PULSE -1 = no pulsing cell )
  local n=$1 t=$2 pulse=${3:-0} w=$BAR_W f i out="" ch
  f=$(( n * w / t ))
  for ((i=0; i<w; i++)); do
    if [ "$i" -lt "$f" ]; then out+="$(fg "${GRAD[i*5/(w-1)]}")█"
    elif [ "$i" -eq "$f" ] && [ "$pulse" -ge 0 ]; then
      if [ $((pulse % 2)) -eq 0 ]; then ch="▓"; else ch="▒"; fi
      out+="$(fg "${GRAD[i*5/(w-1)]}")$ch"
    else out+="${D}░"; fi
  done
  printf '%s%s' "$out" "$N"
}

spin_wait() { # spin_wait PID LABEL [N TOTAL] [STATUS_FN]  -> animates until PID ends, returns its exit code
  local pid=$1 label="$2" n="${3:-}" t="${4:-}" fn="${5:-}" i=0 t0=$SECONDS el bar="" extra=""
  while kill -0 "$pid" 2>/dev/null; do
    el=$(( SECONDS - t0 ))
    if [ -n "$n" ]; then bar="$(gbar "$((n-1))" "$t" "$i") ${D}$n/$t${N} "; fi
    if [ -n "$fn" ] && [ $((i % 5)) -eq 0 ]; then extra="$($fn)"; fi
    printf '\r\033[K %s%s%s %s%s%s%s %s%ss%s  %s%s%s' "$(fg "${GRAD[i%6]}")" "${SPIN_FRAMES[i%10]}" "$N" "$bar" "$B" "$label" "$N" "$D" "$el" "$N" "$D" "$extra" "$N"
    i=$((i+1)); sleep 0.1
  done
  wait "$pid"
}

spin_run() { # spin_run "label" command...   (output goes to $SPIN_LOG or $LOG)
  local label="$1"; shift
  local lg="${SPIN_LOG:-$LOG}" rc
  { echo "=== $label ==="; echo "\$ $*"; } >> "$lg"
  if anim_on; then
    "$@" >> "$lg" 2>&1 &
    CUR_PID=$!
    spin_wait "$CUR_PID" "$label"; rc=$?
    CUR_PID=""
    printf '\r\033[K'
  else
    echo "  ${C}»${N} $label ..."
    "$@" >> "$lg" 2>&1; rc=$?
  fi
  return $rc
}

celebrate() { # celebrate SECONDS -> gradient typewriter "BUILD SUCCESS"
  local word="BUILD SUCCESS" i
  printf ' %s✔%s ' "$G" "$N"
  for ((i=0; i<${#word}; i++)); do
    printf '%s%s%s%s' "$B" "$(fg "${GRAD[i*5/12]}")" "${word:i:1}" "$N"
    if anim_on; then sleep 0.03; fi
  done
  printf '  %s(%ss)%s\n' "$D" "$1" "$N"
}

SLOW_T=0; SLOW_L=""
step() { # [STEP_CMD="shown command"] step "label" command...
  local label="$1"; shift
  local t0=$SECONDS shown="${STEP_CMD:-$*}" rc el anim=0
  STEP_N=$((STEP_N+1))
  if anim_on && [ "$LIVE" != 1 ] && [ "$DRY" != 1 ]; then anim=1; fi
  if [ "$anim" = 0 ]; then echo "${C}$(bar "$STEP_N" "$STEP_T")${N} ${B}$label${N}"; fi
  if [ "$SHOW_CMD" = 1 ]; then echo "${D}  \$ $shown${N}"; fi
  if [ "$DRY" = 1 ]; then echo "  ${Y}↷ skipped (dry run)${N}"; return 0; fi
  { echo "=== $label ==="; echo "\$ $shown"; } >> "$LOG"
  if [ "$anim" = 1 ]; then
    "$@" >> "$LOG" 2>&1 &
    CUR_PID=$!
    spin_wait "$CUR_PID" "$label" "$STEP_N" "$STEP_T"; rc=$?
    CUR_PID=""
  elif [ "$LIVE" = 1 ]; then
    "$@" 2>&1 | tee -a "$LOG" | sed "s/^/    ${D}│${N} /"
    rc=${PIPESTATUS[0]}
  else
    "$@" >> "$LOG" 2>&1; rc=$?
  fi
  el=$((SECONDS-t0))
  if [ "$rc" -eq 0 ]; then
    printf '%s|%s|ok|%s\n' "$label" "${shown//|/¦}" "$el" >> "$STEPLOG"
    if [ "$anim" = 1 ]; then
      printf '\r\033[K %s✔%s %s %s%s%s %s(%ss)%s\n' "$G" "$N" "$(gbar "$STEP_N" "$STEP_T" -1)" "$B" "$label" "$N" "$D" "$el" "$N"
    else
      echo "  ${G}✔ done${N} ${D}(${el}s)${N}"
    fi
    if [ "$el" -gt "$SLOW_T" ]; then SLOW_T=$el; SLOW_L="$label"; fi
    return 0
  fi
  if [ "$anim" = 1 ]; then printf '\r\033[K'; fi
  echo "  ${R}✘ FAILED: $label${N}"
  printf '%s|%s|FAIL|%s\n' "$label" "${shown//|/¦}" "$el" >> "$STEPLOG"
  hr; echo "${Y} Error output of this step:${N}"; log_section | grep -v "deprecated in IMv7" | tail -n 14 | sed 's/^/  /'; hr
  hint; echo "${D}  Full log: $LOG${N}"
  return 1
}

opt_png() { # shrink a PNG when optional tools exist
  [ "$OPTIMIZE" = 1 ] || return 0
  if command -v pngquant >/dev/null 2>&1; then pngquant --force --skip-if-larger --quality 70-95 --output "$1" "$1" >/dev/null 2>&1
  elif command -v optipng >/dev/null 2>&1; then optipng -quiet -o2 "$1" >/dev/null 2>&1; fi
  return 0
}

prep_assets() {
  local ic sp d sum cdir f
  mkdir -p "$PW/res/values" "$PW/res/drawable" "$PW/res/raw" "$PW/build" "$PW/classes" "$PKGDIR"
  local sizes="mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192"
  # --- icon ---
  if [ -n "$ICON" ]; then
    ic="$(resolve_input "$ICON" image)" || return 1
    sum="$(md5sum "$ic" | cut -c1-12)-$OPTIMIZE"; cdir="$CACHE/icons/$sum"
    if [ -f "$cdir/mipmap-xxxhdpi/ic_launcher.png" ]; then
      cp -r "$cdir"/mipmap-* "$PW/res/"; echo "icon: cache hit ($sum)"
    else
      if have_im && [ "$OPTIMIZE" = 1 ]; then
        local pids=() pid rc=0
        for d in $sizes; do
          mkdir -p "$PW/res/mipmap-${d%%:*}"
          imconv "$ic[0]" -resize "${d##*:}x${d##*:}" -background none -gravity center -extent "${d##*:}x${d##*:}" -strip "PNG32:$PW/res/mipmap-${d%%:*}/ic_launcher.png" &
          pids+=($!)
        done
        for pid in "${pids[@]}"; do wait "$pid" || rc=1; done
        [ "$rc" -eq 0 ] || { echo "Icon conversion failed" >&2; return 1; }
      else
        mkdir -p "$PW/res/mipmap-xxxhdpi"
        if [ "$(img_type "$ic")" = png ]; then cp "$ic" "$PW/res/mipmap-xxxhdpi/ic_launcher.png"
        elif have_im; then imconv "$ic[0]" "PNG32:$PW/res/mipmap-xxxhdpi/ic_launcher.png" || return 1
        else echo "Icon is not PNG and imagemagick is missing (pkg install imagemagick)" >&2; return 1; fi
      fi
      for f in "$PW"/res/mipmap-*/ic_launcher.png; do opt_png "$f"; done
      mkdir -p "$cdir" && cp -r "$PW"/res/mipmap-* "$cdir/"
    fi
  else
    mkdir -p "$PW/res/mipmap-xxxhdpi"
    have_im || { echo "No icon given and imagemagick missing" >&2; return 1; }
    make_default_icon "$PW/res/mipmap-xxxhdpi/ic_launcher.png" 192 || return 1
  fi
  # --- loading screen ---
  case "$SPLASH_TYPE" in
    image)
      sp="$(resolve_input "$SPLASH_VALUE" image)" || return 1
      if have_im; then
        if [ "$OPTIMIZE" = 1 ]; then imconv "$sp[0]" -resize '1080x1920>' -strip "PNG:$PW/res/drawable/splash.png" || return 1
        else imconv "$sp[0]" "PNG:$PW/res/drawable/splash.png" || return 1; fi
      elif [ "$(img_type "$sp")" = png ]; then cp "$sp" "$PW/res/drawable/splash.png"
      else echo "Loading image is not PNG and imagemagick is missing" >&2; return 1; fi
      opt_png "$PW/res/drawable/splash.png" ;;
    video)
      sp="$(resolve_input "$SPLASH_VALUE" video)" || return 1
      if [ "$OPTIMIZE" = 1 ] && command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -y -loglevel error -i "$sp" -vf "scale='min(720,iw)':-2" -c:v libx264 -crf 28 -preset veryfast -an -movflags +faststart "$PW/res/raw/splash.mp4" \
          || cp "$sp" "$PW/res/raw/splash.mp4"
      else cp "$sp" "$PW/res/raw/splash.mp4"; fi ;;
  esac
}

gen_project() {
  local sval="#FFFFFF" wbg="#FFFFFF" orient="unspecified"
  case "$SPLASH_TYPE" in
    image|video) wbg="#000000" ;;
    color) sval="$SPLASH_VALUE"; wbg="$SPLASH_VALUE" ;;
  esac
  case "$ORIENT" in portrait) orient="portrait" ;; landscape) orient="landscape" ;; esac
  local perms=""
  if [ "$WEB_PERMS" = 1 ]; then
    perms='  <uses-permission android:name="android.permission.CAMERA"/>
  <uses-permission android:name="android.permission.RECORD_AUDIO"/>
  <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-feature android:name="android.hardware.camera" android:required="false"/>
  <uses-feature android:name="android.hardware.microphone" android:required="false"/>
  <uses-feature android:name="android.hardware.location.gps" android:required="false"/>'
  fi

  cat > "$PW/res/values/styles.xml" << XML
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <style name="AppTheme" parent="android:Theme.Material.Light.NoActionBar">
    <item name="android:colorPrimaryDark">@color/primary_dark</item>
    <item name="android:statusBarColor">@color/primary_dark</item>
    <item name="android:windowBackground">@color/win_bg</item>
  </style>
</resources>
XML

  cat > "$PW/res/values/colors.xml" << XML
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <color name="primary_dark">$COLOR</color>
  <color name="win_bg">$wbg</color>
</resources>
XML

  cat > "$PW/res/values/strings.xml" << XML
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <string name="app_name">$(xesc "$APP_NAME")</string>
</resources>
XML

  cat > "$PW/AndroidManifest.xml" << XML
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="$PACKAGE">
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
$perms
  <application android:label="@string/app_name" android:icon="@mipmap/ic_launcher"
      android:theme="@style/AppTheme" android:usesCleartextTraffic="true"
      android:hardwareAccelerated="true" android:allowBackup="false">
    <activity android:name=".MainActivity" android:screenOrientation="$orient"
        android:configChanges="orientation|screenSize|keyboardHidden|smallestScreenSize|screenLayout">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
XML

  local J_URL J_FS J_ON J_DL J_UP J_FADE J_PB J_ZM J_LK J_EX J_UA J_HOST J_WP J_SC ua host
  ua="$USER_AGENT"
  if [ "$DESKTOP" = 1 ] && [ -z "$ua" ]; then
    ua="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  fi
  host="${URL#*://}"; host="${host%%/*}"; host="${host%%:*}"; host="${host#www.}"; host="${host,,}"
  J_URL="$(jesc "$URL")"; J_FS="$(b2j $FULLSCREEN)"; J_ON="$(b2j $KEEP_ON)"
  J_DL="$(b2j $ALLOW_DOWNLOAD)"; J_UP="$(b2j $ALLOW_UPLOAD)"; J_FADE="$(b2j $SPLASH_FADE)"
  J_PB="$(b2j $PROGRESS_BAR)"; J_ZM="$(b2j $ALLOW_ZOOM)"; J_LK="$(b2j $LOCK_DOMAIN)"; J_EX="$(b2j $EXIT_CONFIRM)"
  J_UA="$(jesc "$ua")"; J_HOST="$(jesc "$host")"
  J_WP="$(b2j $WEB_PERMS)"; J_SC="$(b2j $SECURE_MODE)"

  cat > "$PKGDIR/MainActivity.java" << JAVA
package $PACKAGE;

import android.app.Activity;
import android.app.DownloadManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
import android.webkit.URLUtil;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.content.pm.PackageManager;
import android.webkit.GeolocationPermissions;
import android.webkit.PermissionRequest;
import java.util.ArrayList;
import android.widget.Toast;
import android.widget.VideoView;

public class MainActivity extends Activity {
    private static final String START_URL = "$J_URL";
    private static final boolean FULLSCREEN = $J_FS;
    private static final boolean KEEP_ON = $J_ON;
    private static final boolean ALLOW_DOWNLOAD = $J_DL;
    private static final boolean ALLOW_UPLOAD = $J_UP;
    private static final String SPLASH_TYPE = "$SPLASH_TYPE";
    private static final String SPLASH_COLOR = "$sval";
    private static final long SPLASH_MS = ${SPLASH_MS}L;
    private static final boolean SPLASH_FADE = $J_FADE;
    private static final int REQ_FILE = 4711;
    private static final boolean PROGRESS_BAR = $J_PB;
    private static final boolean ALLOW_ZOOM = $J_ZM;
    private static final boolean LOCK_DOMAIN = $J_LK;
    private static final boolean EXIT_CONFIRM = $J_EX;
    private static final String USER_AGENT = "$J_UA";
    private static final String HOME_HOST = "$J_HOST";
    private static final boolean WEB_PERMS = $J_WP;
    private static final boolean SECURE_MODE = $J_SC;
    private static final int REQ_PERM = 4712;
    private static final int REQ_GEO = 4713;

    private WebView web;
    private FrameLayout root;
    private View splash;
    private long startedAt;
    private boolean hideScheduled = false;
    private String currentUrl = "";
    private ValueCallback<Uri[]> filePathCallback;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private ProgressBar bar;
    private long lastBack = 0;
    private PermissionRequest pendingReq;
    private GeolocationPermissions.Callback pendingGeoCb;
    private String pendingGeoOrigin;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        if (FULLSCREEN) {
            getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                    WindowManager.LayoutParams.FLAG_FULLSCREEN);
        }
        if (KEEP_ON) {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
        if (SECURE_MODE) {
            getWindow().setFlags(WindowManager.LayoutParams.FLAG_SECURE,
                    WindowManager.LayoutParams.FLAG_SECURE);
        }
        startedAt = SystemClock.elapsedRealtime();
        root = new FrameLayout(this);
        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setUseWideViewPort(true);
        s.setLoadWithOverviewMode(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(false);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        if (USER_AGENT.length() > 0) {
            s.setUserAgentString(USER_AGENT);
        }
        if (ALLOW_ZOOM) {
            s.setSupportZoom(true);
            s.setBuiltInZoomControls(true);
            s.setDisplayZoomControls(false);
        }
        if (WEB_PERMS) {
            s.setGeolocationEnabled(true);
        }
        web.setWebViewClient(new AppClient());
        web.setWebChromeClient(new AppChrome());
        if (ALLOW_DOWNLOAD) {
            web.setDownloadListener(new DownloadListener() {
                @Override
                public void onDownloadStart(String url, String ua, String cd, String mime, long len) {
                    startDownload(url, ua, cd, mime);
                }
            });
        }
        root.addView(web, new FrameLayout.LayoutParams(-1, -1));
        if (PROGRESS_BAR) {
            bar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
            bar.setMax(100);
            bar.setProgressTintList(android.content.res.ColorStateList.valueOf(Color.parseColor("$COLOR")));
            int h = (int) (3 * getResources().getDisplayMetrics().density);
            root.addView(bar, new FrameLayout.LayoutParams(-1, h, Gravity.TOP));
            bar.setVisibility(View.GONE);
        }
        buildSplash();
        setContentView(root);
        if (b == null || web.restoreState(b) == null) {
            web.loadUrl(START_URL);
        }
    }

    private void startDownload(String url, String ua, String cd, String mime) {
        try {
            String name = URLUtil.guessFileName(url, cd, mime);
            DownloadManager.Request r = new DownloadManager.Request(Uri.parse(url));
            if (mime != null) r.setMimeType(mime);
            r.addRequestHeader("User-Agent", ua);
            String cookie = CookieManager.getInstance().getCookie(url);
            if (cookie != null) r.addRequestHeader("Cookie", cookie);
            r.setTitle(name);
            r.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            r.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, name);
            DownloadManager dm = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
            dm.enqueue(r);
            Toast.makeText(MainActivity.this, "Downloading " + name, Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            try {
                startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
            } catch (Exception e2) {
                Toast.makeText(MainActivity.this, "Cannot download file", Toast.LENGTH_SHORT).show();
            }
        }
    }

    private class AppClient extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView v, String url) {
            if (url.startsWith("http://") || url.startsWith("https://")) {
                if (LOCK_DOMAIN && !sameSite(url)) {
                    openExternal(url);
                    return true;
                }
                return false;
            }
            try {
                Intent i;
                if (url.startsWith("intent:")) {
                    i = Intent.parseUri(url, Intent.URI_INTENT_SCHEME);
                    i.addCategory(Intent.CATEGORY_BROWSABLE);
                    i.setComponent(null);
                    i.setSelector(null);
                } else {
                    i = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                }
                startActivity(i);
            } catch (Exception e) {
                Toast.makeText(MainActivity.this, "Cannot open link", Toast.LENGTH_SHORT).show();
            }
            return true;
        }

        @Override
        public void onPageStarted(WebView v, String url, android.graphics.Bitmap icon) {
            currentUrl = url;
        }

        @Override
        public void onPageFinished(WebView v, String url) {
            hideSplash();
        }

        @Override
        public void onReceivedError(WebView v, int code, String desc, String failingUrl) {
            if (failingUrl != null && failingUrl.equals(currentUrl)) {
                showError(failingUrl);
            }
        }
    }

    private class AppChrome extends WebChromeClient {
        @Override
        public void onProgressChanged(WebView v, int p) {
            if (bar == null) return;
            bar.setProgress(p);
            bar.setVisibility(p >= 100 ? View.GONE : View.VISIBLE);
        }

        @Override
        public void onPermissionRequest(final PermissionRequest req) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    handleWebPermission(req);
                }
            });
        }

        @Override
        public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback cb) {
            if (!WEB_PERMS) {
                cb.invoke(origin, false, false);
                return;
            }
            if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                cb.invoke(origin, true, false);
            } else {
                pendingGeoOrigin = origin;
                pendingGeoCb = cb;
                requestPermissions(new String[] { android.Manifest.permission.ACCESS_FINE_LOCATION }, REQ_GEO);
            }
        }

        @Override
        public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams params) {
            if (!ALLOW_UPLOAD) {
                cb.onReceiveValue(null);
                return true;
            }
            if (filePathCallback != null) filePathCallback.onReceiveValue(null);
            filePathCallback = cb;
            try {
                Intent i = new Intent(Intent.ACTION_GET_CONTENT);
                i.addCategory(Intent.CATEGORY_OPENABLE);
                i.setType("*/*");
                if (params != null && params.getMode() == FileChooserParams.MODE_OPEN_MULTIPLE) {
                    i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
                }
                startActivityForResult(Intent.createChooser(i, "Choose file"), REQ_FILE);
            } catch (Exception e) {
                filePathCallback = null;
                cb.onReceiveValue(null);
            }
            return true;
        }
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        if (req == REQ_FILE && filePathCallback != null) {
            Uri[] result = null;
            if (res == RESULT_OK && data != null) {
                if (data.getClipData() != null) {
                    int n = data.getClipData().getItemCount();
                    result = new Uri[n];
                    for (int k = 0; k < n; k++) {
                        result[k] = data.getClipData().getItemAt(k).getUri();
                    }
                } else if (data.getData() != null) {
                    result = new Uri[] { data.getData() };
                }
            }
            filePathCallback.onReceiveValue(result);
            filePathCallback = null;
        } else {
            super.onActivityResult(req, res, data);
        }
    }

    private void handleWebPermission(PermissionRequest req) {
        if (!WEB_PERMS) {
            req.deny();
            return;
        }
        ArrayList<String> missing = new ArrayList<String>();
        String[] res = req.getResources();
        for (int i = 0; i < res.length; i++) {
            String perm = null;
            if (PermissionRequest.RESOURCE_VIDEO_CAPTURE.equals(res[i])) {
                perm = android.Manifest.permission.CAMERA;
            } else if (PermissionRequest.RESOURCE_AUDIO_CAPTURE.equals(res[i])) {
                perm = android.Manifest.permission.RECORD_AUDIO;
            }
            if (perm != null && checkSelfPermission(perm) != PackageManager.PERMISSION_GRANTED && !missing.contains(perm)) {
                missing.add(perm);
            }
        }
        if (missing.isEmpty()) {
            req.grant(res);
        } else {
            pendingReq = req;
            requestPermissions(missing.toArray(new String[missing.size()]), REQ_PERM);
        }
    }

    @Override
    public void onRequestPermissionsResult(int code, String[] perms, int[] results) {
        boolean allOk = results.length > 0;
        for (int i = 0; i < results.length; i++) {
            if (results[i] != PackageManager.PERMISSION_GRANTED) {
                allOk = false;
            }
        }
        if (code == REQ_PERM && pendingReq != null) {
            if (allOk) {
                pendingReq.grant(pendingReq.getResources());
            } else {
                pendingReq.deny();
            }
            pendingReq = null;
        } else if (code == REQ_GEO && pendingGeoCb != null) {
            pendingGeoCb.invoke(pendingGeoOrigin, allOk, false);
            pendingGeoCb = null;
        } else {
            super.onRequestPermissionsResult(code, perms, results);
        }
    }

    private boolean sameSite(String url) {
        try {
            String h = Uri.parse(url).getHost();
            if (h == null) return true;
            h = h.toLowerCase();
            if (h.startsWith("www.")) h = h.substring(4);
            return h.equals(HOME_HOST) || h.endsWith("." + HOME_HOST);
        } catch (Exception e) {
            return true;
        }
    }

    private void openExternal(String url) {
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
        } catch (Exception e) {
            Toast.makeText(MainActivity.this, "Cannot open link", Toast.LENGTH_SHORT).show();
        }
    }

    private void showError(String url) {
        String safe = url.replace("'", "%27");
        String html = "<html><head><meta name='viewport' content='width=device-width,initial-scale=1'></head>"
                + "<body style='font-family:sans-serif;text-align:center;padding:18vh 24px;color:#444'>"
                + "<h2>No connection</h2><p>Check your internet and try again.</p>"
                + "<a href='" + safe + "' style='display:inline-block;margin-top:16px;padding:12px 28px;"
                + "background:$COLOR;color:#fff;border-radius:24px;text-decoration:none'>Retry</a>"
                + "</body></html>";
        web.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null);
    }

    private void buildSplash() {
        if (SPLASH_TYPE.equals("none")) return;
        if (SPLASH_TYPE.equals("image")) {
            ImageView iv = new ImageView(this);
            int id = getResources().getIdentifier("splash", "drawable", getPackageName());
            iv.setImageResource(id);
            iv.setScaleType(ImageView.ScaleType.CENTER_CROP);
            splash = iv;
        } else if (SPLASH_TYPE.equals("video")) {
            VideoView vv = new VideoView(this);
            int id = getResources().getIdentifier("splash", "raw", getPackageName());
            vv.setVideoURI(Uri.parse("android.resource://" + getPackageName() + "/" + id));
            vv.setOnPreparedListener(new MediaPlayer.OnPreparedListener() {
                @Override
                public void onPrepared(MediaPlayer mp) { mp.setLooping(true); }
            });
            vv.setOnErrorListener(new MediaPlayer.OnErrorListener() {
                @Override
                public boolean onError(MediaPlayer mp, int what, int extra) { return true; }
            });
            vv.start();
            FrameLayout f = new FrameLayout(this);
            f.setBackgroundColor(Color.BLACK);
            f.addView(vv, new FrameLayout.LayoutParams(-1, -1, Gravity.CENTER));
            splash = f;
        } else {
            View v = new View(this);
            v.setBackgroundColor(Color.parseColor(SPLASH_COLOR));
            splash = v;
        }
        root.addView(splash, new FrameLayout.LayoutParams(-1, -1));
        handler.postDelayed(new Runnable() {
            @Override
            public void run() { removeSplash(); }
        }, 20000);
    }

    private void hideSplash() {
        if (splash == null || hideScheduled) return;
        hideScheduled = true;
        long wait = SPLASH_MS - (SystemClock.elapsedRealtime() - startedAt);
        if (wait < 0) wait = 0;
        handler.postDelayed(new Runnable() {
            @Override
            public void run() { removeSplash(); }
        }, wait);
    }

    private void removeSplash() {
        if (splash == null) return;
        final View sp = splash;
        splash = null;
        if (SPLASH_FADE) {
            sp.animate().alpha(0f).setDuration(350).withEndAction(new Runnable() {
                @Override
                public void run() { root.removeView(sp); }
            });
        } else {
            root.removeView(sp);
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        web.saveState(out);
    }

    @Override
    protected void onPause() { super.onPause(); web.onPause(); }

    @Override
    protected void onResume() { super.onResume(); web.onResume(); }

    @Override
    protected void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        web.destroy();
        super.onDestroy();
    }

    @Override
    public void onBackPressed() {
        if (web.canGoBack()) {
            web.goBack();
            return;
        }
        if (EXIT_CONFIRM) {
            long now = SystemClock.elapsedRealtime();
            if (now - lastBack > 2000) {
                lastBack = now;
                Toast.makeText(MainActivity.this, "Press back again to exit", Toast.LENGTH_SHORT).show();
                return;
            }
        }
        super.onBackPressed();
    }
}
JAVA
}

dex_it() {
  if command -v d8 >/dev/null 2>&1; then
    d8 --release --min-api 21 --lib "$ANDROID_JAR" --output "$PW/build" $(find "$PW/classes" -name '*.class')
  else
    dx --dex --min-sdk-version=21 --output="$PW/build/classes.dex" "$PW/classes"
  fi
  [ -f "$PW/build/classes.dex" ]
}

pack_apk() {
  local lvl=6; [ "$OPTIMIZE" = 1 ] && lvl=9
  (cd "$PW/build" && zip -q -"$lvl" base.apk classes.dex) || return 1
  if command -v zipalign >/dev/null 2>&1; then
    zipalign -f 4 "$PW/build/base.apk" "$PW/build/aligned.apk" && mv "$PW/build/aligned.apk" "$PW/build/base.apk"
  fi
}

# keystore password: random per install, stored in .ks_pass (legacy keystores keep "cioweb3")
ks_pass() {
  if [ -s "$KSPASS_FILE" ]; then cat "$KSPASS_FILE"; return; fi
  if [ -f "$KS" ]; then echo "cioweb3"; return; fi
  local p; p="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-24)"
  ( umask 077; printf '%s' "$p" > "$KSPASS_FILE" )
  echo "$p"
}

ks_pass_arg() { if [ -s "$KSPASS_FILE" ]; then echo "file:$KSPASS_FILE"; else echo "pass:cioweb3"; fi; }

ensure_keystore() {
  if [ ! -f "$KS" ]; then
    local pw; pw="$(ks_pass)"
    keytool -genkeypair -keystore "$KS" -alias cio -keyalg RSA -keysize 2048 \
      -validity 10000 -storepass "$pw" -keypass "$pw" -dname "CN=Cio-ID"
  fi
  [ -f "$KS" ]
}

sign_apk() {
  ensure_keystore || return 1
  local a; a="$(ks_pass_arg)"
  apksigner sign --ks "$KS" --ks-pass "$a" --key-pass "$a" --out "$OUT" "$PW/build/base.apk"
}

verify_apk() {
  apksigner verify --print-certs "$OUT" || return 1
  if command -v aapt >/dev/null 2>&1; then
    local got
    got="$(aapt dump badging "$OUT" 2>/dev/null | sed -n "s/^package: name='\([^']*\)'.*/\1/p")"
    echo "package in APK: ${got:-unknown}"
    if [ -n "$got" ] && [ "$got" != "$PACKAGE" ]; then echo "Package mismatch: expected $PACKAGE" >&2; return 1; fi
  fi
  return 0
}

fmt_size() { du -h "$1" 2>/dev/null | cut -f1; }
out_name() { local n="$PROJECT"; [ "$NAME_WITH_VER" = 1 ] && n="${PROJECT}_v${VERSION_NAME}"; printf '%s' "$n"; }

build() {
  build_run; local rc=$?; trap - INT
  if [ "$WAKE" = 1 ]; then termux-wake-unlock >/dev/null 2>&1; WAKE=0; fi
  return $rc
}

build_run() {
  banner; echo "${B} Build${N}"; hr
  validate_config || { echo "${R} Fix the errors above (menu: Edit config)${N}"; return 1; }
  if [ "$DRY" != 1 ]; then need_deps || return 1; fi
  check_url
  preflight_assets || return 1
  save_config

  PW="$BASE/projects/$PROJECT"
  PKGDIR="$PW/src/${PACKAGE//.//}"
  local OUTDIR
  if [ "$DRY" = 1 ]; then OUTDIR="$(get_outdir quiet)"; else OUTDIR="$(get_outdir)"; mkdir -p "$OUTDIR"; fi
  OUT="$OUTDIR/$(out_name).apk"
  if [ "$SHOW_CMD" = 1 ]; then echo "${D}  ⌁ $(equiv_cmd)${N}"; fi
  if [ "$DRY" = 1 ]; then echo "${Y}${B}  DRY RUN - showing the plan, nothing is built${N}"
  else rm -rf "$PW"; mkdir -p "$PW"; fi
  hr
  : > "$LOG"; : > "$STEPLOG"
  if [ "$DRY" != 1 ]; then
    find "$CACHE" -type f -mtime +7 -delete 2>/dev/null
    if command -v termux-wake-lock >/dev/null 2>&1; then termux-wake-lock >/dev/null 2>&1; WAKE=1; fi
  fi
  STEP_N=0; STEP_T=9; SLOW_T=0; SLOW_L=""; local T0=$SECONDS
  BAR_W=16; if [ "$(term_cols)" -lt 46 ]; then BAR_W=10; fi
  trap 'echo; echo "${Y}Build cancelled${N}"; [ -n "$CUR_PID" ] && kill "$CUR_PID" 2>/dev/null; command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock; exit 130' INT

  local dexcmd="dx --dex --min-sdk-version=21 --output=build/classes.dex classes"
  command -v d8 >/dev/null 2>&1 && dexcmd="d8 --release --min-api 21 --lib android.jar --output build classes/**/*.class"
  local dbg="-g"; [ "$OPTIMIZE" = 1 ] && dbg="-g:none"

  STEP_CMD="prep_assets   # icon x5 densities, loading screen" step "Prepare assets" prep_assets || return 1
  STEP_CMD="gen_project   # AndroidManifest.xml, MainActivity.java, styles.xml, strings.xml" step "Generate project files" gen_project || return 1
  step "Compile resources" aapt2 compile --dir "$PW/res" -o "$PW/build/res.zip" || return 1
  step "Link manifest & resources" aapt2 link -o "$PW/build/base.apk" -I "$ANDROID_JAR" \
      --manifest "$PW/AndroidManifest.xml" --min-sdk-version 21 --target-sdk-version 28 \
      --version-code "$VERSION_CODE" --version-name "$VERSION_NAME" "$PW/build/res.zip" || return 1
  step "Compile Java" ecj -source 1.8 -target 1.8 -nowarn "$dbg" -bootclasspath "$ANDROID_JAR" \
      -d "$PW/classes" "$PKGDIR/MainActivity.java" || return 1
  STEP_CMD="$dexcmd" step "Convert to DEX" dex_it || return 1
  STEP_CMD="zip -$([ "$OPTIMIZE" = 1 ] && echo 9 || echo 6) base.apk classes.dex && zipalign -f 4 base.apk" step "Pack & align APK" pack_apk || return 1
  STEP_CMD="apksigner sign --ks cio.keystore --ks-pass $( { [ ! -f "$KS" ] || [ -s "$KSPASS_FILE" ]; } && echo "file:.ks_pass" || echo "pass:***") --out $OUT base.apk" step "Sign APK" sign_apk || return 1
  STEP_CMD="apksigner verify --print-certs $OUT   # + package check" step "Verify APK" verify_apk || return 1
  trap - INT

  if [ "$DRY" = 1 ]; then
    hr; echo "${G}${B} ✔ Plan OK${N}  ${D}(output would be: $OUT)${N}"; return 0
  fi

  LAST_OUT="$OUT"
  local bytes prev delta="" d size
  size="$(fmt_size "$OUT")"
  bytes="$(stat -c%s "$OUT" 2>/dev/null)"
  prev="$(awk -F'|' -v p="$PROJECT" '$2==p && $6!=""{b=$6} END{print b}' "$HIST" 2>/dev/null)"
  if [[ "$prev" =~ ^[0-9]+$ ]] && [[ "$bytes" =~ ^[0-9]+$ ]]; then
    d=$(( (bytes-prev)/1024 ))
    if [ "$d" -gt 0 ]; then delta="(+${d} KB vs last build)"
    elif [ "$d" -lt 0 ]; then delta="(${d} KB vs last build)"
    else delta="(same size as last build)"; fi
  fi
  printf '%s|%s|%s|%s|%s|%s\n' "$(date '+%Y-%m-%d %H:%M')" "$PROJECT" "$PACKAGE" "$size" "$OUT" "$bytes" >> "$HIST"
  tail -n 50 "$HIST" > "$HIST.tmp" 2>/dev/null && mv "$HIST.tmp" "$HIST"
  save_config
  if command -v termux-media-scan >/dev/null 2>&1; then termux-media-scan "$OUT" >/dev/null 2>&1; fi
  if [ "$NOTIFY" = 1 ] && [ "$BATCH" != 1 ] && command -v termux-notification >/dev/null 2>&1; then
    termux-notification --title "CioWeb3Apk" --content "$PROJECT built ($size)" >/dev/null 2>&1 &
    command -v termux-vibrate >/dev/null 2>&1 && termux-vibrate -d 150 >/dev/null 2>&1 &
  fi
  if [ "$OPTIMIZE" = 1 ] && [ "$KEEP_SRC" != 1 ]; then rm -rf "$PW"; fi

  hr
  celebrate "$((SECONDS-T0))"
  echo "  File    : ${B}$OUT${N}"
  echo "  Size    : $size ${D}$delta${N}"
  echo "  Package : $PACKAGE  ${D}v$VERSION_NAME ($VERSION_CODE)${N}"
  [ -n "$SLOW_L" ] && echo "  ${D}Slowest step: $SLOW_L (${SLOW_T}s)${N}"
  hr
  if [ "$AUTO_SHARE" = 1 ]; then share_whatsapp "$OUT"
  elif [ "$ASSUME_YES" != 1 ] && [ "$BATCH" != 1 ] && ask_yn "Share to WhatsApp now?"; then share_whatsapp "$OUT"; fi
  if [ "$AUTO_INSTALL" = 1 ]; then install_apk "$OUT"
  elif [ "$ASSUME_YES" != 1 ] && [ "$BATCH" != 1 ] && ask_yn "Install now?"; then install_apk "$OUT"; fi
  if [ "$AUTO_UPLOAD" = 1 ] || [ "$CDN_AUTO" = 1 ]; then cdn_upload "$OUT" || true
  elif [ "$ASSUME_YES" != 1 ] && [ "$BATCH" != 1 ] && ask_yn "Upload to a temporary CDN link?"; then cdn_upload "$OUT" || true; fi
  return 0
}

# ───────────── actions ─────────────
share_whatsapp() {
  local f="${1:-$LAST_OUT}"
  [ -f "$f" ] || f="$(get_outdir quiet)/$(out_name).apk"
  [ -f "$f" ] || { bad "APK not found. Build first."; return 1; }
  if ! command -v termux-share >/dev/null 2>&1; then
    bad "termux-api not installed (also install the Termux:API app)"
    ask_yn "Install termux-api package now?" && pkg install -y termux-api
    command -v termux-share >/dev/null 2>&1 || return 1
  fi
  info "Opening share menu - choose WhatsApp"
  [ "$SHOW_CMD" = 1 ] && echo "${D}  \$ termux-share -a send -c application/vnd.android.package-archive $f${N}"
  termux-share -a send -c application/vnd.android.package-archive "$f"
}

install_apk() {
  local f="${1:-$LAST_OUT}"
  [ -f "$f" ] || f="$(get_outdir quiet)/$(out_name).apk"
  [ -f "$f" ] || { bad "APK not found. Build first."; return 1; }
  command -v termux-open >/dev/null 2>&1 || { bad "termux-open missing (pkg install termux-tools)"; return 1; }
  [ "$SHOW_CMD" = 1 ] && echo "${D}  \$ termux-open --view --content-type application/vnd.android.package-archive $f${N}"
  termux-open --view --content-type application/vnd.android.package-archive "$f"
}

list_apks() {
  banner; echo "${B} My APKs${N}"; hr
  if [ ! -s "$HIST" ]; then info "No builds yet."; return; fi
  local d p pk s f n=0
  while IFS='|' read -r d p pk s f _b; do
    n=$((n+1))
    if [ -f "$f" ]; then printf "  ${G}%2d${N} %-16s %-6s ${D}%s${N}\n     ${D}%s${N}\n" "$n" "$p" "$s" "$d" "$f"
    else printf "  ${R}%2d${N} %-16s ${D}(file deleted)${N}\n" "$n" "$p"; fi
  done < <(tail -n 15 "$HIST")
}

optimizer_clean() {
  banner; echo "${B} Optimizer - clean up${N}"; hr
  local before after f
  before="$(du -sk "$BASE" 2>/dev/null | cut -f1)"
  for f in projects .cache build.log; do
    if [ -e "$BASE/$f" ]; then printf "  %-12s %s\n" "$f" "$(du -sh "$BASE/$f" 2>/dev/null | cut -f1)"; fi
  done
  rm -rf "$BASE/projects" "$CACHE" "$LOG" "$BASE"/*.tmp
  if [ -f "$HIST" ]; then tail -n 50 "$HIST" > "$HIST.tmp" && mv "$HIST.tmp" "$HIST"; fi
  after="$(du -sk "$BASE" 2>/dev/null | cut -f1)"
  ok "Removed temp projects, cache and log"
  ok "Freed about $(( before - after )) KB"
  info "Kept: keystore, profiles, config, built APKs"
}

link_cmd() {
  local t="$PREFIX/bin/cioweb3apk"
  printf '#!%s/bin/bash\nexec bash %q "$@"\n' "$PREFIX" "$BASE/cioweb3apk.sh" > "$t" && chmod +x "$t" \
    && ok "Installed command: ${B}cioweb3apk${N}  (run it from anywhere)" \
    || bad "Could not create $t"
}

update_cmd() {
  ensure_tools git || return 1
  [ -d "$BASE/.git" ] || { bad "This folder is not a git clone (use: git clone <repo>)"; return 1; }
  echo "${D}  \$ git -C $BASE pull --ff-only${N}"
  git -C "$BASE" pull --ff-only && ok "Up to date. Restart the tool to use the new version."
}

# ───────────── profiles ─────────────
profile_file() { printf '%s/%s.conf' "$PROFILES" "$(printf '%s' "$1" | tr -c 'A-Za-z0-9_-' '_')"; }

profile_write_plain() { # plain KEY=value file (safe to share, never executed)
  local f="$1" v
  { echo "# cioweb3apk-profile v2"
    for v in "${CONFIG_VARS[@]}"; do
      [ "$v" = LAST_OUT ] && continue
      printf '%s=%s\n' "$v" "${!v//$'\n'/ }"
    done; } > "$f"
}

profile_read_plain() { # parse WITHOUT executing anything; only known keys accepted
  local line k v a allowed n=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    k="${line%%=*}"; v="${line#*=}"
    [[ "$k" =~ ^[A-Z_]+$ ]] || continue
    allowed=0
    for a in "${CONFIG_VARS[@]}"; do [ "$a" = "$k" ] && allowed=1; done
    [ "$k" = LAST_OUT ] && allowed=0
    [ "$allowed" = 1 ] || continue
    printf -v "$k" '%s' "${v:0:500}"; n=$((n+1))
  done < "$1"
  [ "$n" -gt 0 ]
}

sanitize_vars() { # force safe values (blocks arithmetic/code injection from edited files)
  local v
  for v in FULLSCREEN KEEP_ON ALLOW_DOWNLOAD ALLOW_UPLOAD SPLASH_FADE OPTIMIZE SHOW_CMD KEEP_SRC \
           PROGRESS_BAR ALLOW_ZOOM LOCK_DOMAIN EXIT_CONFIRM DESKTOP NAME_WITH_VER NOTIFY LIVE WEB_PERMS SECURE_MODE CDN_AUTO BANNER_ANIM BUILD_ANIM AUTO_TOOLS; do
    [[ "${!v}" =~ ^[01]$ ]] || printf -v "$v" '%s' 0
  done
  [[ "$SPLASH_MS" =~ ^[0-9]{1,5}$ ]] || SPLASH_MS=1500
  [[ "$VERSION_CODE" =~ ^[0-9]{1,9}$ ]] || VERSION_CODE=1
  case "$CDN_TTL" in 1h|12h|24h|72h) ;; *) CDN_TTL=24h ;; esac
  case "$CDN_HOST" in auto|litterbox|0x0|tmpfiles) ;; *) CDN_HOST=auto ;; esac
  case "$BANNER_STYLE" in auto|card|big|medium|mini|off) ;; *) BANNER_STYLE=auto ;; esac
  [[ "$WZ_DEPTH" =~ ^[1-3]$ ]] || WZ_DEPTH=2
  if ! { [[ "$WZ_MAXMB" =~ ^[0-9]{1,3}$ ]] && [ "$WZ_MAXMB" -ge 1 ] && [ "$WZ_MAXMB" -le 200 ]; }; then WZ_MAXMB=50; fi
  case "$THEME" in cyan|green|magenta|yellow|blue|mono) ;; *) THEME=cyan ;; esac
  return 0
}

profile_read_file() { # new format = safe parser; legacy (v3.0) = local file
  local f="$1"
  if head -n1 "$f" | grep -q '^# cioweb3apk-profile'; then profile_read_plain "$f" && sanitize_vars
  else source "$f"; sanitize_vars; fi
}

profile_save() {
  local name="$1" f
  [ -n "$name" ] || { bad "Usage: profile save NAME"; return 1; }
  mkdir -p "$PROFILES"; f="$(profile_file "$name")"
  profile_write_plain "$f"
  ok "Profile saved: $(basename "$f" .conf)"
}

profile_load() {
  local f; f="$(profile_file "$1")"
  [ -f "$f" ] || { bad "Profile not found: $1"; return 1; }
  profile_read_file "$f" || { bad "Profile is empty or corrupt: $1"; return 1; }
  ok "Profile loaded: $(basename "$f" .conf)"
}

profile_delete() {
  local f; f="$(profile_file "$1")"
  [ -f "$f" ] || { bad "Profile not found: $1"; return 1; }
  rm -f "$f"; ok "Profile deleted: $1"
}

profile_list() {
  local f n c=0
  mkdir -p "$PROFILES"
  for f in "$PROFILES"/*.conf; do
    [ -f "$f" ] || continue
    n="$(basename "$f" .conf)"
    ( profile_read_file "$f" >/dev/null 2>&1; printf "  ${G}•${N} %-14s %s ${D}%s${N}\n" "$n" "$APP_NAME" "$PACKAGE" )
    c=$((c+1))
  done
  if [ "$c" -eq 0 ]; then info "No profiles yet. Save one: profile save NAME"; fi
}

profile_export() {
  local f d dest; f="$(profile_file "$1")"
  [ -f "$f" ] || { bad "Profile not found: $1"; return 1; }
  d="$(get_outdir)"; dest="$d/$(basename "$f" .conf).cioprofile"
  ( profile_read_file "$f" >/dev/null 2>&1; profile_write_plain "$dest" )
  ok "Exported: $dest"
  info "Share this file, or upload it and import with: profile import <link>"
}

profile_import() { # profile_import PATH|LINK [NAME]
  local src="$1" name="$2" tmp="$CACHE/import.tmp" base
  [ -n "$src" ] || { bad "Usage: profile import PATH|LINK [NAME]"; return 1; }
  mkdir -p "$CACHE"
  if is_link "$src"; then
    fetch_url "$(normalize_link "$src")" "$tmp" || return 1
  else
    src="${src/#\~/$HOME}"; [ -f "$src" ] || { bad "File not found: $src"; return 1; }
    cp "$src" "$tmp"
  fi
  if [ "$(img_type "$tmp")" = html ]; then bad "That is a web page. Use the RAW file link."; return 1; fi
  if [ -z "$name" ]; then base="${src%%\?*}"; base="${base##*/}"; name="${base%.*}"; fi
  [ -n "$name" ] || name="imported"
  ( profile_read_plain "$tmp" && sanitize_vars && profile_save "$name" ) || { bad "Not a valid CioWeb3Apk profile file"; return 1; }
}

batch_cmd() {
  local f n okc=0 failc=0 results=()
  mkdir -p "$PROFILES"
  ls "$PROFILES"/*.conf >/dev/null 2>&1 || { info "No profiles. Create with: profile save NAME"; return 1; }
  BATCH=1
  for f in "$PROFILES"/*.conf; do
    n="$(basename "$f" .conf)"
    profile_read_file "$f" >/dev/null 2>&1
    echo; echo "${B}${M}▶ Profile: $n${N}"
    if build; then okc=$((okc+1)); results+=("${G}✔${N} $n  ${D}$OUT${N}")
    else failc=$((failc+1)); results+=("${R}✘${N} $n"); fi
  done
  BATCH=0
  load_config
  echo; hr; echo "${B} Batch result: ${G}$okc ok${N}, ${R}$failc failed${N}"
  for f in "${results[@]}"; do echo "  $f"; done
  [ "$failc" -eq 0 ]
}

# ───────────── extra tools ─────────────
keystore_cmd() {
  banner; echo "${B} Keystore${N}"; hr
  if [ ! -f "$KS" ]; then info "No keystore yet - it is created on first build."; return 0; fi
  case "$SUB" in
    backup)
      local d; d="$(get_outdir)/cioweb3apk-keystore-backup"; mkdir -p "$d"
      cp "$KS" "$d/"
      if [ -f "$KSPASS_FILE" ]; then cp "$KSPASS_FILE" "$d/ks_pass.txt"; fi
      ok "Backup saved: $d"
      warn "Keep it private. Anyone with these files can sign updates of your apps." ;;
    *)
      keytool -list -v -keystore "$KS" -storepass "$(ks_pass)" 2>/dev/null | grep -E "Alias name|Owner|Valid|SHA256" | sed 's/^/  /'
      info "Backup: cioweb3apk keystore backup  (needed to update your apps later)" ;;
  esac
}

apk_info() {
  local f="${1:-$LAST_OUT}"
  [ -f "$f" ] || f="$(get_outdir quiet)/$(out_name).apk"
  [ -f "$f" ] || { bad "APK not found. Build first."; return 1; }
  banner; echo "${B} APK info & verify${N}"; hr
  printf "  %-9s %s\n" "File" "$f" "Size" "$(fmt_size "$f")"
  command -v sha256sum >/dev/null 2>&1 && printf "  %-9s %s\n" "SHA-256" "$(sha256sum "$f" | cut -d' ' -f1)"
  if command -v aapt >/dev/null 2>&1; then
    aapt dump badging "$f" 2>/dev/null | sed -n "s/^package: name='\([^']*\)' versionCode='\([^']*\)' versionName='\([^']*\)'.*/  Package   \1\n  Version   \3 (\2)/p; s/^application-label:'\(.*\)'/  Label     \1/p; s/^sdkVersion:'\(.*\)'/  Min SDK   \1/p"
  fi
  if command -v apksigner >/dev/null 2>&1; then
    if apksigner verify "$f" >/dev/null 2>&1; then ok "Signature valid"; else bad "Signature INVALID"; fi
  fi
}

serve_cmd() {
  local f="$LAST_OUT" py="" addr url tmp="$CACHE/serve" port=8080
  [ -f "$f" ] || f="$(get_outdir quiet)/$(out_name).apk"
  [ -f "$f" ] || { bad "APK not found. Build first."; return 1; }
  ensure_tools serve || return 1
  command -v python3 >/dev/null 2>&1 && py=python3
  command -v python  >/dev/null 2>&1 && py=python
  if [ -z "$py" ]; then
    bad "python missing"
    ask_yn "Install python now?" && pkg install -y python
    command -v python >/dev/null 2>&1 && py=python
    [ -n "$py" ] || return 1
  fi
  rm -rf "$tmp"; mkdir -p "$tmp"; cp "$f" "$tmp/"
  while (echo >"/dev/tcp/127.0.0.1/$port") 2>/dev/null && [ "$port" -lt 8100 ]; do port=$((port+1)); done
  addr="$(ip -4 addr show wlan0 2>/dev/null | awk '/inet /{sub(/\/.*/,"",$2); print $2; exit}')"
  [ -n "$addr" ] || addr="$(ifconfig 2>/dev/null | awk '/inet / && $2!="127.0.0.1"{print $2; exit}')"
  [ -n "$addr" ] || addr="<phone-ip>"
  url="http://$addr:$port/$(basename "$f")"
  banner; echo "${B} Share over Wi-Fi${N}"; hr
  echo "  Open on another device (same Wi-Fi):"
  echo "  ${G}${B}$url${N}"
  if command -v qrencode >/dev/null 2>&1; then qrencode -t ANSIUTF8 "$url"; else info "pkg install qrencode  → shows a QR code here"; fi
  info "Only this APK is shared. Press Ctrl+C to stop."
  echo "${D}  \$ $py -m http.server $port --bind 0.0.0.0   (folder: .cache/serve)${N}"
  trap ':' INT
  (cd "$tmp" && "$py" -m http.server "$port" --bind 0.0.0.0)
  trap - INT
  rm -rf "$tmp"
}

# ───────────── auto-fill from website ─────────────
origin_of() { local rest="${1#*://}"; printf '%s://%s' "${1%%://*}" "${rest%%[/?#]*}"; }

abs_url() { # abs_url HREF BASEURL
  local h="$1" base="$2" o path dir
  o="$(origin_of "$base")"
  case "$h" in
    http://*|https://*) printf '%s' "$h" ;;
    //*) printf 'https:%s' "$h" ;;
    /*) printf '%s%s' "$o" "$h" ;;
    *) path="${base#$o}"; path="${path%%[?#]*}"; dir="$o${path%/*}"; printf '%s/%s' "$dir" "$h" ;;
  esac
}

html_attr() { # html_attr TAG ATTR
  printf '%s' "$1" | sed -nE "s/.*[[:space:]]$2=[\"']([^\"']*)[\"'].*/\1/Ip" | head -1
}

AF_TITLE=""; AF_COLOR=""; AF_ICONS=()
autofill_parse() { # autofill_parse HTMLFILE BASEURL -> AF_TITLE AF_COLOR AF_ICONS
  local f="$1" base="$2" flat tags tag rel href t sq="'" dq='"'
  local -a apple=() icons=()
  flat="$(tr '\n\r\t' '   ' < "$f")"
  t="$(printf '%s' "$flat" | sed -nE 's/.*<title[^>]*>([^<]*)<\/title>.*/\1/Ip' | head -1)"
  t="${t//&amp;/&}"; t="${t//&#39;/$sq}"; t="${t//&quot;/$dq}"; t="${t//&nbsp;/ }"
  t="$(printf '%s' "$t" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g')"
  t="${t%% | *}"; t="${t%% - *}"; t="${t%% – *}"; t="${t%% — *}"
  AF_TITLE="${t:0:30}"
  tags="$(printf '%s' "$flat" | grep -oiE '<link[^>]*>')"
  while IFS= read -r tag; do
    [ -n "$tag" ] || continue
    rel="$(html_attr "$tag" rel)"; rel="${rel,,}"; href="$(html_attr "$tag" href)"
    [ -n "$href" ] || continue
    href="${href//&amp;/&}"
    case "$rel" in
      *apple-touch-icon*) apple+=("$(abs_url "$href" "$base")") ;;
      *icon*) case "${href,,}" in *.svg|*.svg\?*) ;; *) icons+=("$(abs_url "$href" "$base")") ;; esac ;;
    esac
  done <<< "$tags"
  AF_ICONS=("${apple[@]}" "${icons[@]}" "$(origin_of "$base")/favicon.ico")
  tag="$(printf '%s' "$flat" | grep -oiE '<meta[^>]*name=.theme-color.[^>]*>' | head -1)"
  AF_COLOR="$(html_attr "$tag" content)"
}

pkg_from_url() {
  local h="${1#*://}" name n suf
  local hostsuf=" vercel.app netlify.app github.io gitlab.io pages.dev web.app firebaseapp.com herokuapp.com onrender.com glitch.me repl.co replit.app replit.dev workers.dev surge.sh fly.dev railway.app azurewebsites.net blogspot.com wordpress.com wixsite.com weebly.com ngrok.io ngrok-free.app trycloudflare.com loca.lt deno.dev koyeb.app appspot.com "
  h="${h%%/*}"; h="${h%%:*}"; h="${h#www.}"; h="${h,,}"
  local -a L; IFS=. read -r -a L <<< "$h"
  n=${#L[@]}
  if [ "$n" -ge 3 ] && [ ${#L[n-1]} -eq 2 ] && [[ " co com net org ac go or web my sch " == *" ${L[n-2]} "* ]]; then name="${L[n-3]}"
  elif [ "$n" -ge 2 ]; then name="${L[n-2]}"
  else name="${L[0]}"; fi
  for suf in $hostsuf; do
    if [[ "$h" == *".$suf" ]]; then name="${h%".$suf"}"; name="${name##*.}"; break; fi
  done
  [[ "$h" =~ ^[0-9.]+$ ]] && name=""
  name="$(printf '%s' "$name" | tr -cd 'a-z0-9')"
  [ -n "$name" ] || name="webapp"
  [[ "$name" =~ ^[0-9] ]] && name="app$name"
  [[ "$JAVA_KW" == *" $name "* ]] && name="${name}app"
  printf 'com.%s.app' "$name"
}

autofill_cmd() { # autofill_cmd URL -> fills name, package, project, icon, color from the site
  local u="${1:-$URL}" f="$CACHE/site.html" pj cand c found=0
  [[ "$u" =~ ^https?:// ]] || u="https://$u"
  ensure_tools core || return 1
  mkdir -p "$CACHE"
  banner; echo "${B} Auto-fill from website${N}"; hr
  info "Reading $u"
  if [ "$SHOW_CMD" = 1 ]; then echo "${D}  \$ curl -sL -m 15 $u${N}"; fi
  if ! curl -sL -m 15 -A "$UA_STR" -o "$f" "$u"; then bad "Cannot open the website (check URL / internet)"; return 1; fi
  autofill_parse "$f" "$u"
  URL="$u"; ok "URL: $URL"
  if [ -n "$AF_TITLE" ]; then APP_NAME="$AF_TITLE"; ok "App name: $APP_NAME"; else warn "No <title> found, keeping: $APP_NAME"; fi
  PACKAGE="$(pkg_from_url "$u")"; ok "Package: $PACKAGE"
  pj="$(printf '%s' "$APP_NAME" | tr -c 'A-Za-z0-9' '_' | sed -E 's/_+/_/g; s/^_//; s/_$//')"
  if [ -n "$pj" ]; then PROJECT="$pj"; ok "Project: $PROJECT"; fi
  c="$(norm_color "$AF_COLOR")"
  if [[ "$c" =~ ^#[0-9A-F]{6}$ ]]; then COLOR="$(darken "$c" 12)"; ok "ColorPrimaryDark: $COLOR ${D}(site theme-color $c)${N}"
  else warn "No theme-color on the site, keeping $COLOR"; fi
  REFRESH=1
  for cand in "${AF_ICONS[@]}"; do
    [ -n "$cand" ] || continue
    info "Trying icon: ${D}$cand${N}"
    if icon_check "$cand"; then ICON="$cand"; found=1; break; fi
  done
  REFRESH=0
  if [ "$found" = 1 ]; then ok "Icon set"; else warn "No usable icon found. Set one: icon set <link>"; fi
  hr; info "Next: ${B}cioweb3apk build${N}  (or edit with: config)"
}

# ───────────── temporary CDN upload ─────────────
CDN_EP_LITTERBOX="${CDN_EP_LITTERBOX:-https://litterbox.catbox.moe/resources/internals/api.php}"
CDN_EP_0X0="${CDN_EP_0X0:-https://0x0.st}"
CDN_EP_TMPFILES="${CDN_EP_TMPFILES:-https://tmpfiles.org/api/v1/upload}"
CDN_URL=""

ttl_hours() { case "$CDN_TTL" in 1h) echo 1 ;; 12h) echo 12 ;; 72h) echo 72 ;; *) echo 24 ;; esac; }
cdn_endpoint() { case "$1" in litterbox) echo "$CDN_EP_LITTERBOX" ;; 0x0) echo "$CDN_EP_0X0" ;; tmpfiles) echo "$CDN_EP_TMPFILES" ;; esac; }

cdn_try() { # cdn_try HOST FILE -> prints the download URL on success
  local h="$1" f="$2" out mime="type=application/vnd.android.package-archive"
  mkdir -p "$CACHE"
  case "$f" in *.zip) mime="type=application/zip" ;; esac
  case "$h" in
    litterbox) out="$(curl -sS -m 600 -A "$UA_STR" -F "reqtype=fileupload" -F "time=$CDN_TTL" -F "fileToUpload=@${f};$mime" "$CDN_EP_LITTERBOX" 2>&1)" ;;
    0x0)       out="$(curl -sS -m 600 -A "$UA_STR" -F "file=@${f};$mime" -F "expires=$(ttl_hours)" "$CDN_EP_0X0" 2>&1)" ;;
    tmpfiles)  out="$(curl -sS -m 600 -A "$UA_STR" -F "file=@${f};$mime" "$CDN_EP_TMPFILES" 2>&1)"
               out="$(printf '%s' "$out" | sed -nE 's/.*"url"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1 \
                      | sed 's#\\/#/#g; /tmpfiles.org\/dl\//!s#tmpfiles.org/#tmpfiles.org/dl/#; s#^http://tmpfiles#https://tmpfiles#')" ;;
    *) return 1 ;;
  esac
  out="$(printf '%s' "$out" | tr -d '\r' | head -n1)"
  if [[ "$out" =~ ^https?://[^[:space:]]+$ ]]; then printf '%s' "$out"; return 0; fi
  printf '%s' "${out:0:200}" > "$CACHE/.cdnerr"
  return 1
}

cdn_upload() { # cdn_upload [FILE] -> uploads to a temporary file host, prints link
  local f="${1:-$LAST_OUT}" hosts h url="" name exp
  [ -f "$f" ] || f="$(get_outdir quiet)/$(out_name).apk"
  [ -f "$f" ] || { bad "APK not found. Build first."; return 1; }
  ensure_tools core || return 1
  name="$(basename "$f")"
  hr; echo "${B} Upload to temporary CDN${N}  ${D}$name ($(fmt_size "$f"))${N}"
  if [ "$CDN_HOST" = auto ]; then hosts="litterbox 0x0 tmpfiles"; else hosts="$CDN_HOST"; fi
  for h in $hosts; do
    info "Uploading via ${B}$h${N} ${D}(expires $CDN_TTL)${N}"
    if [ "$SHOW_CMD" = 1 ]; then echo "${D}  \$ curl -F file=@$name $(cdn_endpoint "$h")${N}"; fi
    rm -f "$CACHE/.cdnerr"
    if url="$(cdn_try "$h" "$f")"; then break; fi
    url=""; warn "$h failed: $(head -c 80 "$CACHE/.cdnerr" 2>/dev/null)"
  done
  if [ -z "$url" ]; then bad "Upload failed on all hosts. Check internet, then retry: cioweb3apk upload"; return 1; fi
  CDN_URL="$url"
  exp=$(( $(date +%s) + $(ttl_hours) * 3600 ))
  printf '%s|%s|%s|%s|%s\n' "$(date '+%Y-%m-%d %H:%M')" "$name" "$CDN_TTL" "$url" "$exp" >> "$LINKS"
  tail -n 30 "$LINKS" > "$LINKS.tmp" 2>/dev/null && mv "$LINKS.tmp" "$LINKS"
  echo; ok "Uploaded! Download link:"
  echo "    ${G}${B}$url${N}"
  info "Expires in about ${B}$CDN_TTL${N}. Anyone with the link can download - share carefully."
  if command -v termux-clipboard-set >/dev/null 2>&1; then printf '%s' "$url" | termux-clipboard-set 2>/dev/null && ok "Link copied to clipboard"; fi
  if command -v qrencode >/dev/null 2>&1; then qrencode -t ANSIUTF8 "$url"; fi
  if [ "$ASSUME_YES" != 1 ] && [ "$BATCH" != 1 ] && command -v termux-share >/dev/null 2>&1 && ask_yn "Send the link via WhatsApp/other app?"; then
    printf '%s' "Download $name: $url" | termux-share -a send -c text/plain
  fi
  return 0
}

cdn_cmd() { cdn_upload "$SUB"; }

links_cmd() {
  banner; echo "${B} My CDN links${N}"; hr
  if [ ! -s "$LINKS" ]; then info "No uploads yet. Run: cioweb3apk upload"; return 0; fi
  local d n t u e st now i=0
  now=$(date +%s)
  while IFS='|' read -r d n t u e; do
    i=$((i+1))
    if ! [[ "$e" =~ ^[0-9]+$ ]]; then st="${Y}unknown${N}"
    elif [ "$now" -gt "$e" ]; then st="${R}expired${N}"
    else st="${G}active${N} ${D}(~$(( (e-now)/3600 ))h left)${N}"; fi
    printf "  %2d. %-18s %s ${D}[%s]${N}\n      %s\n      ${D}%s${N}\n" "$i" "$n" "$st" "$t" "$u" "$d"
  done < <(tail -n 10 "$LINKS")
}

selftest() { # verify every function the menus/commands rely on really exists
  local f miss=0
  banner; echo "${B} Self-test${N}"; hr
  for f in menu features_menu options_menu profiles_menu tools_menu set_config build build_run doctor need_deps \
           autofill_cmd icon_cmd icon_check icon_wizard profile_save profile_load profile_import profile_export batch_cmd \
           serve_cmd apk_info keystore_cmd log_cmd show_help optimizer_clean share_whatsapp install_apk list_apks \
           update_cmd link_cmd cdn_upload links_cmd jar_cmd banner_full banner_compact_line grad_rule logo_rows info_bar banner_card card_row tab spin_wait spin_run gbar celebrate ensure_tools ensure_jar setup_all key_get social_cmd social_menu webzip_cmd webzip_menu keys_cmd find_android_jar valid_jar dispatch parse_opts step hr bar; do
    if declare -F "$f" >/dev/null; then :; else bad "missing function: $f"; miss=$((miss+1)); fi
  done
  if [ "$miss" -eq 0 ]; then ok "All functions present"; fi
  if [ "$(repeat_str '─' 3)" = "───" ]; then ok "Line glyphs OK"; else bad "Glyph rendering problem"; miss=$((miss+1)); fi
  hr; return $miss
}

# ───────────── last build log ─────────────
log_cmd() {
  banner; echo "${B} Last build - steps & commands${N}"; hr
  if [ ! -s "$STEPLOG" ]; then info "No build yet. Run: build"; return 0; fi
  local label shown st secs mark n=0
  while IFS='|' read -r label shown st secs; do
    n=$((n+1))
    if [ "$st" = ok ]; then mark="${G}✔${N}"; else mark="${R}✘${N}"; fi
    printf "  %s %d. %-26s ${D}%ss${N}\n" "$mark" "$n" "$label" "$secs"
    echo "${D}       \$ ${shown:0:100}${N}"
  done < "$STEPLOG"
  hr; info "Full output: $LOG   (cioweb3apk log full)"
  if [ "$SUB" = full ] && [ -f "$LOG" ]; then hr; cat "$LOG"; fi
}

# ───────────── social profile lookup (official / public APIs) ─────────────
py_bin() { if command -v python3 >/dev/null 2>&1; then echo python3; else echo python; fi; }

social_cmd() { # social USER [platforms] | social list
  local user="${SUB:-}" only="${SOC_ONLY:-$ARG}" py out err path rc
  local -a args
  ensure_tools social || return 1
  py="$(py_bin)"
  [ -f "$BASE/tools/social.py" ] || { bad "tools/social.py is missing - run: cioweb3apk update"; return 1; }
  if [ "$user" = list ]; then "$py" "$BASE/tools/social.py" --list; return 0; fi
  if [ -z "$user" ]; then bad "Usage: social USERNAME [github,bluesky,...]    (platform list: social list)"; return 1; fi
  [[ "$user" =~ ^@?[A-Za-z0-9][A-Za-z0-9._-]{0,63}(@[A-Za-z0-9.:-]{1,100})?$ ]] || { bad "Invalid username"; return 1; }
  if [ "$SOC_JSON" != 1 ]; then
    banner; echo "${B} Social profile lookup${N}"; hr
    info "Public data only, via official/public APIs. Use responsibly."
  fi
  mkdir -p "$CACHE"; out="$CACHE/social.out"; err="$CACHE/social.err"; : > "$out"; : > "$err"
  args=("$BASE/tools/social.py" "$user" --color "${GRAD[1]}")
  if [ -n "$only" ]; then args+=(--only "$only"); fi
  if [ "$SOC_JSON" = 1 ]; then args+=(--json); fi
  if [ "$USE_COLOR" != 1 ]; then args+=(--plain); fi
  if [ "$SOC_SAVE" = 1 ]; then path="$(get_outdir)/social_${user//[^A-Za-z0-9._-]/_}.txt"; args+=(--save "$path"); fi
  if [ "$SHOW_CMD" = 1 ] && [ "$SOC_JSON" != 1 ]; then echo "${D}  \$ $py tools/social.py ${args[*]:1}${N}"; fi
  ( YT_API_KEY="$(key_get YT_API_KEY)"; GITHUB_TOKEN="$(key_get GITHUB_TOKEN)"; export YT_API_KEY GITHUB_TOKEN
    exec "$py" "${args[@]}" > "$out" 2> "$err" ) &
  CUR_PID=$!
  if anim_on && [ "$SOC_JSON" != 1 ]; then spin_wait "$CUR_PID" "Looking up @${user#@} on public APIs"; rc=$?; printf '\r\033[K'
  else wait "$CUR_PID"; rc=$?; fi
  CUR_PID=""
  cat "$out"
  if [ -s "$err" ]; then warn "$(head -n1 "$err")"; fi
  return 0
}

social_menu() {
  local u p
  banner; echo "${B} Social profile lookup${N}"; hr
  echo "  ${D}Official/public APIs only · public data · one-shot lookup${N}"
  echo "  ${D}GitHub GitLab Bluesky Mastodon Reddit HackerNews StackOverflow Lichess Chess.com DEV YouTube${N}"
  read -r -p "${Y}Username${N} ${D}(e.g. torvalds or user@mastodon.social)${N}: " u
  [ -z "$u" ] && return 0
  read -r -p "${Y}Platforms${N} ${D}[Enter = all, or e.g. github,bluesky]${N}: " p
  SUB="$u"; ARG="$p"; SOC_ONLY=""
  if ask_yn "Save the report to Download?"; then SOC_SAVE=1; fi
  social_cmd; SOC_SAVE=0
}

# ───────────── website / repo -> ZIP ─────────────
WZ_WORK=""
wz_status() {
  local n sz
  n="$(find "$WZ_WORK/site" -type f 2>/dev/null | wc -l | tr -d ' ')"
  sz="$(du -sk "$WZ_WORK/site" 2>/dev/null | cut -f1)"
  printf '%s files · %s MB' "$n" "$(( ${sz:-0} / 1024 ))"
}
private_host() { # localhost / private networks are never mirrored
  local h="${1,,}"
  [[ "$h" == localhost || "$h" == *.local || "$h" == *.internal || "$h" == *.lan ]] && return 0
  [[ "$h" =~ ^(127\.|10\.|192\.168\.|169\.254\.|0\.|172\.(1[6-9]|2[0-9]|3[01])\.) ]] && return 0
  [[ "$h" =~ ^\[?(::1|fc|fd|fe80) ]] && return 0
  return 1
}
urlenc() { "$(py_bin)" -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }
wz_fetch() { # wz_fetch URL OUT [curl args...]  (size-capped)
  local u="$1" o="$2"; shift 2
  curl -fL -m 900 --max-filesize $(( WZ_MAXMB * 1048576 )) -A "$UA_STR" "$@" -o "$o" "$u"
}

webzip_cmd() { # webzip URL  -> ZIP in Download (GitHub/GitLab: official archive API, other sites: polite mirror)
  local url="${SUB:-}" host rest work outdir stamp wlog zipname outzip safe files size ec api ref o r p
  local pyb snap hfile tok mode
  if [ -z "$url" ]; then bad "Usage: webzip URL [--depth 1-3] [--max-mb N] [--wayback] [--out NAME] [--upload] [--share]"; return 1; fi
  [[ "$url" =~ ^https?:// ]] || url="https://$url"
  [[ "$url" =~ ^https?://[^[:space:]\"\<\>\\]+$ ]] || { bad "Invalid URL"; return 1; }
  host="${url#*://}"; host="${host%%/*}"; host="${host%%:*}"; host="${host,,}"
  if [ "$WZ_ALLOW_LOCAL" != 1 ] && private_host "$host"; then bad "Local / private network addresses are not allowed"; return 1; fi
  ensure_tools webzip || return 1
  pyb="$(py_bin)"
  banner; echo "${B} Website → ZIP${N}"; hr
  outdir="$(get_outdir)"; mkdir -p "$outdir"
  stamp="$(date +%Y%m%d-%H%M%S)"; work="$CACHE/webzip/$stamp"; WZ_WORK="$work"
  rm -rf "$work"; mkdir -p "$work/site"; wlog="$work/webzip.log"; : > "$wlog"
  safe="${WZ_OUT//[^A-Za-z0-9._-]/_}"
  hfile="$work/h.txt"; : > "$hfile"; chmod 600 "$hfile"
  mode="mirror"
  local re_gh='^https?://(www\.)?github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)(/tree/([A-Za-z0-9_.-]+))?(/.*)?$'
  if [ "$WZ_WAYBACK" = 1 ]; then mode="wayback"
  elif [[ "$url" =~ $re_gh ]]; then mode="github"
  elif [[ "$host" == gitlab.com || "$host" == www.gitlab.com ]]; then mode="gitlab"; fi

  case "$mode" in
    github)
      o="${BASH_REMATCH[2]}"; r="${BASH_REMATCH[3]%.git}"; ref="${BASH_REMATCH[5]}"
      api="${CIO_GITHUB_API:-https://api.github.com}/repos/$o/$r/zipball"; [ -n "$ref" ] && api="$api/$ref"
      printf 'Accept: application/vnd.github+json\n' > "$hfile"
      tok="$(key_get GITHUB_TOKEN)"; if [ -n "$tok" ]; then printf 'Authorization: Bearer %s\n' "$tok" >> "$hfile"; fi
      zipname="${safe:-$o-$r${ref:+-$ref}}"; [[ "$zipname" == *.zip ]] || zipname+=".zip"; outzip="$outdir/$zipname"
      info "GitHub repo ${B}$o/$r${N} ${D}${ref:+(branch $ref) }via the official GitHub API${N}"
      if [ "$SHOW_CMD" = 1 ]; then echo "${D}  \$ curl -fL $api -o $zipname${N}"; fi
      SPIN_LOG="$wlog" spin_run "Downloading repository ZIP" wz_fetch "$api" "$outzip" -H "@$hfile" \
        || { bad "Download failed (private repo, wrong name, rate limit, or bigger than ${WZ_MAXMB} MB)"; rm -f "$outzip"; return 1; } ;;
    gitlab)
      p="${url#*gitlab.com/}"; ref=""
      if [[ "$p" == *"/-/tree/"* ]]; then ref="${p#*/-/tree/}"; ref="${ref%%/*}"; fi
      p="${p%%/-/*}"; p="${p%%\?*}"; p="${p%/}"; p="${p%.git}"
      [[ "$p" == */* ]] || { bad "Use a project URL like gitlab.com/group/project"; return 1; }
      api="${CIO_GITLAB:-https://gitlab.com}/api/v4/projects/${p//\//%2F}/repository/archive.zip"; [ -n "$ref" ] && api="$api?sha=$ref"
      zipname="${safe:-${p//\//-}${ref:+-$ref}}"; [[ "$zipname" == *.zip ]] || zipname+=".zip"; outzip="$outdir/$zipname"
      info "GitLab project ${B}$p${N} ${D}via the official GitLab API${N}"
      if [ "$SHOW_CMD" = 1 ]; then echo "${D}  \$ curl -fL $api -o $zipname${N}"; fi
      SPIN_LOG="$wlog" spin_run "Downloading project ZIP" wz_fetch "$api" "$outzip" \
        || { bad "Download failed (private project, wrong name, or bigger than ${WZ_MAXMB} MB)"; rm -f "$outzip"; return 1; } ;;
    wayback)
      snap="$(curl -fsSL -m 20 -A "$UA_STR" "${CIO_WAYBACK:-https://archive.org}/wayback/available?url=$(urlenc "$url")" 2>>"$wlog" \
        | "$pyb" -c 'import sys,json; d=json.load(sys.stdin); c=d.get("archived_snapshots",{}).get("closest",{}); print(c.get("url","") if c.get("available") else "")' 2>>"$wlog")"
      [ -n "$snap" ] || { bad "No archived copy found in the Internet Archive (Wayback Machine)"; return 1; }
      snap="$(printf '%s' "$snap" | sed -E 's#^http://web\.archive\.org#https://web.archive.org#; s#(/web/[0-9]+)/#\1id_/#')"
      info "Closest archived copy: ${D}$snap${N}"
      zipname="${safe:-${host//[^A-Za-z0-9.-]/_}-wayback}"; [[ "$zipname" == *.zip ]] || zipname+=".zip"; outzip="$outdir/$zipname"
      SPIN_LOG="$wlog" spin_run "Downloading archived page" wz_fetch "$snap" "$work/site/index.html" \
        || { bad "Could not download the archived copy"; return 1; }
      printf 'Source: %s\nSnapshot: %s\nDate: %s\nTool: CioWeb3Apk v%s (Internet Archive public API)\nNote: single page only.\n' "$url" "$snap" "$(date '+%F %T')" "$VERSION" > "$work/site/_ARCHIVE_INFO.txt"
      SPIN_LOG="$wlog" spin_run "Compressing ZIP" bash -c 'cd "$1" && zip -qr -9 "$2" .' _ "$work/site" "$outzip" || { bad "zip failed"; return 1; } ;;
    *)
      warn "Only copy sites you own or have permission to archive. robots.txt is respected."
      if ! ask_yn "I own this site or have permission - continue?"; then
        if [ "$ASSUME_YES" != 1 ]; then info "Cancelled. (Non-interactive use: add --yes to confirm permission.)"; fi
        rm -rf "$work"; return 1
      fi
      zipname="${safe:-${host//[^A-Za-z0-9.-]/_}_$stamp}"; [[ "$zipname" == *.zip ]] || zipname+=".zip"; outzip="$outdir/$zipname"
      info "Mirroring ${B}$host${N} ${D}(depth $WZ_DEPTH, max ${WZ_MAXMB} MB, polite: 0.5s delay)${N}"
      if [ "$SHOW_CMD" = 1 ]; then echo "${D}  \$ wget --recursive --level=$WZ_DEPTH --no-parent --page-requisites --convert-links --adjust-extension --domains=$host --wait=0.5 --quota=${WZ_MAXMB}m -e robots=on $url${N}"; fi
      ( cd "$work/site" && exec timeout 900 wget --recursive --level="$WZ_DEPTH" --no-parent --page-requisites \
          --convert-links --adjust-extension --restrict-file-names=windows --no-host-directories \
          --domains="$host" --wait=0.5 --random-wait --timeout=15 --tries=2 --quota="${WZ_MAXMB}m" \
          -e robots=on --user-agent="$UA_STR" --no-verbose "$url" ) >> "$wlog" 2>&1 &
      CUR_PID=$!
      if anim_on; then spin_wait "$CUR_PID" "Mirroring $host" "" "" wz_status; ec=$?; printf '\r\033[K'
      else wait "$CUR_PID"; ec=$?; fi
      CUR_PID=""
      files="$(find "$work/site" -type f 2>/dev/null | wc -l | tr -d ' ')"
      if [ "${files:-0}" -eq 0 ]; then
        bad "Nothing downloaded (blocked by robots.txt, needs login/JavaScript, or the server refused)"
        tail -n 4 "$wlog" 2>/dev/null | sed 's/^/    /'
        info "Try the Internet Archive copy instead: ${B}cioweb3apk webzip $url --wayback${N}"
        rm -rf "$work"; return 1
      fi
      [ "$ec" -ne 0 ] && warn "wget finished with code $ec (some pages were skipped - normal for 404s / size limit)"
      printf 'Source: %s\nDate: %s\nTool: CioWeb3Apk v%s (wget mirror, robots.txt respected)\nNote: copy for personal/offline use - respect the owner copyright and license.\n' "$url" "$(date '+%F %T')" "$VERSION" > "$work/site/_ARCHIVE_INFO.txt"
      SPIN_LOG="$wlog" spin_run "Compressing ZIP" bash -c 'cd "$1" && zip -qr -9 "$2" .' _ "$work/site" "$outzip" || { bad "zip failed"; return 1; } ;;
  esac

  [ -s "$outzip" ] || { bad "ZIP was not created"; return 1; }
  size="$(fmt_size "$outzip")"
  files="$(unzip -l "$outzip" 2>/dev/null | tail -n1 | awk '{print $2}')"
  if command -v termux-media-scan >/dev/null 2>&1; then termux-media-scan "$outzip" >/dev/null 2>&1; fi
  hr; ok "ZIP ready: ${B}$outzip${N}"; info "Size $size · ${files:-?} files"
  LAST_ZIP="$outzip"
  if [ "$AUTO_UPLOAD" = 1 ]; then cdn_upload "$outzip" || true
  elif [ "$ASSUME_YES" != 1 ] && [ "$BATCH" != 1 ] && ask_yn "Upload to a temporary CDN link?"; then cdn_upload "$outzip" || true; fi
  if [ "$AUTO_SHARE" = 1 ]; then ensure_tools share && termux-share -a send -c application/zip "$outzip"; fi
  rm -rf "$work"
  return 0
}

webzip_menu() {
  local u d m
  banner; echo "${B} Website → ZIP${N}"; hr
  echo "  ${D}GitHub / GitLab repos use the official archive API.${N}"
  echo "  ${D}Other sites are mirrored politely (robots.txt respected).${N}"
  read -r -p "${Y}URL${N}: " u
  [ -z "$u" ] && return 0
  read -r -p "${Y}Depth 1-3${N} ${D}[$WZ_DEPTH]${N}: " d
  if [[ "$d" =~ ^[1-3]$ ]]; then WZ_DEPTH="$d"; fi
  read -r -p "${Y}Max size MB${N} ${D}[$WZ_MAXMB]${N}: " m
  if [[ "$m" =~ ^[0-9]{1,3}$ ]]; then WZ_MAXMB="$m"; fi
  sanitize_vars; save_config
  SUB="$u"; ARG=""; webzip_cmd
}

# ───────────── help ─────────────
show_help() {
  banner; echo "${B} Quick start${N}"; hr
  cat << HELP_EOF
  ${D}1.${N} cioweb3apk doctor --fix           ${D}install needed tools${N}
  ${D}2.${N} cioweb3apk auto https://site.com  ${D}fill name/icon/color${N}
  ${D}3.${N} cioweb3apk icon set <image link>  ${D}direct image link${N}
  ${D}4.${N} cioweb3apk build --share          ${D}build + WhatsApp${N}

${B} Build${N}
  ${G}build${N} [profile]   ${G}dry${N} [profile]   ${G}batch${N}   ${G}config${N}  ${G}features${N}  ${G}options${N}
${B} Icon & site${N}
  ${G}auto${N} URL              read title, icon, color from a website
  ${G}icon set${N} LINK|PATH    direct image link (imgur, GitHub, Drive, Dropbox ok)
  ${G}icon test${N} LINK|PATH   check a link without saving  ${G}icon reset${N}
${B} Tools${N}
  ${G}doctor${N} [--fix]        check bugs / auto install
  ${G}profile${N} save|load|delete|list|export|import NAME
  ${G}share${N} ${G}install${N} ${G}serve${N}   WhatsApp / install / Wi-Fi link+QR
  ${G}info${N} ${G}log${N} [full]        APK details / last build steps
  ${G}upload${N} [file]         APK -> temporary CDN link (1h-72h)  ${G}links${N}  my links
  ${G}keystore${N} [backup]     signing key info / backup
  ${G}jar${N} [path|link]       find / download android.jar (needed to compile)
  ${G}list${N} ${G}clean${N} ${G}update${N} ${G}link${N} ${G}cmd${N} ${G}theme${N} NAME
  ${G}banner${N} [auto|card|big|medium|mini|off]   preview the header
${B} Social & WebZip${N}
  ${G}social${N} USER [platforms]   public profile lookup (official/public APIs only)
  ${G}social list${N}               platforms   ${G}keys${N} set youtube|github KEY  (optional)
  ${G}webzip${N} URL                site or repo -> ZIP  [--depth 1-3 --max-mb N --wayback --out NAME]
  ${G}setup${N}                     install every tool once (also happens automatically on first use)

${B} Build options${N}
  --url URL  --name "App"  --pkg com.x.y  --project NAME
  --icon PATH|LINK (--icon-url)  --color "#RRGGBB"  --version 1.2  --code 3
  --splash none | color:#HEX | image:PATH|LINK | video:PATH|LINK
  --orient auto|portrait|landscape  --fullscreen  --keep-on  --zoom
  --lock-domain  --desktop  --ua "UserAgent"  --no-progress
  --web-perms (camera/mic/location)  --secure (block screenshots)
  --profile NAME  --theme green|magenta|yellow|blue|mono|cyan
  --no-opt  --live  --refresh  --dry-run  --share  --install  --yes
  --upload  --ttl 1h|12h|24h|72h  --cdn auto|litterbox|0x0|tmpfiles
  --banner auto|card|big|medium|mini|off  --no-anim  --no-auto-install
  --only github,bluesky  --save  --json   (social)

${D} Tip: inside the menu you can type any command directly.${N}
HELP_EOF
}

# ───────────── menus ─────────────
set_config() {
  banner; echo "${B} Edit config${N} ${D}(Enter = keep current)${N}"; hr
  ask "Website URL" URL
  ask "App Name" APP_NAME
  ask "Package Name" PACKAGE
  ask "Project Name" PROJECT
  ask "Icon (file or DIRECT image link, '-' = default)" ICON
  if [ "$ICON" = "-" ]; then ICON=""; elif [ -n "$ICON" ]; then icon_check "$ICON" || warn "Icon problem - retry with menu 7 or: cioweb3apk icon set <link>"; fi
  ask "ColorPrimaryDark (#RRGGBB)" COLOR
  echo "${B} Loading screen${N}: ${G}0${N}) None  ${G}1${N}) Color  ${G}2${N}) Image  ${G}3${N}) Video  ${D}(Enter = keep)${N}"
  local s; read -r -p "Choose [0-3]: " s
  case "$s" in
    0) SPLASH_TYPE="none"; SPLASH_VALUE="-" ;;
    1) SPLASH_TYPE="color"; SPLASH_VALUE="#FFFFFF"; ask "Splash color (#RRGGBB)" SPLASH_VALUE ;;
    2) SPLASH_TYPE="image"; SPLASH_VALUE=""; read -r -p "Image path or link: " SPLASH_VALUE ;;
    3) SPLASH_TYPE="video"; SPLASH_VALUE=""; read -r -p "Video path or link (mp4): " SPLASH_VALUE ;;
  esac
  hr
  if validate_config; then ok "Config valid"; else warn "Fix the problems above and edit again"; fi
  save_config
}

features_menu() {
  local m v
  while :; do
    banner; echo "${B} App features${N}"; hr
    echo "  ${G}1${N}) Fullscreen (hide status bar)   $(onoff $FULLSCREEN)"
    echo "  ${G}2${N}) Orientation                    ${C}$ORIENT${N}"
    echo "  ${G}3${N}) Keep screen on                 $(onoff $KEEP_ON)"
    echo "  ${G}4${N}) File downloads                 $(onoff $ALLOW_DOWNLOAD)"
    echo "  ${G}5${N}) File upload (forms)            $(onoff $ALLOW_UPLOAD)"
    echo "  ${G}6${N}) Loading min. time              ${C}${SPLASH_MS} ms${N}"
    echo "  ${G}7${N}) Loading fade-out               $(onoff $SPLASH_FADE)"
    echo "  ${G}8${N}) Top progress bar               $(onoff $PROGRESS_BAR)"
    echo "  ${G}9${N}) Pinch zoom                     $(onoff $ALLOW_ZOOM)"
    echo "  ${G}a${N}) Lock to site domain            $(onoff $LOCK_DOMAIN)"
    echo "  ${G}b${N}) Press back twice to exit       $(onoff $EXIT_CONFIRM)"
    echo "  ${G}c${N}) Desktop mode                   $(onoff $DESKTOP)"
    echo "  ${G}d${N}) Custom User-Agent             ${C}$([ -n "$USER_AGENT" ] && echo "${USER_AGENT:0:22}…" || echo default)${N}"
    echo "  ${G}e${N}) Camera / mic / location for sites $(onoff $WEB_PERMS)"
    echo "  ${G}f${N}) Block screenshots (secure)      $(onoff $SECURE_MODE)"
    echo "  ${G}0${N}) Back"
    read -r -p "${C}❯${N} " m
    case "$m" in
      1) FULLSCREEN=$((1-FULLSCREEN)) ;;
      2) case "$ORIENT" in auto) ORIENT=portrait ;; portrait) ORIENT=landscape ;; *) ORIENT=auto ;; esac ;;
      3) KEEP_ON=$((1-KEEP_ON)) ;;
      4) ALLOW_DOWNLOAD=$((1-ALLOW_DOWNLOAD)) ;;
      5) ALLOW_UPLOAD=$((1-ALLOW_UPLOAD)) ;;
      6) read -r -p "Milliseconds (0-10000): " v; if [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -le 10000 ]; then SPLASH_MS="$v"; fi ;;
      7) SPLASH_FADE=$((1-SPLASH_FADE)) ;;
      8) PROGRESS_BAR=$((1-PROGRESS_BAR)) ;;
      9) ALLOW_ZOOM=$((1-ALLOW_ZOOM)) ;;
      a|A) LOCK_DOMAIN=$((1-LOCK_DOMAIN)) ;;
      b|B) EXIT_CONFIRM=$((1-EXIT_CONFIRM)) ;;
      c|C) DESKTOP=$((1-DESKTOP)) ;;
      d|D) read -r -p "User-Agent ('-' = default): " v; if [ "$v" = "-" ]; then USER_AGENT=""; elif [ -n "$v" ]; then USER_AGENT="$v"; fi ;;
      e|E) WEB_PERMS=$((1-WEB_PERMS)) ;;
      f|F) SECURE_MODE=$((1-SECURE_MODE)) ;;
      0|"") save_config; return ;;
    esac
    save_config
  done
}

options_menu() {
  local m
  while :; do
    banner; echo "${B} Build options & Optimizer${N}"; hr
    echo "  ${G}1${N}) Optimizer (small & fast APK)    $(onoff $OPTIMIZE)"
    echo "  ${G}2${N}) Show executed commands          $(onoff $SHOW_CMD)"
    echo "  ${G}3${N}) Live build output               $(onoff $LIVE)"
    echo "  ${G}4${N}) Keep project source             $(onoff $KEEP_SRC)"
    echo "  ${G}5${N}) APK file name with version      $(onoff $NAME_WITH_VER)"
    echo "  ${G}6${N}) Notification when done          $(onoff $NOTIFY)"
    echo "  ${G}7${N}) Version name / code             ${C}$VERSION_NAME / $VERSION_CODE${N}"
    echo "  ${G}8${N}) Color theme                     ${C}$THEME${N}"
    echo "  ${G}9${N}) Temp CDN expiry                 ${C}$CDN_TTL${N}"
    echo "  ${G}a${N}) Temp CDN host                   ${C}$CDN_HOST${N}"
    echo "  ${G}b${N}) Auto-upload after build         $(onoff $CDN_AUTO)"
    echo "  ${G}c${N}) Banner style                    ${C}$BANNER_STYLE${N}"
    echo "  ${G}d${N}) Banner intro animation          $(onoff $BANNER_ANIM)"
    echo "  ${G}e${N}) Animated build progress         $(onoff $BUILD_ANIM)"
    echo "  ${G}f${N}) Auto-install missing tools      $(onoff $AUTO_TOOLS)"
    echo "  ${G}0${N}) Back"
    read -r -p "${C}❯${N} " m
    case "$m" in
      1) OPTIMIZE=$((1-OPTIMIZE)) ;;
      2) SHOW_CMD=$((1-SHOW_CMD)) ;;
      3) LIVE=$((1-LIVE)) ;;
      4) KEEP_SRC=$((1-KEEP_SRC)) ;;
      5) NAME_WITH_VER=$((1-NAME_WITH_VER)) ;;
      6) NOTIFY=$((1-NOTIFY)) ;;
      7) ask "Version name" VERSION_NAME; ask "Version code" VERSION_CODE ;;
      8) case "$THEME" in cyan) THEME=green ;; green) THEME=magenta ;; magenta) THEME=yellow ;; yellow) THEME=blue ;; blue) THEME=mono ;; *) THEME=cyan ;; esac; apply_theme ;;
      9) case "$CDN_TTL" in 1h) CDN_TTL=12h ;; 12h) CDN_TTL=24h ;; 24h) CDN_TTL=72h ;; *) CDN_TTL=1h ;; esac ;;
      a|A) case "$CDN_HOST" in auto) CDN_HOST=litterbox ;; litterbox) CDN_HOST=0x0 ;; 0x0) CDN_HOST=tmpfiles ;; *) CDN_HOST=auto ;; esac ;;
      b|B) CDN_AUTO=$((1-CDN_AUTO)) ;;
      c|C) case "$BANNER_STYLE" in auto) BANNER_STYLE=card ;; card) BANNER_STYLE=big ;; big) BANNER_STYLE=medium ;; medium) BANNER_STYLE=mini ;; mini) BANNER_STYLE=off ;; *) BANNER_STYLE=auto ;; esac
           BANNER_SHOWN=1; banner_full "$BANNER_STYLE"; read -r -p "${D}Enter...${N}" _ ;;
      d|D) BANNER_ANIM=$((1-BANNER_ANIM)) ;;
      e|E) BUILD_ANIM=$((1-BUILD_ANIM)) ;;
      f|F) AUTO_TOOLS=$((1-AUTO_TOOLS)) ;;
      0|"") save_config; return ;;
    esac
    save_config
  done
}

profiles_menu() {
  local a n
  banner; echo "${B} Profiles${N}"; hr
  profile_list; hr
  echo "  ${G}s${N}) Save current as   ${G}l${N}) Load   ${G}d${N}) Delete"
  echo "  ${G}e${N}) Export to Download  ${G}i${N}) Import (file or link)   ${G}Enter${N}) Back"
  read -r -p "${C}❯${N} " a
  case "$a" in
    s) read -r -p "Profile name: " n; profile_save "$n" ;;
    l) read -r -p "Profile name: " n; profile_load "$n" && save_config ;;
    d) read -r -p "Profile name: " n; profile_delete "$n" ;;
    e) read -r -p "Profile name: " n; profile_export "$n" ;;
    i) read -r -p "File path or link: " n; profile_import "$n" ;;
    *) return ;;
  esac
  pause
}

tools_menu() {
  local m
  while :; do
    banner; echo "${B} More tools${N}"; hr
    echo "  ${G}1${N}) Profiles (save / load / list)"
    echo "  ${G}2${N}) Batch build all profiles"
    echo "  ${G}3${N}) Share APK over Wi-Fi (link + QR)"
    echo "  ${G}4${N}) APK info & verify"
    echo "  ${G}5${N}) Keystore info / backup"
    echo "  ${G}6${N}) My APKs (history)"
    echo "  ${G}7${N}) Install last APK"
    echo "  ${G}8${N}) Dry run (show plan only)"
    echo "  ${G}9${N}) Update tool (git pull)"
    echo "  ${G}a${N}) Last build steps & commands"
    echo "  ${G}b${N}) Upload APK to temporary CDN link"
    echo "  ${G}c${N}) My CDN links"
    echo "  ${G}d${N}) Setup: install all tools now"
    echo "  ${G}e${N}) API keys (YouTube / GitHub, optional)"
    echo "  ${G}0${N}) Back"
    read -r -p "${C}❯${N} " m
    SUB=""; ARG=""; ARG2=""
    case "$m" in
      1) profiles_menu ;;
      2) batch_cmd; pause ;;
      3) serve_cmd; pause ;;
      4) apk_info; pause ;;
      5) keystore_cmd; pause ;;
      6) list_apks; pause ;;
      7) install_apk; pause ;;
      8) DRY=1; build; DRY=0; pause ;;
      9) update_cmd; pause ;;
      a|A) log_cmd; pause ;;
      b|B) cdn_upload; pause ;;
      c|C) links_cmd; pause ;;
      d|D) setup_all; pause ;;
      e|E) keys_cmd; pause ;;
      0|"") return ;;
    esac
  done
}

menu() {
  local m u _p
  while :; do
    banner_full; show_config; hr
    echo "  ${G}1${N}) ${B}Build APK${N}          ${G}6${N}) Auto-fill from website"
    echo "  ${G}2${N}) Edit config         ${G}7${N}) Icon from direct link"
    echo "  ${G}3${N}) App features        ${G}8${N}) Social profile lookup"
    echo "  ${G}4${N}) Build options       ${G}9${N}) Website → ZIP"
    echo "  ${G}5${N}) Share to WhatsApp   ${G}t${N}) More tools"
    echo "  ${G}d${N}) Doctor ${G}s${N}) Setup ${G}h${N}) Help ${G}c${N}) Clean ${G}0${N}) Exit"
    echo "  ${D}or type a command: build, dry, social <user>, webzip <url> ...${N}"
    read -r -p "${C}❯${N} " m
    SUB=""; ARG=""; ARG2=""
    case "$m" in
      1) build; pause ;;
      2) set_config; pause ;;
      3) features_menu ;;
      4) options_menu ;;
      5) share_whatsapp; pause ;;
      6) read -r -p "${Y}Website URL${N} ${D}[$URL]${N}: " u; autofill_cmd "${u:-$URL}"; save_config; pause ;;
      7) icon_wizard; pause ;;
      8) social_menu; pause ;;
      9) webzip_menu; pause ;;
      t|T) tools_menu ;;
      d|D) doctor; pause ;;
      s|S) setup_all; pause ;;
      h|H) show_help; pause ;;
      c|C) optimizer_clean; pause ;;
      0|q) exit 0 ;;
      "") ;;
      *) read -r -a _p <<< "$m"; SUB="${_p[1]:-}"; ARG="${_p[2]:-}"; ARG2="${_p[3]:-}"; dispatch "${_p[0]}"; pause ;;
    esac
  done
}

# ───────────── cli ─────────────
parse_opts() {
  local v
  while [ $# -gt 0 ]; do
    case "$1" in
      --url) URL="$2"; shift 2 ;;
      --name) APP_NAME="$2"; shift 2 ;;
      --pkg|--package) PACKAGE="$2"; shift 2 ;;
      --project) PROJECT="$2"; shift 2 ;;
      --icon|--icon-url) ICON="$2"; shift 2 ;;
      --color) COLOR="$2"; shift 2 ;;
      --splash) v="$2"; SPLASH_TYPE="${v%%:*}"; if [ "$v" = "${v%%:*}" ]; then SPLASH_VALUE="-"; else SPLASH_VALUE="${v#*:}"; fi; shift 2 ;;
      --version) VERSION_NAME="$2"; shift 2 ;;
      --code) VERSION_CODE="$2"; shift 2 ;;
      --orient) ORIENT="$2"; shift 2 ;;
      --ua) USER_AGENT="$2"; shift 2 ;;
      --theme) THEME="$2"; shift 2 ;;
      --profile) shift 2 ;;
      --fullscreen) FULLSCREEN=1; shift ;;
      --keep-on) KEEP_ON=1; shift ;;
      --zoom) ALLOW_ZOOM=1; shift ;;
      --lock-domain) LOCK_DOMAIN=1; shift ;;
      --desktop) DESKTOP=1; shift ;;
      --web-perms) WEB_PERMS=1; shift ;;
      --secure) SECURE_MODE=1; shift ;;
      --no-progress) PROGRESS_BAR=0; shift ;;
      --no-exit-confirm) EXIT_CONFIRM=0; shift ;;
      --no-opt) OPTIMIZE=0; shift ;;
      --no-notify) NOTIFY=0; shift ;;
      --live) LIVE=1; shift ;;
      --refresh) REFRESH=1; shift ;;
      --dry-run) DRY=1; shift ;;
      --share) AUTO_SHARE=1; shift ;;
      --install) AUTO_INSTALL=1; shift ;;
      --upload) AUTO_UPLOAD=1; shift ;;
      --ttl) CDN_TTL="$2"; shift 2 ;;
      --cdn) CDN_HOST="$2"; shift 2 ;;
      --banner) BANNER_STYLE="$2"; shift 2 ;;
      --only) SOC_ONLY="$2"; shift 2 ;;
      --save) SOC_SAVE=1; shift ;;
      --json) SOC_JSON=1; shift ;;
      --depth) WZ_DEPTH="$2"; shift 2 ;;
      --max-mb) WZ_MAXMB="$2"; shift 2 ;;
      --wayback) WZ_WAYBACK=1; shift ;;
      --out) WZ_OUT="$2"; shift 2 ;;
      --no-auto-install) AUTO_TOOLS=0; shift ;;
      --no-anim) BUILD_ANIM=0; BANNER_ANIM=0; shift ;;
      --yes|-y) ASSUME_YES=1; shift ;;
      --fix) FIX_FLAG="--fix"; shift ;;
      *) warn "Unknown option: $1"; shift ;;
    esac
  done
}

dispatch() {
  local cmd="$1"
  case "$cmd" in
    menu)        menu ;;
    build)       if [ -n "$SUB" ]; then profile_load "$SUB" || return 1; fi; build ;;
    dry|plan)    if [ -n "$SUB" ]; then profile_load "$SUB" || return 1; fi; DRY=1; build; DRY=0 ;;
    batch)       batch_cmd ;;
    config)      set_config ;;
    features)    features_menu ;;
    options)     options_menu ;;
    doctor)      doctor "$FIX_FLAG" ;;
    share)       share_whatsapp ;;
    install)     install_apk ;;
    serve)       serve_cmd ;;
    info|verify) apk_info ;;
    keystore)    keystore_cmd ;;
    auto|autofill) autofill_cmd "$SUB"; save_config ;;
    icon)        icon_cmd ;;
    log)         log_cmd ;;
    upload|cdn)  cdn_cmd ;;
    links)       links_cmd ;;
    jar)         jar_cmd ;;
    selftest)    selftest ;;
    setup|bootstrap) setup_all ;;
    social|stalk|lookup) social_cmd ;;
    webzip|web2zip) webzip_cmd ;;
    keys)        keys_cmd ;;
    banner)      if [ -n "$SUB" ]; then BANNER_STYLE="$SUB"; sanitize_vars; fi; BANNER_SHOWN=0; banner_full ;;
    list)        list_apks ;;
    clean)       optimizer_clean ;;
    update)      update_cmd ;;
    link)        link_cmd ;;
    cmd)         equiv_cmd; echo ;;
    theme)       if [ -n "$SUB" ]; then THEME="$SUB"; fi; apply_theme; save_config; ok "Theme: $THEME" ;;
    profile)
      case "$SUB" in
        save)        profile_save "$ARG" ;;
        load)        profile_load "$ARG" && save_config ;;
        delete|rm)   profile_delete "$ARG" ;;
        export)      profile_export "$ARG" ;;
        import)      profile_import "$ARG" "$ARG2" ;;
        list|"")     profile_list ;;
        *)           bad "Usage: profile save|load|delete|list NAME" ;;
      esac ;;
    exit|quit)   exit 0 ;;
    version|-v|--version) echo "CioWeb3Apk v$VERSION by Cio-ID" ;;
    help|-h|--help) show_help ;;
    *) bad "Unknown command: $cmd"; show_help; return 1 ;;
  esac
}

main() {
  load_config; sanitize_vars; apply_theme; find_android_jar
  local cmd="${1:-menu}"; [ $# -gt 0 ] && shift
  SUB=""; ARG=""; ARG2=""
  if [ $# -gt 0 ] && [[ "$1" != -* ]]; then SUB="$1"; shift; fi
  if [ $# -gt 0 ] && [[ "$1" != -* ]]; then ARG="$1"; shift; fi
  if [ $# -gt 0 ] && [[ "$1" != -* ]]; then ARG2="$1"; shift; fi
  local a prev=""
  for a in "$@"; do
    if [ "$prev" = "--profile" ]; then profile_load "$a" || exit 1; fi
    prev="$a"
  done
  parse_opts "$@"; sanitize_vars; apply_theme
  dispatch "$cmd"; exit $?
}

main "$@"
