#include "../../includes/packet.h"

interface DVRouting{
    command void start();
    command uint16_t getRouting(uint16_t dest);
    command message_t* updateRouting(message_t* msg, void* payload, uint8_t len);
}