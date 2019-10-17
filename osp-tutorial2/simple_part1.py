#!/usr/bin/env python
from __future__ import print_function

import os
import sys

from ovsdbapp.backend import ovs_idl
from ovsdbapp.backend.ovs_idl import connection
from ovsdbapp.schema.ovn_northbound import impl_idl

conn = "tcp:127.0.0.1:6641"
print("Connecting to", conn, file=sys.stderr)

# The python-ovs Idl class
i = connection.OvsdbIdl.from_server(conn, 'OVN_Northbound')
# The ovsdbapp Connection object
c = connection.Connection(i, 5)
# The OVN_Northbound API implementation object
api = impl_idl.OvnNbApiIdlImpl(c)

# access the table direcly
# for row in api.tables['NB_Global'].rows.values():
#     print(row.uuid)
#     print(row.nb_cfg)

mimic_commands = """
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
"""

# add a logical switch sw0
api.ls_add("sw0").execute(check_error=True)

# add logical switch port and addresses
api.lsp_add("sw0", "sw0-port1").execute(check_error=True)
api.lsp_set_addresses("sw0-port1", ["50:54:00:00:00:01 192.168.0.2"]).execute(check_error=True)
api.lsp_add("sw0", "sw0-port2").execute(check_error=True)
api.lsp_set_addresses("sw0-port2", ["50:54:00:00:00:02 192.168.0.3"]).execute(check_error=True)

# add a logical switch sw1
api.ls_add("sw1").execute(check_error=True)
api.lsp_add("sw1", "sw1-port1").execute(check_error=True)
api.lsp_set_addresses("sw1-port1", ["50:54:00:00:00:03 11.0.0.2"]).execute(check_error=True)


api.lr_add("lr0").execute(check_error=True)

api.lrp_add("lr0", "lrp0", mac="00:00:00:00:ff:01", networks=["192.168.0.1/24"]).execute(check_error=True)
api.lsp_add("sw0", "lrp0-attachment").execute(check_error=True)
api.lsp_set_type("lrp0-attachment", "router").execute(check_error=True)
api.lsp_set_addresses("lrp0-attachment", ["00:00:00:00:ff:01"]).execute(check_error=True)
lrp0Options={"router-port": "lrp0"}
api.lsp_set_options("lrp0-attachment", **lrp0Options).execute(check_error=True)

api.lrp_add("lr0", "lrp1", mac="00:00:00:00:ff:02", networks=["11.0.0.1/24"]).execute(check_error=True)
api.lsp_add("sw1", "lrp1-attachment").execute(check_error=True)
api.lsp_set_type("lrp1-attachment", "router").execute(check_error=True)
api.lsp_set_addresses("lrp1-attachment", ["00:00:00:00:ff:02"]).execute(check_error=True)
lrp1Options={"router-port": "lrp1"}
api.lsp_set_options("lrp1-attachment", **lrp1Options).execute(check_error=True)

mimic_commands_acl = """
# ACLs for sw0-port1
#  - allow all outgoing traffic and related reply traffic
#  - deny all incoming traffic not a part of an existing connection
sudo ovn-nbctl --wait=hv acl-add sw0 from-lport 1001 'inport == "sw0-port1" && ip' allow-related
sudo ovn-nbctl --wait=hv acl-add sw0 to-lport 1001 'outport == "sw0-port1" && ip' drop
sudo ovn-nbctl acl-list sw0
"""

api.acl_add("sw0", direction="from-lport", priority=1001, match='inport == "sw0-port1" && ip',
            action='allow-related').execute(check_error=True)
api.acl_add("sw0", direction="to-lport", priority=1001, match='outport == "sw0-port1" && ip',
            action='drop').execute(check_error=True)

# Loop through rows returned from an API call
for row in api.ls_list().execute(check_error=True):
    print("uuid: %s, name: %s" % (row.uuid, row.name))
    for row2 in api.lsp_list(switch=row.uuid).execute(check_error=True):
        print("  uuid: %s, name: %s" % (row2.uuid, row2.name))

