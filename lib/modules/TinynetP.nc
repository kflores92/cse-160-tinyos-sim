#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module TinynetP {
    provides interface Tinynet;

    uses interface SimpleSend as Sender;
    uses interface Packet;
    uses interface DVRouting;
}

implementation {

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

    uint16_t mySeq;
    uint8_t nextHop;

    
        pack* outgoingPack;

    command error_t Tinynet.send(pack* msg, uint16_t dest){
        dbg(ROUTING_CHANNEL, "FORWARD_IP STARTED on node %d\n", TOS_NODE_ID);

        nextHop = call DVRouting.getRouting(dest);

        if(nextHop != INF){
            message_t localOutgoingMsg;
            outgoingPack = (pack*) call Packet.getPayload(&localOutgoingMsg, sizeof(pack));

            if(outgoingPack != NULL){

                makePack(
                    outgoingPack,
                    msg->src,
                    msg->dest,
                    msg->TTL,
                    msg->protocol,
                    msg->seq,
                    msg->payload,
                    PACKET_MAX_PAYLOAD_SIZE
                );
                

                if (call Sender.send(*outgoingPack, nextHop) == SUCCESS){
                    dbg(ROUTING_CHANNEL, "Sending to next hop!%d\n", TOS_NODE_ID);
                    return SUCCESS;
                }
                else{
                    dbg(ROUTING_CHANNEL, "Failed to send packet to next hop!\n");
                    return FAIL;
                }

            }

        }

    }

    

    command message_t* Tinynet.forwardIP(message_t* msg, void* payload, uint8_t len){
        uint8_t* ptr_payload;
        const char* ack = "ACK";
        dbg(ROUTING_CHANNEL, "FORWARD_IP CALLED on node %d\n", TOS_NODE_ID);

        if(len==sizeof(pack)){
            pack* myMsg = (pack*) payload;
            pack sendPack;

            if(myMsg->dest == TOS_NODE_ID && myMsg->protocol == PROTOCOL_IP) {
                //if dest ping
                dbg(ROUTING_CHANNEL, "Packet has reached destination! \n");
                dbg(ROUTING_CHANNEL, "%s\n", myMsg->payload);
                ptr_payload = ack;
                makePack(&sendPack, TOS_NODE_ID, myMsg->src, MAX_TTL, PROTOCOL_IPR, myMsg->seq, ptr_payload, PACKET_MAX_PAYLOAD_SIZE);
                call Tinynet.send(&sendPack, myMsg->src);
                return msg;

            }else if(myMsg->dest == TOS_NODE_ID && myMsg->protocol == PROTOCOL_IPR){
                //if dest ping reply
                dbg(ROUTING_CHANNEL, "Reply has reached destination! \n");
                dbg(ROUTING_CHANNEL, "%s\n", myMsg->payload);
                return msg;

            }else{
                if(myMsg->TTL <= 1){
                    dbg(ROUTING_CHANNEL, "Packet has expired or been dropped. \n");
                    return msg;
                }
                
                

                nextHop = call DVRouting.getRouting(myMsg->dest);

                    if (nextHop != INF) {
                        message_t localOutgoingMsg;
                        myMsg->TTL = myMsg->TTL - 1;
                        
                        outgoingPack = (pack*) call Packet.getPayload(&localOutgoingMsg, sizeof(pack));
                        makePack(
                            outgoingPack,
                            myMsg->src,
                            myMsg->dest,
                            myMsg->TTL,
                            myMsg->protocol,
                            myMsg->seq,
                            (uint8_t*)myMsg->payload,
                            PACKET_MAX_PAYLOAD_SIZE
                        );
                        

                        if(call Sender.send(*outgoingPack, nextHop) == SUCCESS){
                            dbg(ROUTING_CHANNEL, "Forwarding to next hop!\n");

                        }
                        else{
                            dbg(ROUTING_CHANNEL, "Failed to forward packet to next hop!\n");
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