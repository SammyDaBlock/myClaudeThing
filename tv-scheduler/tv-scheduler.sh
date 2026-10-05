#!/usr/bin/env bash
# Turns the TV off when nobody's home or it's sleep time, back on otherwise.
# `tv-scheduler --loop` (the systemd service) checks every CHECK_EVERY_SEC seconds.
# Only acts when the wanted state CHANGES, so turning the TV on/off by hand isn't undone.
set -u

if [ "${1:-}" = "--loop" ]; then
  while true; do
    "$0"
    # shellcheck source=/dev/null
    sleep "$( . "${TV_SCHED_CONF:-/etc/tv-scheduler.conf}"; echo "${CHECK_EVERY_SEC:-5}" )"
  done
fi

CONF="${TV_SCHED_CONF:-/etc/tv-scheduler.conf}"
STATE_DIR="${TV_SCHED_STATE:-/var/lib/tv-scheduler}"
# shellcheck source=/dev/null
. "$CONF"
mkdir -p "$STATE_DIR"
# Settings changed in the Watch app (TV page) override the config file. Written by nas-tv.
SETTINGS="$STATE_DIR/settings.conf"
# shellcheck source=/dev/null
[ -f "$SETTINGS" ] && . "$SETTINGS"
AUTO_ENABLED="${AUTO_ENABLED:-1}"   # 0 = scheduler does nothing at all
AUTO_ON="${AUTO_ON:-1}"             # 0 = never turns the TV ON by itself (only off)
AWAY_OFF="${AWAY_OFF:-1}"           # 0 = don't turn off when nobody's home
SLEEP_OFF="${SLEEP_OFF:-1}"         # 0 = don't turn off at sleep time
USE_BAKALARI="${USE_BAKALARI:-1}"   # 0 = ignore Bakalari, only Mon-Fri + free-dates file

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

# Bakalari knows best (holidays, ředitelské volno, ...): use its cached answer when it has this date,
# otherwise fall back to Mon-Fri minus the free-dates file.
BAKALARI_CACHE="$STATE_DIR/school-days"
is_school_day() {  # $1 = date string accepted by `date -d`
  local dow ymd ans
  dow=$(date -d "$1" +%u); ymd=$(date -d "$1" +%F)
  if [ "$USE_BAKALARI" = 1 ]; then
    ans=$(awk -v d="$ymd" '$1 == d {print $2; exit}' "$BAKALARI_CACHE" 2>/dev/null)
    [ -n "$ans" ] && { [ "$ans" = school ]; return; }
  fi
  [ "$dow" -le 5 ] && ! is_free_date "$ymd"
}

to_min() { echo $(( 10#${1%%:*} * 60 + 10#${1##*:} )); }

# The night BEFORE day D follows D's type (Sunday night = school night, Friday night = free night).
# A night-off time from 12:00 on is the evening before; earlier than 12:00 means after midnight
# (00:00 = midnight, 01:00 = 1 at night). The TV stays off until that day's morning-on time.
night_off() { if is_school_day "$1"; then echo "$SCHOOL_NIGHT_OFF"; else echo "$FREE_NIGHT_OFF"; fi; }
morning_on() { if is_school_day "$1"; then echo "$SCHOOL_MORNING_ON"; else echo "$FREE_MORNING_ON"; fi; }
is_sleep_time() {
  local now off on
  now=$(to_min "$(date +%H:%M)")
  # the night that ends this morning
  off=$(to_min "$(night_off today)"); on=$(to_min "$(morning_on today)")
  if [ "$off" -lt 720 ]; then
    [ "$now" -ge "$off" ] && [ "$now" -lt "$on" ] && return 0
  else
    [ "$now" -lt "$on" ] && return 0
  fi
  # the night that starts this evening
  off=$(to_min "$(night_off tomorrow)")
  [ "$off" -ge 720 ] && [ "$now" -ge "$off" ] && return 0
  return 1
}

# ---------- presence ----------
connected_macs() {  # devices associated with the extender AP, minus ignored ones
  local mac
  for mac in $(iw dev "$EXTENDER_IFACE" station dump 2>/dev/null | awk '/^Station/{print tolower($2)}'); do
    [[ " ${EXTENDER_IGNORE_MACS,,} " == *" $mac "* ]] || echo "$mac"
  done
}
someone_connected() { [ -n "$(connected_macs)" ]; }
device_name() {  # hostname from the extender's DHCP leases, e.g. "iPhone"
  local n
  n=$(awk -v m="$1" 'tolower($2) == m {print $4; exit}' /var/lib/NetworkManager/dnsmasq-"$EXTENDER_IFACE".leases 2>/dev/null)
  n="${n//[^A-Za-z0-9 ._-]/}"; [ -n "$n" ] && [ "$n" != "*" ] && echo "$n" || echo "$1"
}

is_home() {
  local now last
  now=$(date +%s)
  someone_connected && echo "$now" > "$STATE_DIR/last_seen"
  last=$(cat "$STATE_DIR/last_seen" 2>/dev/null || echo "$now")  # first run: assume home
  [ $(( now - last )) -lt "${AWAY_AFTER_SEC:-$(( ${AWAY_AFTER_MIN:-5} * 60 ))}" ]
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
    # send a few, Wi-Fi WoL packets get lost sometimes
    for _ in 1 2 3; do wakeonlan -i "${WOL_BCAST:-255.255.255.255}" "$TV_MAC" >/dev/null 2>&1; sleep 1; done
    # then switch to the NAS's input, once the TV answers (it takes a few seconds to boot)
    if [ -n "${TV_INPUT:-}" ]; then
      local i
      for i in $(seq 15); do
        timeout 8 bscpylgtvcommand "$TV_IP" set_input "$TV_INPUT" >/dev/null 2>&1 && { log "  input -> $TV_INPUT"; break; }
        sleep 2
      done
    fi
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
# Manual "TV on/off now" from the Watch app. Doesn't touch the wanted state, so the
# scheduler won't undo it until the next real change (leaving, sleep time, ...).
if [ "${1:-}" = "--set" ]; then
  case "${2:-}" in on|off) log "TV -> $2 (by hand, from the Watch app)"; tv_set "$2"; exit 0 ;; esac
  echo "usage: tv-scheduler --set on|off" >&2; exit 2
fi

sleep_now=0; home_now=0
is_sleep_time && sleep_now=1
is_home && home_now=1

if [ "$SLEEP_OFF" = 1 ] && [ "$sleep_now" = 1 ]; then want=off; reason="sleep time"
elif [ "$AWAY_OFF" = 1 ] && [ "$home_now" = 0 ]; then want=off; reason="nobody home"
else want=on; reason="home and awake"
fi
[ "$home_now" = 0 ] && [ "$AWAY_OFF" = 0 ] && reason="nobody home, but turning off when away is disabled"
[ "$sleep_now" = 1 ] && [ "$SLEEP_OFF" = 0 ] && reason="sleep time, but turning off at night is disabled"

last_want=$(cat "$STATE_DIR/want" 2>/dev/null || echo "")
acted=""
if [ "$AUTO_ENABLED" != 1 ]; then
  reason="automation is turned off"
elif [ "${1:-}" = "--force" ] || [ "$want" != "$last_want" ]; then
  if [ "$want" = on ] && [ "$AUTO_ON" != 1 ]; then
    log "TV would go on ($reason), but turning on by itself is disabled"
  else
    log "TV -> $want ($reason)"
    tv_set "$want"
    acted=1
  fi
  echo "$want" > "$STATE_DIR/want"
fi

# ---------- status for the Watch app ----------
devs=""
for m in $(connected_macs); do devs="$devs${devs:+,}\"$(device_name "$m")\""; done
day_t() { if is_school_day "$1"; then echo school; else echo free; fi; }
b() { [ "$1" = 1 ] && echo true || echo false; }
cat > "$STATE_DIR/status.json.tmp" <<JSON
{"t": $(date +%s), "want": "$want", "reason": "$reason", "home": $(b $home_now), "sleep": $(b $sleep_now),
 "devices": [$devs], "today": "$(day_t today)", "tomorrow": "$(day_t tomorrow)",
 "bakalari_updated": $(stat -c %Y "$BAKALARI_CACHE" 2>/dev/null || echo null),
 "settings": {"AUTO_ENABLED": $(b "$AUTO_ENABLED"), "AUTO_ON": $(b "$AUTO_ON"), "AWAY_OFF": $(b "$AWAY_OFF"),
   "SLEEP_OFF": $(b "$SLEEP_OFF"), "USE_BAKALARI": $(b "$USE_BAKALARI"),
   "SCHOOL_NIGHT_OFF": "$SCHOOL_NIGHT_OFF", "SCHOOL_MORNING_ON": "$SCHOOL_MORNING_ON",
   "FREE_NIGHT_OFF": "$FREE_NIGHT_OFF", "FREE_MORNING_ON": "$FREE_MORNING_ON",
   "AWAY_AFTER_SEC": ${AWAY_AFTER_SEC:-10}, "TV_INPUT": "${TV_INPUT:-}"}}
JSON
mv "$STATE_DIR/status.json.tmp" "$STATE_DIR/status.json"
