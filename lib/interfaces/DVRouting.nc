#include "../../includes/packet.h"

interface DVRouting{
    command void start();
    command uint16_t getRouting();
    command message_t* updateRouting(message_t* msg, void* payload, uint8_t len);
}