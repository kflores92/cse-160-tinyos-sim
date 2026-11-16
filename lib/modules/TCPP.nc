#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/socket.h"

module TCPP {
    provides interface TCP;

    uses interface Hashmap<socket_store_t> as Sockets;
    uses interface Tinynet;
}

implementation {
    uint8_t numSockets = 0;

    command void TCP.start(){

    }

    event void Tinynet.transportPacketRecieve(transport* myMsg, uint16_t src){

    }

}