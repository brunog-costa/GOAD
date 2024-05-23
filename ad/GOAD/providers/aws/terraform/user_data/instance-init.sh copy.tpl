#!/bin/bash
usermod -l "${username}" ubuntu  
usermod -d "/home/${username}" -m ${username}
sed -i "s/ubuntu/${username}/" /etc/sudoers.d/90-cloud-init-users
set -e
mkdir -p /etc/twingate/
{
    echo TWINGATE_URL="${url}"
    echo TWINGATE_ACCESS_TOKEN="${access_token}"
    echo TWINGATE_REFRESH_TOKEN="${refrent_token}"
} > /etc/twingate/connector.conf
sudo systemctl enable --now twingate-connector