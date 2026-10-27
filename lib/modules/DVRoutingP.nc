#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/routing.h"
#include "../../includes/protocol.h"

module DVRoutingP {
    provides interface DVRouting;

    uses interface Timer<TMilli> as startTimer;
    uses interface Timer<TMilli> as routingTimer;
    uses interface Random;
    uses interface Hashmap<tuple> as routingTable;
    uses interface SimpleSend as Sender;
    uses interface NDiscovery;
    uses interface Packet;
}

implementation {

    uint16_t routeSeq = 0;
    uint32_t* table = 0;
    uint32_t* neighborTable;
    uint32_t* neighborTableCopy;
    uint16_t neighborTableSize;
    tuple route;
    void makePack(pack *Package, uint16_t origin, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void makeTuple(tuple *Tuple, uint8_t dest, uint8_t next_hop, uint8_t cost);
    uint32_t* arrCopy(const uint32_t* a, size_t n);

    command void DVRouting.start(){
        
        tuple routeInfo;
        int i;
        call startTimer.startOneShot(4000 + (uint16_t) (call Random.rand16()%500));

        //Initialize Routing Table with 0 and Infinity
        for(i = 1; i <= MAX_NODES; i++){
            if(i == TOS_NODE_ID){
                makeTuple(&routeInfo, TOS_NODE_ID, TOS_NODE_ID, 0);
                call routingTable.insert(i, routeInfo);
            }else{
                makeTuple(&routeInfo, i, INF, INF);
                call routingTable.insert(i, routeInfo);
            }
            
        }
    }

    command void DVRouting.printRoutingTable() {
        uint8_t i;

        //Print Routing Table
        table = call routingTable.getKeys();
        dbg(ROUTING_CHANNEL, "\n\n\n\n");
        dbg(ROUTING_CHANNEL, "---------------------\n");
        
        dbg(ROUTING_CHANNEL, "Routing Table Size: %d. \n", call routingTable.size());
        for(i = 0; i < call routingTable.size(); i++){
            route = call routingTable.get(table[i]);
            dbg(ROUTING_CHANNEL, "Dest: %d | Next Hop: %d | Cost: %d . \n", route.dest, route.next_hop, route.cost);
        }
        dbg(ROUTING_CHANNEL, "---------------------\n");
        dbg(ROUTING_CHANNEL, "\n\n\n\n");
    }

    event void startTimer.fired(){

        tuple routeInfo;
        uint32_t i;
        uint32_t neighborNode;

        //Initialize Neighbor Information
        neighborTable = call NDiscovery.getNeighbors();
        neighborTableSize = call NDiscovery.getTableSize();
        neighborTableCopy = arrCopy(neighborTable, neighborTableSize);

        for(i = 0; i < neighborTableSize; i++){
            neighborNode = neighborTable[i];
            makeTuple(&routeInfo, neighborNode, neighborNode, 1);
            call routingTable.insert(neighborNode, routeInfo);
        }

        call routingTimer.startPeriodic(1500 + (uint16_t) (call Random.rand16()%500));

    }

    event void routingTimer.fired() {

        pack adPacket;
        tuple storedInfo;
        tuple routeInfo[MAX_PAYLOAD_TUPLES];
        uint16_t currentTableSize = call NDiscovery.getTableSize();
        uint32_t neighborNode;
        uint8_t* payload;
        uint32_t i;
        uint32_t j;
        uint32_t p;
        
        //Every 1.5 Seconds

        //Update Neighbor Information
        if(currentTableSize != neighborTableSize){

            for(i = 0; i < neighborTableSize; i++){
                neighborNode = neighborTableCopy[i];
                makeTuple(&storedInfo, neighborNode, INF, INF);
                call routingTable.insert(neighborNode, storedInfo);
            }

            neighborTableSize = currentTableSize;
            free(neighborTableCopy);
            neighborTableCopy = arrCopy(neighborTable, neighborTableSize);

            for(i = 0; i < neighborTableSize; i++){
                neighborNode = neighborTable[i];
                makeTuple(&storedInfo, neighborNode, neighborNode, 1);
                call routingTable.insert(neighborNode, storedInfo);
            }
        }
        
        //Send Routing Information to Neighbors

        for(i = 0; i < neighborTableSize; i++){
            neighborNode = neighborTable[i];
            
            for(j = 0; j <= call routingTable.size()/MAX_PAYLOAD_TUPLES; j++){
                for(p = 1; p <= MAX_PAYLOAD_TUPLES; p++){
                    routeInfo[p - 1] = call routingTable.get((j * MAX_PAYLOAD_TUPLES) + p);
                }

                payload = (uint8_t*) routeInfo;
                makePack(&adPacket, TOS_NODE_ID, TOS_NODE_ID, neighborNode, 1, PROTOCOL_DV, routeSeq, payload, PACKET_MAX_PAYLOAD_SIZE);
                //call Sender.send(adPacket, neighborNode);
            }
        }

        routeSeq = routeSeq + 1;

    }

    command message_t* DVRouting.updateRouting(message_t* msg, void* payload, uint8_t len) {
        
        /*
        if(len == sizeof(pack)){
            pack* recieveAd = (pack*)payload;
            tuple* routeInfo = (tuple*)recieveAd->payload;
            tuple currentInfo;
            tuple nextHop;
            tuple newInfo;
            uint32_t i;

            for(i = 1; i <= call routingTable.size(); i++){
                if(i == (routeInfo->dest)){
                    currentInfo = call routingTable.get(i);
                    nextHop = call routingTable.get((uint32_t)recieveAd->src);
                    if((routeInfo->cost + nextHop.cost) < currentInfo.cost){
                        makeTuple(&newInfo, routeInfo->dest, (routeInfo->cost + nextHop.cost));
                        call routingTable.insert((int)i, newInfo);
                    }
                }
            }

            return msg;
        }else {
            return msg;
        }
        */
    }

    command uint8_t DVRouting.getRouting(uint8_t dest) {

        tuple routingInfo;
        makeTuple(&routingInfo, dest, TOS_NODE_ID, INF);

        if(call routingTable.contains(dest)){
            routingInfo = call routingTable.get(dest);
            return routingInfo.next_hop;
        }else {
            return routingInfo.next_hop;
        }

    }

    void makePack(pack *Package, uint16_t origin, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->origin = origin;
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }

    void makeTuple(tuple *Tuple, uint8_t dest, uint8_t next_hop, uint8_t cost) {
        Tuple->dest = dest;
        Tuple->next_hop = next_hop;
        Tuple->cost = cost;
    }

    uint32_t* arrCopy(const uint32_t* a, size_t n) {
        size_t i = 0;
        uint32_t *b = malloc(n * sizeof(uint32_t));

        for(i = 0; i < n; i++) {
            *( b + i ) = *( a + i );
        }

        return b;
    }
}