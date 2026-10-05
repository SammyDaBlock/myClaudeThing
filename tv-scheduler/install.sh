#!/usr/bin/env bash
# sudo ./install.sh
set -e
cd "$(dirname "$0")"
apt-get update
apt-get install -y cec-utils iputils-arping wakeonlan pipx
pipx install --global bscpylgtv 2>/dev/null || PIPX_BIN_DIR=/usr/local/bin pipx install bscpylgtv || true
install -m 755 tv-scheduler.sh /usr/local/bin/tv-scheduler
[ -f /etc/tv-scheduler.conf ] || install -m 644 tv-scheduler.conf /etc/tv-scheduler.conf
[ -f /etc/tv-scheduler.free-dates ] || install -m 644 free-dates.example /etc/tv-scheduler.free-dates
install -m 644 tv-scheduler.service tv-scheduler.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now tv-scheduler.timer
echo
echo "Installed. Now edit /etc/tv-scheduler.conf (phone IP, TV IP/MAC)."
echo "CEC check:  echo scan | cec-client -s -d 1"
echo "Logs:       journalctl -u tv-scheduler -f"
