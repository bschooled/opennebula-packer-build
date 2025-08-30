#!/bin/bash

NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"
LOG_FILE="/var/log/ip-assign.log"
IP_LIST=(192.168.50.226 192.168.50.227 192.168.50.228 192.168.50.229 192.168.50.230 192.168.50.231 192.168.50.232 192.168.50.233 192.168.50.234 192.168.50.235)
GATEWAY="192.168.50.1"
COMMENT_FLAG="# updated-by-ip-assigner"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Exit if already updated
if grep -q "$COMMENT_FLAG" "$NETPLAN_FILE"; then
  echo "$TIMESTAMP - Netplan already updated. Skipping." >> "$LOG_FILE"
  exit 0
fi

# Retry loop with timeout
start_time=$(date +%s)
chosen_ip=""
while true; do
  for ip in "${IP_LIST[@]}"; do
    if ! ping -c 1 -W 1 "$ip" &>/dev/null; then
      chosen_ip="$ip"
      break
    fi
  done

  if [ -n "$chosen_ip" ]; then
    break
  fi

  now=$(date +%s)
  elapsed=$((now - start_time))
  if [ "$elapsed" -ge 60 ]; then
    echo "$TIMESTAMP - No available IP found after 60s. Exiting." >> "$LOG_FILE"
    exit 1
  fi

  sleep 2
done

echo "$TIMESTAMP - Assigning IP: $chosen_ip" >> "$LOG_FILE"

# Update Netplan using yq
for iface in dynamic0 dynamic1 dynamic2 dynamic3; do
  yq -i ".network.ethernets.${iface}.addresses = [\"${chosen_ip}/24\"]" "$NETPLAN_FILE" -y
  if [ $? -ne 0 ]; then
    echo "$TIMESTAMP - Failed to update addresses for $iface. Exiting." >> "$LOG_FILE"
    exit 1
  fi

  yq -i ".network.ethernets.${iface}.routes = [{\"to\": \"default\", \"via\": \"$GATEWAY\"}]" "$NETPLAN_FILE" -y
  if [ $? -ne 0 ]; then
    echo "$TIMESTAMP - Failed to update routes for $iface. Exiting." >> "$LOG_FILE"
    exit 1
  fi

  yq -i ".network.ethernets.${iface}.nameservers.addresses = [\"$GATEWAY\"]" "$NETPLAN_FILE" -y
  if [ $? -ne 0 ]; then
    echo "$TIMESTAMP - Failed to update nameservers for $iface. Exiting." >> "$LOG_FILE"
    exit 1
  fi
done

# Append comment flag
echo "$COMMENT_FLAG" >> "$NETPLAN_FILE"

# Apply Netplan
netplan generate && netplan apply
echo "$TIMESTAMP - Netplan applied successfully with IP $chosen_ip" >> "$LOG_FILE"