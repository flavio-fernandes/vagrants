#!/usr/bin/env bash
#

# set -o xtrace
set -o errexit

[ -e /dev/kvm ] || { echo "PROBLEM, you need to ensure nesting is enabled"; exit 1; }

yum install -y git emacs wget

