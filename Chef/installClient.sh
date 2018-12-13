#!/bin/bash
#
# See https://docs.chef.io/packages.html
#

# client install
#curl -L https://www.opscode.com/chef/install.sh | sudo bash

sudo apt-get install apt-transport-https
wget -qO - https://packages.chef.io/chef.asc | sudo apt-key add -
CHANNEL=stable
DISTRIBUTION="$(cat /etc/lsb-release | grep DISTRIB_CODENAME | awk -F '=' '{ print $2 }')"

if [[ -z "$DISTRIBUTION" ]]; then
  echo "ERROR: could not determine distribute from /etc/lsb-release"
  exit 1
fi
echo "deb https://packages.chef.io/repos/apt/$CHANNEL $DISTRIBUTION main" > chef-${CHANNEL}.list
sudo mv chef-stable.list /etc/apt/sources.list.d/
sudo apt-get update
sudo apt install chef chefdk

