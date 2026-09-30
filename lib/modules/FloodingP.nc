#include "../../includes/channels.h"
#include "../../includes/packet.h"

module FloodingP {
    provides interface Flooding;

    uses interface Random;
    uses interface SimpleSend as Sender;
    uses interface Receive;
    uses interface Hashmap<pack*> as Cache;
}

implementation {

    void makePack(pack *Package, uint16_t origin, uint8_t fseq, uint8_t fTTL, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    uint8_t mySeq = 0;

    command void Flooding.init(){

    }

    command void Flooding.send(pack msg, uint16_t dest){
        msg.fseq = mySeq;
        mySeq++;
        call Sender.send(msg, AM_BROADCAST_ADDR);
        dbg(FLOODING_CHANNEL, "Flood Packet Sent. \n");
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){   

        dbg(FLOODING_CHANNEL, "Flood Recieve. \n");
        if(len==sizeof(pack)){
            pack* myMsg = (pack*) payload;
            pack* cachePacket;
            pack sendPacket;
            uint8_t* ptr_payload = myMsg->payload;

            if(myMsg->dest == TOS_NODE_ID){
                if(call Cache.contains(myMsg->origin)){
                    cachePacket = call Cache.get(myMsg->origin);
                    if(cachePacket->fseq < myMsg->fseq){
                        call Cache.remove(myMsg->origin);
                        call Cache.insert(myMsg->origin, myMsg);
                    }
                }else {
                    call Cache.insert(myMsg->origin, myMsg);
                }

                dbg(FLOODING_CHANNEL, "Packet Reached Destination and Cached. \n");     
                return msg;
            }

            if(myMsg->fTTL <= 0){
                dbg(FLOODING_CHANNEL, "Packet Expired at %s. \n", TOS_NODE_ID);
                return msg;
            }else{
                myMsg->fTTL -= 1;
            }

            makePack(&sendPacket, myMsg->origin, myMsg->fseq, myMsg->fTTL, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, ptr_payload, PACKET_MAX_PAYLOAD_SIZE);

            if(call Cache.contains(myMsg->origin)){
                cachePacket = call Cache.get(myMsg->origin);
            }else {
                call Cache.insert(myMsg->origin, myMsg);
                call Sender.send(sendPacket, AM_BROADCAST_ADDR);
                dbg(FLOODING_CHANNEL, "New Origin Cached and Packet Forwarded. \n");
                return msg;
            }

            if(cachePacket->fseq < myMsg->fseq){
                call Cache.remove(myMsg->origin);
                call Cache.insert(myMsg->origin, myMsg);
                call Sender.send(sendPacket, AM_BROADCAST_ADDR);
                dbg(FLOODING_CHANNEL, "Packet Forwarded from %s.\n", TOS_NODE_ID);
            }else {
                dbg(FLOODING_CHANNEL, "Packet Dropped.\n");
                return msg;
            }
            
            dbg(FLOODING_CHANNEL, "Unknown Packet Type %d\n", len);
            return msg;
        }
        

        return msg;
    }

    void makePack(pack *Package, uint16_t origin, uint8_t fseq, uint8_t fTTL, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->origin = origin;
      Package->fseq = fseq;
      Package->fTTL = fTTL;
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}