#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/neighbor.h"

configuration NDiscoveryC {
    provides interface NDiscovery;
}

implementation {
    components NDiscoveryP;
    NDiscovery = NDiscoveryP;

    components new TimerMilliC() as neighborTimer;
    components RandomC as Random;
    components new SimpleSendC(AM_PACK) as Sender;
    components new HashmapC(stats, 64) as Cache;
    components new AMReceiverC(AM_PACK) as GeneralReceive;

    NDiscoveryP.neighborTimer -> neighborTimer;
    NDiscoveryP.Random -> Random;
    NDiscoveryP.Sender -> Sender;
    NDiscoveryP.Cache -> Cache;
    NDiscoveryP.Receive -> GeneralReceive;
}