#!/bin/bash

set -x

sudo /usr/share/openvswitch/scripts/ovn-ctl stop_northd
sudo rm -rf /etc/openvswitch/ovnnb_db.db  /etc/openvswitch/ovnsb_db.db
sudo /usr/share/openvswitch/scripts/ovn-ctl start_northd

sleep 1
sudo ovn-nbctl set-connection ptcp:8888 ptcp:6641:127.0.0.1 punix:/tmp/foonb
