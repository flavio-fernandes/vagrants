#!/usr/bin/env python
from __future__ import print_function

import os
import sys

from ovsdbapp.backend import ovs_idl
from ovsdbapp.backend.ovs_idl import connection
from ovsdbapp.schema.ovn_northbound import impl_idl

# Place this file in the ovsdbapp checkout
# From an ovs checkout that has already been built, do:
# tutorial/ovs-sandbox --ovn

# just some parsing of the ovs-sandbox set environment variables
protocol, url = os.environ['OVN_NB_DB'].split(':')
if protocol != 'unix':
    print(protocol, "is unsupported.", file=sys.stderr)
    sys.exit(1)
DB = os.path.join(os.environ['OVS_DBDIR'], url)
conn = '%s:%s' % (protocol, DB)
print("Connecting to", conn, file=sys.stderr)

# The python-ovs Idl class
i = connection.OvsdbIdl.from_server(conn, 'OVN_Northbound')
# The ovsdbapp Connection object
c = connection.Connection(i, 5)
# The OVN_Northbound API implementation object
api = impl_idl.OvnNbApiIdlImpl(c)

# access the table direcly
for row in api.tables['NB_Global'].rows.values():
    print(row.uuid)
    print(row.nb_cfg)

# add a logical switch
api.ls_add("testbr").execute(check_error=True)

# Loop through rows returned from an API call
for row in api.ls_list().execute(check_error=True):
    print("uuid: %s, name: %s" % (row.uuid, row.name))

