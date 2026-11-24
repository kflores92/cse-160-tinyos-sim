#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/socket.h"
#include "../../includes/connection.h"

module TCPP {
    provides interface TCP;

    uses interface Hashmap<conn_store> as Ports;
    uses interface Tinynet;
    uses interface Timer<TMilli> as Timeout;
    uses interface List<uint8_t> as avaliablePorts;
    uses interface Timer<TMilli> as portRelease;
    uses interface List<uint8_t> as closingPorts;
}

implementation {

    task void postStateChange(uint8_t flag, uint8_t port);
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t origin, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void makeSegment(transport* Segment, uint8_t src_port, uint8_t dest_port, uint8_t seq, uint8_t ack, uint8_t flag, uint8_t* payload, uint8_t length);
    void makeConn(conn* Connection, uint8_t state, uint16_t dest_addr, uint8_t dest_port, uint8_t seq, uint8_t lastAck);
    uint8_t mySeq = 1;

    bool activePort(uint8_t port){
        if(Ports.contains(port)){
            return TRUE;
        }else{
            return FALSE;
        }
    }

    command void startTCP(){
        uint8_t i;

        for(i = 1; i < 255; i++){
            avaliablePorts.pushback(i);
        }

        post postStateChange(LISTEN, DEFAULT_LISTEN_PORT);
    }

    event void Tinynet.transportPacketRecieve(pack* myMsg, uint16_t src){
        transport* mySeg = (transport*) myMsg->payload;
        dbg(TRANSPORT_CHANNEL, "TCP Packet Arrived\n");
        post postStateChange(mySeg->flag, myMsg);
    }

    command error_t TCP.stateChange(uint8_t flag, pack* myMsg){
        post postStateChange(flag, myMsg);
        return SUCCESS;
    }

    command error_t TCP.sendSetup(uint8_t flag, uint8_t dest, uint8_t src_port, uint8_t dest_port, uint8_t ack, uint8_t* payload){
        pack sendPack;
        transport sendSegment;
        uint8_t* ptr_payload;
        
        makeSegment(&sendSegment, src_port, dest_port, mySeq, ack, flag, payload, SEGMENT_MAX_PAYLOAD_SIZE);
        ptr_payload = (uint8_t*) &sendSegment;

        makePack(&sendPack, TOS_NODE_ID, dest, MAX_TTL, PROTOCOL_TCP, PROTOCOL_IP, 0, ptr_payload, PACKET_MAX_PAYLOAD_SIZE);
        return call Tinynet.send(&sendPack, dest);
    }

    command error_t TCP.sendData(uint8_t* payload, uint8_t len, uint8_t dest, uint8_t port){
        return FAIL;
    }

    command error_t TCP.processData(uint8_t* payload, uint8_t port){
        return FAIL;
    }

    event void Timeout.fired(){

    }

     task void postStateChange(uint8_t flag, pack* myMsg){
        transport* mySeg = (transport*) myMsg->payload;
        conn_store storedConn;
        uint8_t src_port;

        switch(mySeg->flag){
            case SEND:

                break;

            case CONNECT:
                if(!Ports.contains(mySeg->dest_port)) {
                    makeConn(&storedConn, SYN_SENT, dest_addr, DEFAULT_LISTEN_PORT, mySeq, 0);
                    Ports.insert(port, storedConn);
                    call sendSetup(SYN, dest_addr, port, DEFAULT_LISTEN_PORT, 0 "");
                }
                break;

            case LISTEN:
                if(!Ports.contains(mySeg->dest_port)){
                    makeConn(&storedConn, LISTENING, NO_ADDRESS, NO_PORT, 0, 0);
                    Ports.insert(port, storedConn);
                }

                break;

            case SYN:
                if(Port.contains(mySeg->dest_port)){
                    storedConn = Ports.get(mySeg->dest_port);
                    if(storedConn->state == LISTENING){
                        src_port = avaliablePorts.popfront();
                        makeConn(&storedConn, SYN_RCVD, myMsg->src, mySeg->src_port, mySeg->seq, mySeg->ack);
                        Ports.insert(src_port, storedConn);
                        call sendSetup(SYNACK, dest_addr, port, DEFAULT_LISTEN_PORT, 0, "");
                    }
                }

                break;

            case SYNACK:
                if(Port.contains(mySeg->dest_port)){
                    storedConn = Ports.get(mySeg->dest_port);
                    if(storedConn->state == SYN_SENT){
                        makeConn(&storedConn, ESTABLISHED, myMsg->src, mySeg->src_port, mySeg->seq, mySeg->ack);
                        Ports.insert(mySeg->dest_port, storedConn);
                        call sendSetup(ACK, myMsg->src, mySeg->dest_port, mySeg->src_port, 0, "");
                    }
                }

                break;

            case CLOSE:
                if(Port.contains(mySeg->src_port)){
                    storedConn = Ports.get(mySeg->src_port);
                    
                    if(storedConn->state == ESTABLISHED){
                        makeConn(&storedConn, FIN_WAIT_A, storedConn->dest_addr, storedConn->dest_port, storedConn->seq, storedConn->ack);
                        Ports.insert(mySeg->src_port, storedConn);
                        call sendSetup(FIN, storedConn->dest_addr, storedConn->dest_port, mySeg->src_port, 0, "");
                    }

                    if(storedConn->state == CLOSE_WAIT){
                        makeConn(&storedConn, FIN_WAIT_A, storedConn->dest_addr, storedConn->dest_port, storedConn->seq, storedConn->ack);
                        Ports.insert(mySeg->src_port, storedConn);
                        call sendSetup(FIN, storedConn->dest_addr, storedConn->dest_port, mySeg->src_port, 0, "");
                    }
                }

                break;

            case ACK:
                if(Port.contains(mySeg->dest_port)){
                    storedConn = Ports.get(mySeg->dest_port);
                    if(storedConn->state == SYN_RCVD){
                        makeConn(&storedConn, ESTABLISHED, myMsg->src, mySeg->src_port, mySeg->seq, mySeg->ack);
                        Ports.insert(mySeg->dest_port, storedConn);
                    }

                    if(storedConn->state == FIN_WAIT_A){
                        makeConn(&storedConn, FIN_WAIT_B, storedConn->dest_addr, storedConn->dest_port, storedConn->seq, storedConn->ack);
                        Ports.insert(mySeg->dest_port, storedConn);
                    }
                    
                    if(storedConn->state == CLOSING){
                        makeConn(&storedConn, TIME_WAIT, storedConn->dest_addr, storedConn->dest_port, storedConn->seq, storedConn->ack);
                        Ports.insert(mySeg->dest_port, storedConn);
                        portRelease.startOneShot(10000);
                        closingPorts.pushback(mySeg->dest_port);
                    }

                    if(storedConn->state == LAST_ACK){
                        avaliablePorts.pushback(mySeg->dest_port);
                        Ports.remove(mySeg->dest_port);
                    }
                }
                break;

            case FIN:
                if(Port.contains(mySeg->dest_port)){
                    storedConn = Ports.get(mySeg->dest_port);
                    if(storedConn->state == ESTABLISHED){
                        makeConn(&storedConn, CLOSE_WAIT, storedConn->dest_addr, storedConn->dest_port, storedConn->seq, storedConn->ack);
                        Ports.insert(mySeg->src_port, storedConn);
                        call sendSetup(ACK, storedConn->dest_addr, storedConn->dest_port, mySeg->src_port, 0, "");
                    }

                    if(storedConn->state == FIN_WAIT_A){
                        makeConn(&storedConn, CLOSING, storedConn->dest_addr, storedConn->dest_port, storedConn->seq, storedConn->ack);
                        Ports.insert(mySeg->src_port, storedConn);
                        call sendSetup(ACK, storedConn->dest_addr, storedConn->dest_port, mySeg->src_port, 0, "");
                    }

                    if(storedConn->state == FIN_WAIT_B){
                        makeConn(&storedConn, TIME_WAIT, storedConn->dest_addr, storedConn->dest_port, storedConn->seq, storedConn->ack);
                        Ports.insert(mySeg->src_port, storedConn);
                        call sendSetup(ACK, storedConn->dest_addr, storedConn->dest_port, mySeg->src_port, 0, "");
                        portRelease.startOneShot(10000);
                        closingPorts.pushback(mySeg->dest_port);
                    }
                }
                break;    
            
            case FINACK:
                if(Port.contains(mySeg->dest_port)){
                    storedConn = Ports.get(mySeg->dest_port);
                    if(storedConn->state == FIN_WAIT_A){
                        makeConn(&storedConn, TIME_WAIT, storedConn->dest_addr, storedConn->dest_port, storedConn->seq, storedConn->ack);
                        Ports.insert(mySeg->src_port, storedConn);
                        call sendSetup(ACK, storedConn->dest_addr, storedConn->dest_port, mySeg->src_port, 0, "");
                        portRelease.startOneShot(10000);
                        closingPorts.pushback(mySeg->dest_port);
                    }
                }
                break;

            default:
                dbg(TRANSPORT_CHANNEL, "Couldn't Identify TCP Action");
                break;
    }

    event void portRelease.fired(){
        release_port = closingPorts.popfront();

        avaliablePorts.pushback(release_port);
        Ports.remove(release_port);
    }

    void makeConn(conn* Connection, uint8_t state, uint16_t dest_addr, uint8_t dest_port, uint8_t seq, uint8_t lastAck){
        Connection->state = state;
        Connection->dest_addr = dest_addr;
        Connection->dest_port = dest_port;
        Connection->seq = seq;
        Connection->lastAck = lastAck;
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