#include "../../includes/packet.h"

interface DVRouting {
    command void start();
    command void printRoutingTable();
    command uint8_t getRouting(uint8_t dest);
    command message_t* updateRouting(message_t* msg, void* payload, uint8_t len);
}