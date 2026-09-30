#include "../../includes/packet.h"

configuration FloodingC {
    provides interface Flooding;
}

implementation {

    components FloodingP;
    Flooding = FloodingP;

    components RandomC as Random;
    FloodingP.Random -> Random;

    components new SimpleSendC(AM_PACK) as Sender;
    FloodingP.Sender -> Sender;

    components new AMReceiverC(AM_PACK) as GeneralReceive;
    FloodingP.Receive -> GeneralReceive;

    components new HashmapC(pack*, 64) as Cache;
    FloodingP.Cache -> Cache;
}