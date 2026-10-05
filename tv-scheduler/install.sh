#!/usr/bin/env bash
# sudo ./install.sh
set -e
cd "$(dirname "$0")"
apt-get update
apt-get install -y iputils-arping wakeonlan pipx
pipx install --global bscpylgtv 2>/dev/null || PIPX_BIN_DIR=/usr/local/bin pipx install bscpylgtv || true
install -m 755 tv-scheduler.sh /usr/local/bin/tv-scheduler
install -m 755 tv-scheduler-bakalari.sh /usr/local/bin/tv-scheduler-bakalari
[ -f /etc/tv-scheduler.conf ] || install -m 644 tv-scheduler.conf /etc/tv-scheduler.conf
[ -f /etc/tv-scheduler.free-dates ] || install -m 644 free-dates.example /etc/tv-scheduler.free-dates
install -m 644 tv-scheduler.service tv-scheduler.timer tv-scheduler-bakalari.service tv-scheduler-bakalari.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now tv-scheduler-bakalari.timer
systemctl start tv-scheduler-bakalari.service || true
systemctl enable --now tv-scheduler.timer
echo
echo "Installed. Config: /etc/tv-scheduler.conf"
echo "Pair with the TV once (accept the prompt on the TV):  sudo bscpylgtvcommand <TV_IP> get_power_state"
echo "Logs:  journalctl -u tv-scheduler -u tv-scheduler-bakalari -f"
