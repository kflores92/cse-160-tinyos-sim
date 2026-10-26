#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module NetworkP {
    provides interface Network;

    uses interface Sender;
    uses interface Packet;
    uses interface DVRouting;
}

implementation {

    uint16_t mySeq;
    uint16_t nextHop;

    command error_t Network.send(pack* msg, uint16_t dest){

    }

    command message_t* Network.forwardIP(message_t* msg, void* payload, uint8_t len){
        if(len==sizeof(pack)){
            pack* myMsg = (pack*) payload;

            if(myMsg->dest == TOS_NODE_ID) {
                //if dest ping
               signal Network.ping(myMsg->src, myMsg->payload);
               return msg;
            }

            else{
                if(myMsg->TTL <= 1){
                    dbg(ROUTING_CHANNEL, "Packet has expired or been dropped. \n");
                    return msg;
                }
                
                

                nextHop = call DVRouting.getRouting(myMsg->dest);

                    if (nextHop != NULL){
                        myMsg->TTL = myMsg->TTL - 1;
                        pack* outgoingPack = (pack*) call Packet.getPayload(&outgoingPacketBuf, sizeof(pack));
                        makePack(
                            outgoingPack,
                            myMsg->src,
                            myMsg->dest,
                            myMsg->TTL,
                            myMsg->protocol,
                            myMsg->seq,
                            myMsg->payload,
                            PACKET_MAX_PAYLOAD_SIZE
                        );
                        

                        if(call Sender.send(&outgoingPacketBuf, nextHop) == SUCCESS){
                            dbg(ROUTING_CHANNEL, "Forwarding to next hop!\n");

                        }
                        

                    }
                    else{
                        dbg(ROUTING_CHANNEL, "Packet has been dropped. No route to dest \n");
                        
                    }
                
            }

            return msg;
         }
         
      return msg;
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }

}