#include "../../includes/packet.h"

configuration NetworkC {
    provides interface Network;
}

implementation {
    
    //wire upper layer
    components NetworkP;
    Network = NetworkP;

    //wire to DV
    components DVRoutingC as DVRouting;
    NetworkP.DVRouting -> DVRouting;

    //wire to link layer
    components new SimpleSendC(AM_PACK) as Sender;
    NetworkP.Sender -> Sender;

    //wire packet interface
    components ActiveMessageC as Packet;
    NetworkP.Packet -> Packet;

}