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
    components new TimerMilliC() as routingTimer;
    components RandomC as Random;
    components new HashmapC(stats, 64) as routingTable;
    components new SimpleSendC(AM_PACK) as Sender;
    components NDiscoveryC as NDiscovery;

    DVRouting.startTimer -> startTimer;
    DVRouting.routingTimer -> routingTimer;
    DVRouting.Random -> Random;
    DVRouting.routingTable -> routingTable;
    DVRouting.Sender -> Sender;
    DVRoutingP.NDiscovery -> NDiscovery;
}