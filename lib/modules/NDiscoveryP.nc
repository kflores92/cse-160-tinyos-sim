#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/neighbor.h"

module NDiscoveryP {
    provides interface NDiscovery;

    uses interface Timer<TMilli> as neighborTimer;
    uses interface Random;
    uses interface SimpleSend as Sender;
    uses interface Receive;
    uses interface Hashmap<stats> as Cache;
}

implementation {

    void makePack(pack *Package, uint16_t origin, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    uint16_t mySeq;
    uint32_t* table;
    uint8_t i;
    uint16_t neighbor;
    

    command void NDiscovery.start() {   
        call neighborTimer.startPeriodic(1500 + (uint16_t) (call Random.rand16()%500));
    }

    event void neighborTimer.fired() {
        pack neighborPack;
        stats neighborInfo;
        uint8_t payload[] = "";

        //dbg(NEIGHBOR_CHANNEL, "Neighbor timer is fired: searching for neighbors! \n");

        makePack(&neighborPack, TOS_NODE_ID, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, PROTOCOL_NPKT, mySeq, payload, PACKET_MAX_PAYLOAD_SIZE);
        mySeq++;
        call Sender.send(neighborPack, AM_BROADCAST_ADDR);

        table = call Cache.getKeys();
        
        for(i = 0; i < call Cache.size(); i++){
            neighborInfo = call Cache.get(table[i]);
            neighborInfo.age -= 1;

            if(neighborInfo.age >= 0){
                call Cache.insert(table[i], neighborInfo);
            }else{
                call Cache.remove(table[i]);
                dbg(NEIGHBOR_CHANNEL, "Neighbor Deleted. \n");
            }
        }
    }

    command void NDiscovery.printNeighbors() {
        table = call Cache.getKeys();
        dbg(NEIGHBOR_CHANNEL, "\n\n\n\n");
        dbg(NEIGHBOR_CHANNEL, "---------------------\n");
        
        dbg(NEIGHBOR_CHANNEL, "Cache Size: %d. \n", call Cache.size());
        for(i = 0; i < call Cache.size(); i++){
            neighbor = table[i];
            dbg(NEIGHBOR_CHANNEL, "Neighbor %d. \n", neighbor);
        }
        dbg(NEIGHBOR_CHANNEL, "---------------------\n");
        dbg(NEIGHBOR_CHANNEL, "\n\n\n\n");
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
        if(len == sizeof(pack)){
            pack* myMsg = (pack*) payload;
            pack replyPack;

            if(myMsg->protocol == PROTOCOL_NPKT){
                makePack(&replyPack, TOS_NODE_ID, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, PROTOCOL_NPKT_R, mySeq, payload, PACKET_MAX_PAYLOAD_SIZE);   
                call Sender.send(replyPack, myMsg->origin);
                //dbg(NEIGHBOR_CHANNEL, "Request PKT Recieved, Reply Sent. \n");
                return msg;
            }

            if(myMsg->protocol == PROTOCOL_NPKT_R){
                stats neighborInfo;
                neighborInfo.cost = 1;
                neighborInfo.age = 5;

                if(!(call Cache.contains(myMsg->origin))){
                    call Cache.insert(myMsg->origin, neighborInfo);
                    //Neighbor Dicovery Table needs to implement cost function
                    //for now hop of 1.
                }else {
                    call Cache.insert(myMsg->origin, neighborInfo);
                }

                //dbg(NEIGHBOR_CHANNEL, "NPKT Reply Recieved, Cache Updated. \n");
                return msg;
            }
        }

        dbg(NEIGHBOR_CHANNEL, "Packed Ignored by Neighbor Discovery. \n");
        return msg;
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
}