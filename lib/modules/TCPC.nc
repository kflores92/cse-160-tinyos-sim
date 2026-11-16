#include "../../includes/packet.h"

configuration TCPC {
    provides interface TCP;
}

implementation {
    components TCPP;
    TCP = TCPP;
}