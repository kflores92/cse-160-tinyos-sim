#include <Timer.h>
#include "../../includes/packet.h"

configuration NDiscoveryC {
    provides interface NDiscovery;
}

implementation {
    components NDiscoveryP;
    NDiscovery = NDiscoveryP;

    components new TimerMilliC() as neighborTimer;
    components RandomC as Random;
    components new SimpleSendC(AM_PACK) as Sender;

    NDiscoveryP.neighborTimer -> neighborTimer;
    NDiscoveryP.Random -> Random;
    NDiscoveryP.Sender -> Sender;
}