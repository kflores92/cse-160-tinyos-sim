#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/connection.h"

configuration TCPC {
    provides interface TCP;
}

implementation {

    components TCPP;
    TCP = TCPP;

    components TinynetC as Tinynet;
    TCPP.Tinynet -> Tinynet;

    components new HashmapC(conn_store, 255) as Ports;
    TCPP.Ports -> Ports;

    components new TimerMilliC() as Timeout;
    TCPP.Timeout -> Timeout;
}