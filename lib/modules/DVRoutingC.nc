#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/neighbor.h"
#include "../../includes/routing.h"

configuration DVRoutingC {
    provides interface DVRouting;
}

implementation {

    components DVRoutingP;
    DVRouting = DVRoutingP;

    components new TimerMilliC() as startTimer;
    DVRoutingP.startTimer -> startTimer;

    components new TimerMilliC() as routingTimer;
    DVRoutingP.routingTimer -> routingTimer;

    components RandomC as Random;
    DVRoutingP.Random -> Random;

    components new HashmapC(tuple, 255) as routingTable;
    DVRoutingP.routingTable -> routingTable;

    components new HashmapC(valid, 255) as validTable;
    DVRoutingP.validTable -> validTable;

    components new SimpleSendC(AM_PACK) as Sender;
    DVRoutingP.Sender -> Sender;

    components NDiscoveryC as NDiscovery;
    DVRoutingP.NDiscovery -> NDiscovery;

    components ActiveMessageC as Packet;
    DVRoutingP.Packet -> Packet;
}