#!/bin/bash
usermod -l "${username}" ubuntu  
usermod -d "/home/${username}" -m ${username}
sed -i "s/ubuntu/${username}/" /etc/sudoers.d/90-cloud-init-users
set -e
# Install Twingate
curl "https://binaries.twingate.com/connector/setup.sh" | sudo TWINGATE_ACCESS_TOKEN="${access_token}" TWINGATE_REFRESH_TOKEN="${refrent_token}" TWINGATE_NETWORK="${network_name}" TWINGATE_LABEL_DEPLOYED_BY="linux" bash
sudo systemctl enable --now twingate-connector