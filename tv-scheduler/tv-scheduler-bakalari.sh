#!/usr/bin/env bash
# Asks Bakalari which of the next weeks' days are school days and caches it for tv-scheduler.
# Uses the Bakalari login of the custom-mcp container, so no password is stored here.
# Output: $STATE_DIR/school-days, one "YYYY-MM-DD school|free  # day type / note" per line.
set -eu
STATE_DIR="${TV_SCHED_STATE:-/var/lib/tv-scheduler}"
CONTAINER="${BAKALARI_CONTAINER:-custom-mcp}"
WEEKS="${BAKALARI_WEEKS:-10}"
mkdir -p "$STATE_DIR"
tmp="$STATE_DIR/school-days.tmp"

docker exec -i -e WEEKS="$WEEKS" "$CONTAINER" python - > "$tmp" 2>/dev/null <<'PY'
import os
from datetime import date, timedelta
import bakalari_mcp as b
seen = set()
for w in range(int(os.environ["WEEKS"])):
    d = date.today() + timedelta(weeks=w)
    for day in b._api("GET", "timetable/actual", params={"date": d.isoformat()})["Days"]:
        ymd = day["Date"][:10]
        if ymd in seen:
            continue
        seen.add(ymd)
        # school = a normal day that actually has lessons; Holiday/Celebration/DirectorDay/empty days = free
        school = day["DayType"] == "WorkDay" and len(day["Atoms"]) > 0
        print(ymd, "school" if school else "free", "#", day["DayType"], day.get("DayDescription") or "")
PY

if [ -s "$tmp" ]; then
  mv "$tmp" "$STATE_DIR/school-days"
  echo "Bakalari: cached $(wc -l < "$STATE_DIR/school-days") days ($(grep -c ' free' "$STATE_DIR/school-days") free on weekdays)"
else
  rm -f "$tmp"
  echo "Bakalari fetch failed, keeping the old cache / falling back to the dates file" >&2
  exit 1
fi
