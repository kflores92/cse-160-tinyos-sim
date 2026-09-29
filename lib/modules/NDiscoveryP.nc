#include "../../includes/channels.h"
#include "../../includes/packet.h"

module NDiscoveryP {
    provides interface NDiscovery;

    uses interface Timer<TMilli> as neighborTimer;
    uses interface Random;
    uses interface SimpleSend as Sender;
}

implementation {
    
    command void NDiscovery.start() {
        call neighborTimer.startOneShot(500 + (uint16_t) (call Random.rand16()%500));

    }

    event void neighborTimer.fired() {
        dbg(NEIGHBOR_CHANNEL, "Neighbor timer is fired");
    }

    command void NDiscovery.printNeighbors() {

    }

    /*
        1. Find out our own node's address.
        2. Use SimpleSend with dest AM_BROADCAST_ADDR, we need a packet.
        3. Send a package to all neighbors every time the timer fires.
        4. Have a reciever
    */

}