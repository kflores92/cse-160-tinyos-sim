#include "../../includes/channels.h"
#include "../../includes/packet.h"

module NDiscoveryP {
    provides interface NDiscovery;

    uses interface Timer<TMilli> as neighborTimer;
    uses interface Random;
    uses interface SimpleSend as Sender;
    uses interface Receive;
    uses interface Hashmap<uint8_t> as Cache;
}

implementation {
    
    command void NDiscovery.start() {
        call neighborTimer.startOneShot(500 + (uint16_t) (call Random.rand16()%500));

    }

    event void neighborTimer.fired() {
        dbg(NEIGHBOR_CHANNEL, "Neighbor timer is fired. \n");
    }

    command void NDiscovery.printNeighbors() {

    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t length){

    }

}