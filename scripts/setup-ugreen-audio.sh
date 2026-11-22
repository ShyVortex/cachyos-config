#!/usr/bin/env bash
# Fix: no audio from the UGREEN 15390 HDMI capture card on Linux.
#
# On Linux, the card's ALSA capture switch ("Digital In") is off by default,
# so the card shows up as an audio source but delivers silence (Windows enables
# it automatically). This script installs a udev rule that turns "Digital In"
# on every time the card is plugged in, on any Linux distribution.
#
# Requirements: alsa-utils (provides amixer)
# Usage:        sudo bash setup-ugreen-audio.sh
#
# Other capture cards: run `arecord -l` to find your card's ALSA id (the name
# after "card N:") and `amixer -c N` to find the name of its capture control,
# then change CARD_ID and CONTROL below.
set -euo pipefail

CARD_ID="U15390"
CONTROL="Digital In"
RULE_FILE="/etc/udev/rules.d/99-ugreen-capture-audio.rules"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash $0" >&2
  exit 1
fi

AMIXER="$(command -v amixer || true)"
if [[ -z "$AMIXER" ]]; then
  echo "amixer not found: install the 'alsa-utils' package and run this script again." >&2
  exit 1
fi

# The rule matches the card by its ALSA id, so it keeps working even if
# the card number or the USB port changes.
cat > "$RULE_FILE" <<EOF
# UGREEN capture card ($CARD_ID): enable the "$CONTROL" capture switch when plugged in
ACTION=="add", SUBSYSTEM=="sound", KERNEL=="controlC*", ATTRS{id}=="$CARD_ID", RUN+="$AMIXER -c %n sset '$CONTROL' cap"
EOF

echo "Rule written to $RULE_FILE"

udevadm control --reload-rules
udevadm trigger --subsystem-match=sound --action=add

# Enable the capture switch right away if the card is already connected
CARD="$(awk -v id="$CARD_ID" '$0 ~ "\\[" id {print $1; exit}' /proc/asound/cards || true)"
if [[ -n "$CARD" ]]; then
  "$AMIXER" -c "$CARD" sset "$CONTROL" cap >/dev/null
  echo "Card found (card $CARD): \"$CONTROL\" enabled."
else
  echo "Card not connected right now: it will be configured the next time you plug it in."
fi

echo "Done. If an app was already using the card, restart it."