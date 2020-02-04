#!/usr/bin/env bash
#

# set -o xtrace
set -o errexit

# commented out the line below, because qemu in virtual box will never make it
[ -e /dev/kvm ] || { echo "PROBLEM, you need to ensure hv can nest"; exit 1; }
grep -q Y /sys/module/kvm_intel/parameters/nested || {
  sudo rmmod kvm-intel
  sudo sh -c "echo 'options kvm-intel nested=y' >> /etc/modprobe.d/dist.conf"
  sudo modprobe kvm-intel
}
modinfo kvm_intel | grep -q 'nested:bool' || { echo "PROBLEM, nesting did not enable"; exit 1; }

yum install -y git emacs wget vim telnet
yum install -y python3 python3-devel
