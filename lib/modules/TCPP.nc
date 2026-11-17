#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/socket.h"
#include "../../includes/port.h"

module TCPP {
    provides interface TCP;

    uses interface Hashmap<conn_store> as Ports;
    uses interface Tinynet;
    uses interface Timer<TMilli> as Timeout;
}

implementation {

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t origin, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    mySeq = 0;

    bool activePort(uint8_t port){
        
    }

    event void Tinynet.transportPacketRecieve(transport* myMsg, uint16_t src){
        dbg(TRANSPORT_CHANNEL, "Transport Packet Arrived");
    }

    command error_t TCP.stateChange(uint8_t flag, uint8_t port){

    }

    command error_t TCP.sendSetup(uint8_t* payload, uint8_t dest, uint8_t src_port, uint8_t dest_port){
        pack* sendPack;
        transport* sendSegment;
        uint8_t* ptr_payload;
        
        makeSegment(&sendSegment, src_port, dest_port, mySeq, 0, SYN, payload, SEGMENT_MAX_PAYLOAD_SIZE);
        ptr_payload = (uint8_t*)sendSegment;

        makePack(&sendPack, TOS_NODE_ID, dest, MAX_TTL, PROTOCOL_TCP, PROTOCOL_IP, 0, ptr_payload, PACKET_MAX_PAYLOAD_SIZE);

        call Tinynet.send(sendPack, dest);
    }

    command error_t TCP.sendData(uint8_t* payload, uint8_t len, uint8_t dest, uint8_t port){

    }

    command error_t TCP.processData(uint8_t* payload, uint8_t port){

    }

    void makeSegment(transport* Segment, uint8_t src_port, uint8_t dest_port, uint8_t seq, uint8_t ack, uint8_t flag, uint8_t* payload, uint8_t length){
        Segment->src_port = src_port;
        Segment->dest_port = dest_port;
        Segment->seq = seq;
        Segment->ack = ack;
        Segment->flag = flag;
        memcpy(Segment->payload, payload, length);
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t origin, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->origin = origin;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
   }

}