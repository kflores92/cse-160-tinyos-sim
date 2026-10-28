#include "../../includes/packet.h"

configuration TinynetC {
    provides interface Tinynet;
}

implementation {
    
    //wire upper layer
    components TinynetP;
    Tinynet = TinynetP;

    //wire to DV
    components DVRoutingC as DVRouting;
    TinynetP.DVRouting -> DVRouting;


    //wire to link layer
    components new SimpleSendC(AM_PACK) as Sender;
    TinynetP.Sender -> Sender;

    //wire packet interface
    components ActiveMessageC as Packet;
    TinynetP.Packet -> Packet;

}