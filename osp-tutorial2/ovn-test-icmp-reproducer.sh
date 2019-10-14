#!/bin/bash


cleanup() {
    if ! which ovn-nbctl 2>&1 > /dev/null ; then
        # OVN not yet installed, nothing to cleanup
        return
    fi
    sudo ovs-vsctl del-port ns1
    sudo ovs-vsctl del-port ns2
    sudo ovs-vsctl del-port ns3
    sudo ip netns delete ns1
    sudo ip netns delete ns2
    sudo ip netns delete ns3
    sudo ovn-nbctl lsp-del sw0-port1
    sudo ovn-nbctl lsp-del sw0-port2
    sudo ovn-nbctl lsp-del sw1-port1
    sudo ovn-nbctl lsp-del lrp0-attachment
    sudo ovn-nbctl lsp-del lrp1-attachment
    sudo ovn-nbctl lr-del lr0
    sudo ovn-nbctl ls-del sw0
    sudo ovn-nbctl ls-del sw1
}
if [ "$1" = "cleanup" ] ; then
    cleanup
    exit 0
fi


# Add a repo for where we can get OVS 2.6 packages
if [ ! -f /etc/yum.repos.d/delorean-deps.repo ] ; then
    curl -L http://trunk.rdoproject.org/centos7/delorean-deps.repo | sudo tee /etc/yum.repos.d/delorean-deps.repo
fi
sudo yum install -y libibverbs
sudo yum install -y openvswitch openvswitch-ovn-central openvswitch-ovn-host
for n in openvswitch ovn-northd ovn-controller ; do
    sudo systemctl enable $n
    sudo systemctl start $n
    systemctl status $n
done
sudo ovs-vsctl set open . external-ids:ovn-remote=unix:/var/run/openvswitch/ovnsb_db.sock
sudo ovs-vsctl set open . external-ids:ovn-encap-type=geneve
sudo ovs-vsctl set open . external-ids:ovn-encap-ip=127.0.0.1


sudo setenforce 0


sudo ovn-nbctl ls-add sw0
sudo ovn-nbctl lsp-add sw0 sw0-port1
sudo ovn-nbctl lsp-set-addresses sw0-port1 "50:54:00:00:00:01 192.168.0.2"
sudo ovn-nbctl lsp-add sw0 sw0-port2
sudo ovn-nbctl lsp-set-addresses sw0-port2 "50:54:00:00:00:02 192.168.0.3"
sudo ovn-nbctl ls-add sw1
sudo ovn-nbctl lsp-add sw1 sw1-port1
sudo ovn-nbctl lsp-set-addresses sw1-port1 "50:54:00:00:00:03 11.0.0.2"
sudo ovn-nbctl lr-add lr0
sudo ovn-nbctl show
sudo ovn-nbctl lrp-add lr0 lrp0 00:00:00:00:ff:01 192.168.0.1/24
sudo ovn-nbctl lsp-add sw0 lrp0-attachment
sudo ovn-nbctl lsp-set-type lrp0-attachment router
sudo ovn-nbctl lsp-set-addresses lrp0-attachment 00:00:00:00:ff:01
sudo ovn-nbctl lsp-set-options lrp0-attachment router-port=lrp0
sudo ovn-nbctl lrp-add lr0 lrp1 00:00:00:00:ff:02 11.0.0.1/24
sudo ovn-nbctl lsp-add sw1 lrp1-attachment
sudo ovn-nbctl lsp-set-type lrp1-attachment router
sudo ovn-nbctl lsp-set-addresses lrp1-attachment 00:00:00:00:ff:02
sudo ovn-nbctl lsp-set-options lrp1-attachment router-port=lrp1


add_phys_port() {
    name=$1
    mac=$2
    ip=$3
    mask=$4
    gw=$5
    iface_id=$6
    sudo ip netns add $name
    sudo ovs-vsctl add-port br-int $name -- set interface $name type=internal
    sudo ip link set $name netns $name 
    sudo ip netns exec $name ip link set $name address $mac
    sudo ip netns exec $name ip addr add $ip/$mask dev $name 
    sudo ip netns exec $name ip link set $name up
    sudo ip netns exec $name ip route add default via $gw
    sudo ovs-vsctl set Interface $name external_ids:iface-id=$iface_id
}


add_phys_port ns1 50:54:00:00:00:01 192.168.0.2 24 192.168.0.1 sw0-port1
add_phys_port ns2 50:54:00:00:00:02 192.168.0.3 24 192.168.0.1 sw0-port2
add_phys_port ns3 50:54:00:00:00:03 11.0.0.2 24 11.0.0.1 sw1-port1


msg() {
    echo
    echo "***"
    echo "*** $1" 
    echo "***"
    echo
}


msg "Starting with no ACLs"


msg "sw0-port1 (192.168.0.2) can ping sw0-port2 (192.168.0.3)"
sudo ip netns exec ns1 ping -c 5 192.168.0.3


msg "sw0-port1 (192.168.0.2) can ping sw1-port1 (11.0.0.2)"
sudo ip netns exec ns1 ping -c 5 11.0.0.2


msg "sw0-port2 (192.168.0.3) can ping logical router IP (192.168.0.1)"
sudo ip netns exec ns2 ping -c 5 192.168.0.1


msg "sw0-port1 (192.168.0.2) can ping logical router IP (192.168.0.1)"
sudo ip netns exec ns1 ping -c 5 192.168.0.1


msg "Adding ACLs for sw0-port1 (192.168.0.2) "


# ACLs for sw0-port1
#  - allow all outgoing traffic and related reply traffic
#  - deny all incoming traffic not a part of an existing connection
sudo ovn-nbctl --wait=hv acl-add sw0 from-lport 1001 'inport == "sw0-port1" && ip' allow-related
sudo ovn-nbctl --wait=hv acl-add sw0 to-lport 1001 'outport == "sw0-port1" && ip' drop
sudo ovn-nbctl acl-list sw0


msg "sw0-port1 (192.168.0.2) can ping sw0-port2 (192.168.0.3)"
sudo ip netns exec ns1 ping -c 5 192.168.0.3


msg "sw0-port1 (192.168.0.2) can ping sw1-port1 (11.0.0.2)"
sudo ip netns exec ns1 ping -c 5 11.0.0.2


msg "sw0-port2 (192.168.0.3) can ping logical router IP (192.168.0.1)"
sudo ip netns exec ns2 ping -c 5 192.168.0.1


msg "BUG: sw0-port1 (192.168.0.2) can NOT ping logical router IP (192.168.0.1)"
sudo ip netns exec ns1 ping -c 5 192.168.0.1
