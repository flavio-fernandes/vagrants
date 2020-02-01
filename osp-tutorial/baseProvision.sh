#!/usr/bin/env bash
#

# set -o xtrace
set -o errexit

# NOTE: Assuming we are in an intel based system...
[ -e /dev/kvm ] || { echo "PROBLEM, you need to ensure hv can nest"; exit 1; }
grep -q Y /sys/module/kvm_intel/parameters/nested || {
  sudo rmmod kvm-intel
  sudo sh -c "echo 'options kvm-intel nested=y' >> /etc/modprobe.d/dist.conf"
  sudo modprobe kvm-intel
}
modinfo kvm_intel | grep -q 'nested:bool' || { echo "PROBLEM, nesting did not enable"; exit 1; }

yum install -y git emacs vim wget tmux
yum install -y python3 python3-devel

