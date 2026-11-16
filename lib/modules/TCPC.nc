#include "../../includes/packet.h"
#include "../../includes/socket.h"

configuration TCPC {
    provides interface TCP;
}

implementation {
    components TCPP;
    TCP = TCPP;

    components new HashmapC(socket_store_t, MAX_NUM_OF_SOCKETS) as Sockets;
    TCPP.Sockets -> Sockets;

    components TinynetC as Tinynet;
    TCPP.Tinynet -> Tinynet;
}