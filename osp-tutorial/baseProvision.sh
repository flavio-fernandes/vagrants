#!/usr/bin/env bash
#

# set -o xtrace
set -o errexit

# commented out the line below, because qemu in virtual box will never make it
## [ -e /dev/kvm ] || { echo "PROBLEM, you need to ensure nesting is enabled"; exit 1; }

#yum install -y git emacs wget
apt-get update
apt install -y git emacs wget
apt install -y vim telnet tmate
apt install -y python3-dev
