#!/usr/bin/env bash
#

# set -o xtrace
set -o errexit

# commented out the line below, because qemu in virtual box will never make it
## [ -e /dev/kvm ] || { echo "PROBLEM, you need to ensure nesting is enabled"; exit 1; }

yum install -y git emacs vim wget tmux
yum install -y python3 python3-devel

