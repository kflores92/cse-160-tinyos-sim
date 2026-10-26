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
}

implementation {

    uint16_t routeSeq = 0;
    void makePack(pack *Package, uint16_t origin, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void makeTuple(tuple *Tuple, uint16_t dest, uint16_t next_hop, uint16_t cost);

    command void DVRouting.start(){
        
        tuple* routeInfo;
        int i;
        call startTimer.startOneShot(4000 + (uint16_t) (call Random.rand16()%500));

        for(i = 1; i <= MAX_NODES; i++){
            if(i == TOS_NODE_ID){
                makeTuple(routeInfo, TOS_NODE_ID, TOS_NODE_ID, 0)
                routingTable.insert(i, routeInfo);
            }else{
                makeTuple(routeInfo, i, TOS_NODE_ID, INF);
                routingTable.insert(i, routeInfo);
            }
            
        }
    }

    command void startTimer.fired(){
        tuple* routeInfo;
        int i;
        uint32_t* neighborTable = NDiscovery.getNeighbors();
        uint16_t tableSize = NDiscovery.getTableSize();

        for(i = 0; i < tableSize; i++){
            neighborNode = neighborTable[i];
            makeTuple(routeInfo, neighborNode, neighborNode, 1);
            routingTable.insert(neighborNode, routeInfo);
        }

        call routingTimer.startPeriodic(1500 + (uint16_t) (call Random.rand16()%500));
    }

    command void routingTimer.fired(){
        //Send Routing Information to Neighbors
        pack* adPacket;
        tuple* routeInfo;
        uint32_t* neighborTable = NDiscovery.getNeighbors();
        uint16_t tableSize = NDiscovery.getTableSize();
        uint32_t neighborNode;
        uint8_t* payload;
        int i;
        int j;

        for(i = 0; i < tableSize; i++){
            neighborNode = neighborTable[i];
            makeTuple(routeInfo, neighborNode, neighborNode, 1);
            routingTable.insert(neighborNode, routeInfo);
        }

        for(i = 0; i < tableSize; i++){
            neighborNode = neighborTable[i];
            for(j = 0; j < routingTable.size(); j++){
                routeInfo = routingTable.get(j + 1);
                if(neighborNode != routeInfo.next_hop){
                    payload = routeInfo;
                    makePack(adPacket, TOS_NODE_ID, TOS_NODE_ID, neighborNode, 1, PROTOCOL_DV, routeSeq, payload, PACKET_MAX_PAYLOAD_SIZE);
                    Sender.send(adPacket, neighborNode); 
                }
            }
        }

        routeSeq = routeSeq + 1;
    }

    command message_t* DVRouting.updateRouting(message_t* msg, void* payload, uint8_t len){
        if(len == sizeof(pack)){
            pack* recieveAd = (pack*)payload;
            tuple* routeInfo = (tuple*)recieveAd.payload;
            tuple* currentInfo;
            tuple* nextHop;
            tuple* newInfo;
            int i;

            for(i = 1; i <= routingTable.size(); i++){
                if(i = routeInfo.dest){
                    currentInfo = routingTable.get(i);
                    nextHop = routingTable.get(routeInfo.next_hop);
                    if((routeInfo.cost + nextHop.cost) < currentInfo.cost){
                        makeTuple(newInfo, routeInfo.dest, routeInfo.next_hop, (routeInfo.cost + nextHop.cost));
                        routingTable.insert(i, newInfo);
                    }
                }
            }

            return msg;
        }else {
            return msg;
        }
    }

    command uint16_t DVRouting.getRouting(uint16_t dest) {
        //Return next_hop from Routing Table for a particular dest.
        tuple* routingInfo;
        makeTuple(routingInfo, dest, TOS_NODE_ID, INF);

        if(routingTable.contains(dest)){
            routingInfo = routingTable.get(dest);
            return routingInfo;
        }else {
            return routingInfo;
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

   void makeTuple(tuple *Tuple, uint16_t dest, uint16_t next_hop, uint16_t cost) {
      Tuple->dest = dest;
      Tuple->next_hop = next_hop;
      Tuple->cost = cost;
   }
}