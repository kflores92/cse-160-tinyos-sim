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
    void makePack(pack *Package, uint16_t origin, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void makeTuple(tuple *Tuple, uint8_t dest, uint8_t next_hop, uint8_t cost);
    uint32_t* arrCopy(const uint32_t* a, size_t n);

    command void DVRouting.start(){
        
        tuple routeInfo;
        int i;
        call startTimer.startOneShot(4000 + (uint16_t) (call Random.rand16()%500));

        //Initialize Routing Table with 0 and Infinity
        makeTuple(&routeInfo, TOS_NODE_ID, TOS_NODE_ID, 0);
        call routingTable.insert(TOS_NODE_ID, routeInfo);
    }

    command void DVRouting.printRoutingTable() {
        uint8_t i;
        uint32_t* routes;
        uint32_t current;
        tuple storedRoute;

        //Print Routing Table
        table = call routingTable.getKeys();
        dbg(ROUTING_CHANNEL, "\n\n\n\n");
        dbg(ROUTING_CHANNEL, "---------------------\n");
        dbg(ROUTING_CHANNEL, "Routing Table Size: %d. \n", call routingTable.size());
        routes = call routingTable.getKeys();
        for(i = 0; i < call routingTable.size(); i++){
            current = routes[i];
            storedRoute = call routingTable.get(current);
            dbg(ROUTING_CHANNEL, "Dest: %d | Next Hop: %d | Cost: %d . \n", storedRoute.dest, storedRoute.next_hop, storedRoute.cost);
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
        tuple newInfo;
        tuple routeInfo[MAX_PAYLOAD_TUPLES];
        message_t* pkt;
        bool invalidNextHop;
        uint16_t currentTableSize = call NDiscovery.getTableSize();
        uint32_t neighborNode;
        uint32_t* routes;
        uint32_t current;
        uint16_t routingTableSize;
        uint16_t fullPackets;
        uint16_t remainingPackets;
        uint8_t* payload;
        uint32_t i;
        uint32_t j;
        uint32_t p;
        
        //Every 1.5 Seconds

        //Update Neighbor Information
        if(currentTableSize != neighborTableSize){

            for(i = 0; i < neighborTableSize; i++){
                neighborNode = neighborTableCopy[i];
                makeTuple(&storedInfo, neighborNode, INVALID_NH, INF);
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
            
            routes = call routingTable.getKeys();
            for(j = 0; j < call routingTable.size(); j++) {
                current = routes[j];
                storedInfo = call routingTable.get(current);
                invalidNextHop = TRUE;

                for(i = 0; i < neighborTableSize; i++){
                    neighborNode = neighborTable[i];
                    if(storedInfo.next_hop == neighborNode){
                        invalidNextHop = FALSE;
                    }
                }

                if(invalidNextHop && (j != TOS_NODE_ID)){
                    makeTuple(&newInfo, storedInfo.dest, INVALID_NH, INF);
                    call routingTable.insert(j, newInfo);
                }
            }
        }

        
        //Send Routing Information to Neighbors

        for(i = 0; i < neighborTableSize; i++){
            neighborNode = neighborTable[i];
            routes = call routingTable.getKeys();
            routingTableSize = call routingTable.size();
            fullPackets = routingTableSize / MAX_PAYLOAD_TUPLES;
            remainingPackets = routingTableSize % MAX_PAYLOAD_TUPLES;

            for(j = 0; j < fullPackets; j++){
                for(p = 0; p < MAX_PAYLOAD_TUPLES; p++){
                    routeInfo[p] = call routingTable.get(routes[(j * MAX_PAYLOAD_TUPLES) + p]);
                    if(routeInfo[p].next_hop == neighborNode){
                        routeInfo[p].cost = INF;
                    } 
                }

                payload = (uint8_t*) routeInfo;
                //Since DVRouting doesn't utilize origin we are repurposing it to payload struct count;
                makePack(&adPacket, MAX_PAYLOAD_TUPLES, TOS_NODE_ID, neighborNode, 1, PROTOCOL_DV, routeSeq, payload, PACKET_MAX_PAYLOAD_SIZE);
                call Sender.send(adPacket, neighborNode);
            }

            for(p = 0; p < remainingPackets; p++){
                routeInfo[p] = call routingTable.get(routes[(fullPackets * MAX_PAYLOAD_TUPLES) + p]);
                if(routeInfo[p].next_hop == neighborNode){
                    routeInfo[p].cost = INF;
                } 
            }

            if(remainingPackets != 0) { 
                payload = (uint8_t*) routeInfo;
                //Since DVRouting doesn't utilize origin we are repurposing it to payload struct count;
                makePack(&adPacket, remainingPackets, TOS_NODE_ID, neighborNode, 1, PROTOCOL_DV, routeSeq, payload, PACKET_MAX_PAYLOAD_SIZE);
                call Sender.send(adPacket, neighborNode);
            }
        }

        routeSeq = routeSeq + 1;

    }

    command message_t* DVRouting.updateRouting(message_t* msg, void* payload, uint8_t len) {

        if(len == sizeof(pack)){
            pack* recieveAd = (pack*)payload;
            tuple* routeInfo = (tuple*) recieveAd->payload;
            tuple storedInfo;
            uint16_t numPackets = recieveAd->origin; //Repurposed Struct Count
            uint8_t i;
            uint8_t j;
            
            for(i = 0; i < numPackets; i++){
                
                if(call routingTable.contains(routeInfo[i].dest)) {
                    storedInfo = call routingTable.get(routeInfo[i].dest);

                    if(routeInfo[i].cost + 1 < storedInfo.cost){
                        makeTuple(&storedInfo, routeInfo[i].dest, recieveAd->src, routeInfo[i].cost + 1);
                        call routingTable.insert(routeInfo[i].dest, storedInfo);
                    }
                }else {
                    if(routeInfo[i].cost + 1 < INF){
                        makeTuple(&storedInfo, routeInfo[i].dest, recieveAd->src, routeInfo[i].cost + 1);
                        call routingTable.insert(routeInfo[i].dest, storedInfo);
                    }
                }
            }

            return msg;
        }else {
            return msg;
        }
    }

    command uint8_t DVRouting.getRouting(uint8_t dest) {

        tuple routingInfo;
        makeTuple(&routingInfo, dest, INVALID_NH, INF);

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