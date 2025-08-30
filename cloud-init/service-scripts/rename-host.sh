#!/bin/bash

# Extract manufacturer from DMI
manufacturer=$(cat /sys/class/dmi/id/product_family | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

# Fallback if empty
if [ -z "$manufacturer" ]; then
  manufacturer="unknown"
fi

# Construct new hostname
new_hostname="${manufacturer}-nebula"

# Set hostname
hostnamectl set-hostname "$new_hostname"

# Update /etc/hosts
sed -i "s/127.0.1.1.*/127.0.1.1 $new_hostname/" /etc/hosts