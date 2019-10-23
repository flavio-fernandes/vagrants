#!/usr/bin/env bash
#

# set -o xtrace
set -o errexit

[ -e /dev/kvm ] || { echo "PROBLEM, you need to ensure nesting is enabled"; exit 1; }

yum install -y git emacs wget

# Add persistent route via netwoek manager
# https://elearning.wsldp.com/pcmagazine/add-permanent-routes-centos-7/
CONN="System eth1"
nmcli connection modify "$CONN" +ipv4.routes "10.0.0.0/8 10.19.41.254"
nmcli connection reload
nmcli connection up "$CONN"


