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

    # TODO: make this happen via osvdbapp as well
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
#if [ ! -f /etc/yum.repos.d/delorean-deps.repo ] ; then
#    curl -L http://trunk.rdoproject.org/centos7/delorean-deps.repo | sudo tee /etc/yum.repos.d/delorean-deps.repo
#fi
#sudo yum install -y libibverbs
#sudo yum install -y openvswitch openvswitch-ovn-central openvswitch-ovn-host
#for n in openvswitch ovn-northd ovn-controller ; do
#    sudo systemctl enable $n
#    sudo systemctl start $n
#    systemctl status $n
#done

sudo ovs-vsctl set open . external-ids:ovn-remote=unix:/var/run/openvswitch/ovnsb_db.sock
sudo ovs-vsctl set open . external-ids:ovn-encap-type=geneve
sudo ovs-vsctl set open . external-ids:ovn-encap-ip=127.0.0.1

sudo setenforce 0

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

function do_ping {
     local instance=$1
     local target=$2
     sudo ip netns exec $instance ping -c 1 -W 1 $2 > /dev/null
}
function assert_ping {
     ! do_ping $@ && echo "$1 was not able to reach $2" && exit
     #echo "$1 could reach $2 as expected"
}
function assert_no_ping {
     do_ping $@ && echo "$1 was unexpectedly able to reach $2" && exit
     #echo "$1 could not reach $2 as expected"
}

msg "sw0-port1 (192.168.0.2) can ping sw0-port2 (192.168.0.3)"
assert_ping ns1 192.168.0.3
#sudo ip netns exec ns1 ping -c 2 192.168.0.3

msg "sw0-port1 (192.168.0.2) can ping sw1-port1 (11.0.0.2)"
assert_ping ns1 11.0.0.2
#sudo ip netns exec ns1 ping -c 2 11.0.0.2

msg "sw0-port2 (192.168.0.3) can ping logical router IP (192.168.0.1)"
assert_ping ns2 192.168.0.1
#sudo ip netns exec ns2 ping -c 2 192.168.0.1

msg "sw0-port1 (192.168.0.2) can ping logical router IP (192.168.0.1)"
assert_ping ns1 192.168.0.1
#sudo ip netns exec ns1 ping -c 2 192.168.0.1

msg "sw0-port1 (192.168.0.2) can ping sw0-port2 (192.168.0.3)"
assert_ping ns1 192.168.0.3
#sudo ip netns exec ns1 ping -c 2 192.168.0.3

msg "sw0-port1 (192.168.0.2) can ping sw1-port1 (11.0.0.2)"
assert_ping ns1 11.0.0.2
#sudo ip netns exec ns1 ping -c 2 11.0.0.2

msg "sw0-port2 (192.168.0.3) cannot ping sw0-port1 (192.168.0.2)"
assert_no_ping ns2 192.168.0.2

