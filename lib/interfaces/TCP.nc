#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/socket.h"
#include "../../includes/connection.h"

interface TCP {
    command void start();

    command error_t startServer(uint8_t listenPort);

    command error_t startClient(uint16_t destAddr, uint8_t srcPort, uint8_t destPort, uint16_t transferBytes);

}