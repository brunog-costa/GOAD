#!/bin/bash
usermod -l "${username}" ubuntu  
usermod -d "/home/${username}" -m ${username}
sed -i "s/ubuntu/${username}/" /etc/sudoers.d/90-cloud-init-users
set -e
# Install Twingate
sudo mkdir -p /etc/twingate/
HOSTNAME_LOOKUP=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
{
echo TWINGATE_NETWORK="hackeronilabs"
echo TWINGATE_ACCESS_TOKEN="${access_token}"
echo TWINGATE_REFRESH_TOKEN="${refrent_token}"
echo TWINGATE_LABEL_HOSTNAME=$HOSTNAME_LOOKUP
echo TWINGATE_LABEL_DEPLOYED_BY="ami"
} > /etc/twingate/connector.conf
sudo systemctl enable --now twingate-connector