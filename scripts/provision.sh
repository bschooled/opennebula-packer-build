#!/usr/bin/env bash
set -eux

# Ensure destination dirs
install -d -m0755 /usr/local/bin /etc/systemd/system

# Copy scripts and service files if present
find /tmp/service-scripts -maxdepth 1 -name "*.sh" -exec cp -a {} /usr/local/bin/ \; || true
if ls /tmp/service-scripts/*.sh 1> /dev/null 2>&1; then
  chmod 0755 /tmp/service-scripts/*.sh || true
  cp -a /tmp/service-scripts/*.sh /usr/local/bin/ || true
fi
if ls /tmp/service-scripts/*.service 1> /dev/null 2>&1; then
  chmod 0644 /tmp/service-scripts/*.service || true
  cp -a /tmp/service-scripts/*.service /etc/systemd/system/ || true
fi

# Clone repo and set up environment
if [ ! -d /opt/one-deploy ]; then
  git clone https://github.com/OpenNebula/one-deploy /opt/one-deploy
fi
mkdir -p /opt/one-deploy/my-one
cp -a /tmp/onedeploy-configs/* /opt/one-deploy/my-one/ || true
chown -R nebula:root /opt/one-deploy || true

groupadd -g 9869 onedeploy || true
useradd -m -s /bin/bash -u 9869 -g 9869 onedeploy || true

mkdir -p /mnt/NebulaStorage-nfs
MOUNT_LINE="192.168.50.25:/mnt/OpenNebula/NebulaStorage /mnt/NebulaStorage-nfs nfs defaults,vers=3 0 0"
FSTAB="/etc/fstab"
# Append to fstab only if not already present
if ! grep -Fxq "$MOUNT_LINE" "$FSTAB"; then
  echo "$MOUNT_LINE" >> "$FSTAB"
fi

systemctl daemon-reexec || true
systemctl daemon-reload || true
systemctl enable rename-enx.service || true
systemctl enable rename-host.service || true
systemctl enable assign-ip.service || true
systemctl start rename-host.service || true

mount -a || true
chown 9869:9869 /mnt/NebulaStorage-nfs || true

sudo -u nebula -H bash -c "
set -eux
python3 -m pipx ensurepath || true
pipx install hatch || true
source ~/.bashrc
cd /opt/one-deploy || exit 0
make requirements || true
/home/nebula/.local/bin/hatch env create default || true
if [ -f /opt/one-deploy/requirements.yml ] && grep -q 'collections:' /opt/one-deploy/requirements.yml; then
    /home/nebula/.local/bin/hatch env run -e default -- ansible-galaxy collection install --requirements-file /opt/one-deploy/requirements.yml || true
else
    echo 'Missing or malformed requirements.yml' >&2
    exit 1
fi
"

echo "Provisioning complete" > /var/log/packer-provision.log
