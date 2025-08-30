#!/bin/bash

LINK_DIR="/etc/systemd/network"
mkdir -p "$LINK_DIR"

# Get current MAC addresses
current_macs=$(ls /sys/class/net/*/address | xargs cat)

# Clean up stale .link files
for linkfile in "$LINK_DIR"/*-mgmt*.link; do
  [ -e "$linkfile" ] || continue
  mac=$(grep '^MACAddress=' "$linkfile" | cut -d= -f2)
  if ! echo "$current_macs" | grep -iq "$mac"; then
    echo "Removing stale link file: $linkfile (MAC $mac not found)"
    rm -f "$linkfile"
  fi
done

# Index counters
indexenx=1
indexenp=1
indexens=1
indexeno=1

# Create new .link files for enx*
for iface in $(ls /sys/class/net/ | grep ^enx); do
  mac=$(cat /sys/class/net/$iface/address)
  alias="mgmtenx${indexenx}"

  echo "Creating link file for $iface (MAC: $mac) → $alias"

  cat <<EOF > "$LINK_DIR/10-mgmt-enx-${alias}.link"
[Match]
MACAddress=$mac

[Link]
Name=$alias
AlternativeName=$iface
AlternativeNamesPolicy=database
EOF

  indexenx=$((indexenx + 1))
done

# Create new .link files for enp*
for iface in $(ls /sys/class/net/ | grep ^enp); do
  mac=$(cat /sys/class/net/$iface/address)
  alias="mgmtenp${indexenp}"

  echo "Creating link file for $iface (MAC: $mac) → $alias"

  cat <<EOF > "$LINK_DIR/10-mgmt-enp-${alias}.link"
[Match]
MACAddress=$mac

[Link]
Name=$alias
AlternativeName=$iface
AlternativeNamesPolicy=database
EOF

  indexenp=$((indexenp + 1))
done

# Create new .link files for ens*
for iface in $(ls /sys/class/net/ | grep ^ens); do
  mac=$(cat /sys/class/net/$iface/address)
  alias="mgmtens${indexens}"

  echo "Creating link file for $iface (MAC: $mac) → $alias"

  cat <<EOF > "$LINK_DIR/10-mgmt-ens-${alias}.link"
[Match]
MACAddress=$mac

[Link]
Name=$alias
AlternativeName=$iface
AlternativeNamesPolicy=database
EOF

  indexens=$((indexens + 1))
done

# Create new .link files for eno*
for iface in $(ls /sys/class/net/ | grep ^eno); do
  mac=$(cat /sys/class/net/$iface/address)
  alias="mgmteno${indexeno}"

  echo "Creating link file for $iface (MAC: $mac) → $alias"

  cat <<EOF > "$LINK_DIR/10-mgmt-eno-${alias}.link"
[Match]
MACAddress=$mac

[Link]
Name=$alias
AlternativeName=$iface
AlternativeNamesPolicy=database
EOF

  indexeno=$((indexeno + 1))
done

# Reload udev to apply changes
systemctl restart systemd-udevd
udevadm trigger