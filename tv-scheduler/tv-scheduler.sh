#!/usr/bin/env bash
# Turns the TV off when nobody's home or it's sleep time, back on otherwise.
# Runs every minute from tv-scheduler.timer. Only acts when the wanted state
# CHANGES, so turning the TV on/off by hand isn't undone a minute later.
set -u

CONF="${TV_SCHED_CONF:-/etc/tv-scheduler.conf}"
STATE_DIR="${TV_SCHED_STATE:-/var/lib/tv-scheduler}"
# shellcheck source=/dev/null
. "$CONF"
mkdir -p "$STATE_DIR"

log() { echo "$*"; }

# ---------- day types ----------
is_free_date() {  # $1 = YYYY-MM-DD
  local d="$1" line from to
  [ -f "$FREE_DATES_FILE" ] || return 1
  while IFS= read -r line; do
    line="${line%%#*}"; line="${line//[[:space:]]/}"
    [ -z "$line" ] && continue
    if [[ "$line" == *..* ]]; then
      from="${line%%..*}"; to="${line##*..}"
      [[ ! "$d" < "$from" && ! "$d" > "$to" ]] && return 0
    elif [ "$line" = "$d" ]; then
      return 0
    fi
  done < "$FREE_DATES_FILE"
  return 1
}

is_school_day() {  # $1 = date string accepted by `date -d`
  local dow ymd
  dow=$(date -d "$1" +%u); ymd=$(date -d "$1" +%F)
  [ "$dow" -le 5 ] && ! is_free_date "$ymd"
}

to_min() { echo $(( 10#${1%%:*} * 60 + 10#${1##*:} )); }

# Sleep if: before the morning-on time of today, or after the night-off time
# that belongs to tomorrow's day type (school night vs free night).
is_sleep_time() {
  local now on off
  now=$(to_min "$(date +%H:%M)")
  if is_school_day today; then on=$(to_min "$SCHOOL_MORNING_ON"); else on=$(to_min "$FREE_MORNING_ON"); fi
  [ "$now" -lt "$on" ] && return 0
  if is_school_day tomorrow; then off=$(to_min "$SCHOOL_NIGHT_OFF"); else off=$(to_min "$FREE_NIGHT_OFF"); fi
  # 00:00 means "midnight", i.e. never in the evening; the morning check covers it
  [ "$off" -gt 0 ] && [ "$now" -ge "$off" ] && return 0
  return 1
}

# ---------- presence ----------
phone_seen_now() {
  local ip iface
  for ip in $PHONE_IPS; do
    if command -v arping >/dev/null; then
      iface=$(ip route get "$ip" 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="dev"){print $(i+1); exit}}')
      arping -c 2 -w 3 ${iface:+-I "$iface"} "$ip" >/dev/null 2>&1 && return 0
    fi
    ping -c 1 -W 2 "$ip" >/dev/null 2>&1 && return 0
    ip neigh show "$ip" 2>/dev/null | grep -qE 'REACHABLE|DELAY' && return 0
  done
  return 1
}

is_home() {
  local now last
  now=$(date +%s)
  phone_seen_now && echo "$now" > "$STATE_DIR/last_seen"
  last=$(cat "$STATE_DIR/last_seen" 2>/dev/null || echo "$now")  # first run: assume home
  [ $(( now - last )) -lt $(( AWAY_AFTER_MIN * 60 )) ]
}

# ---------- TV control ----------
cec_available() { command -v cec-client >/dev/null && echo scan | cec-client -s -d 1 2>/dev/null | grep -q 'device #0'; }

tv_cec() {  # on|off
  local cmd="standby 0"; [ "$1" = on ] && cmd="on 0"
  echo "$cmd" | cec-client -s -d 1 >/dev/null 2>&1
  [ "$1" = on ] && echo "as" | cec-client -s -d 1 >/dev/null 2>&1  # switch TV input to the NAS
  return 0
}

tv_lgnet() {  # on|off
  if [ "$1" = on ]; then
    wakeonlan "$TV_MAC" >/dev/null 2>&1 || etherwake "$TV_MAC" >/dev/null 2>&1
  else
    bscpylgtvcommand "$TV_IP" power_off >/dev/null 2>&1
  fi
}

tv_set() {
  case "$TV_BACKEND" in
    cec)   tv_cec "$1" ;;
    lgnet) tv_lgnet "$1" ;;
    *)     if cec_available; then tv_cec "$1"; else tv_lgnet "$1"; fi ;;
  esac
}

# ---------- main ----------
reason=""
if is_sleep_time; then want=off; reason="sleep time"
elif ! is_home; then want=off; reason="nobody home"
else want=on; reason="home and awake"
fi

last_want=$(cat "$STATE_DIR/want" 2>/dev/null || echo "")
if [ "${1:-}" = "--force" ] || [ "$want" != "$last_want" ]; then
  log "TV -> $want ($reason)"
  tv_set "$want"
  echo "$want" > "$STATE_DIR/want"
fi
