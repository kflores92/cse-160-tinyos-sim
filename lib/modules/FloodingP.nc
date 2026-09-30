#include "../../includes/channels.h"
#include "../../includes/packet.h"

module FloodingP {
    provides interface Flooding;

    uses interface Random;
    uses interface SimpleSend as Sender;
    uses interface Receive;
    uses interface Hashmap<pack> as Cache;
}

implementation {

    void makePack(pack *Package, uint16_t origin, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    uint8_t mySeq = 0;

    command void Flooding.send(pack msg, uint16_t dest){
        pack cachePacket;
        pack storePacket;
        msg.seq = mySeq;
        mySeq++;

        if(call Cache.contains(msg.origin)){
            cachePacket = call Cache.get(msg.origin);
            if(cachePacket.seq < msg.seq){
                call Cache.remove(msg.origin);
                makePack(&storePacket, msg.origin, msg.src, msg.dest, msg.TTL, msg.protocol, msg.seq, msg.payload, PACKET_MAX_PAYLOAD_SIZE);
                call Cache.insert(msg.origin, storePacket);
            }
        }else{
            makePack(&storePacket, msg.origin, msg.src, msg.dest, msg.TTL, msg.protocol, msg.seq, msg.payload, PACKET_MAX_PAYLOAD_SIZE);
            call Cache.insert(msg.origin, storePacket);
        }

        call Sender.send(msg, AM_BROADCAST_ADDR);
        dbg(FLOODING_CHANNEL, "Flood Packet Sent. \n");
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){   

        dbg(FLOODING_CHANNEL, "Flood Recieve. \n");
        if(len==sizeof(pack)){
            pack* myMsg = (pack*) payload;
            pack cachePacket;
            pack storePacket;
            pack sendPacket;
            uint8_t* ptr_payload = myMsg->payload;

            makePack(&storePacket, myMsg->origin, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, ptr_payload, PACKET_MAX_PAYLOAD_SIZE);

            if(myMsg->dest == TOS_NODE_ID){
                if(call Cache.contains(myMsg->origin)){
                    cachePacket = call Cache.get(myMsg->origin);
                    if(cachePacket.seq < myMsg->seq){
                        call Cache.remove(myMsg->origin);
                        call Cache.insert(myMsg->origin, storePacket);
                    }
                }else {
                    call Cache.insert(myMsg->origin, storePacket);
                }

                dbg(FLOODING_CHANNEL, "Packet Reached Destination and Cached. \n");     
                return msg;
            }
            
            if(myMsg->TTL <= 0){
                dbg(FLOODING_CHANNEL, "Packet Expired. \n");
                return msg;
            }else{
                myMsg->TTL -= 1;
            }

            makePack(&sendPacket, myMsg->origin, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, ptr_payload, PACKET_MAX_PAYLOAD_SIZE);
            storePacket.TTL = myMsg->TTL;

            if(call Cache.contains(myMsg->origin)){
                cachePacket = call Cache.get(myMsg->origin);
            }else {
                call Cache.insert(myMsg->origin, storePacket);
                call Sender.send(sendPacket, AM_BROADCAST_ADDR);
                dbg(FLOODING_CHANNEL, "New Origin Cached and Packet Forwarded. \n");
                return msg;
            }

            if(cachePacket.seq < myMsg->seq){
                call Cache.remove(myMsg->origin);
                call Cache.insert(myMsg->origin, storePacket);
                call Sender.send(sendPacket, AM_BROADCAST_ADDR);
                dbg(FLOODING_CHANNEL, "Cache Updated and Packet Forwarded.\n");
                return msg;
            }else {
                dbg(FLOODING_CHANNEL, "Packet Dropped.\n");
                return msg;
            }
            
            dbg(FLOODING_CHANNEL, "Unknown Packet Type %d\n", len);
            return msg;
        }
        

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