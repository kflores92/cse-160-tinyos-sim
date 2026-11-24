#include "../../includes/packet.h"

configuration TCPC {
    provides interface TCP;
}

implementation {
    components TCPP;
    TCP = TCPP;

    //including timer component to resend packets after timeout
    components new TimerMilliC() as resend;
    TCPP.resend -> resend;

    

    //wiring TCP module to the TinynetC component for sending and receiving packets
    components TinynetC;
    TCPP.Tinynet -> TinynetC;

}