# Reminders
In order, to run pingTest.py successfully you must the old version of python.
-- python pingTest.py

In order to run updates you must first compile and then run.
-- make micaz sim
-- python "TestSim.py or pingTest.py"

In order to run a container use:
-- docker start -i (tinyos or container name)

/topo defines the topology of the node network.
We then use loadTopo and bootAll to load and wake up all nodes to run concurrently.

Neighbor Discovery is sending out a packet using AMBroadcast without a destination, with
a message for all other nodes to send back their addresses.

s.neighborDis(src, packet);

Flooding is a routing protocol to find a path from a src node to a destination node
using AMBroadcast, to find a potential path.

s.flood(src, dest, packet);