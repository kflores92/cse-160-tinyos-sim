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
}

implementation {

    task void postStateChange(uint8_t flag, uint8_t port);
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t origin, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void makeSegment(transport* Segment, uint8_t src_port, uint8_t dest_port, uint8_t seq, uint8_t ack, uint8_t flag, uint8_t* payload, uint8_t length);
    void makeConn(conn* Connection, uint8_t state, uint16_t dest_addr, uint8_t dest_port, uint8_t seq, uint8_t lastAck);
    uint8_t mySeq = 1;
    uint8_t avaliablePort = 1;

    bool activePort(uint8_t port){
        if(Ports.contains(port)){
            return TRUE;
        }else{
            return FALSE;
        }
    }

    command void startTCP(){
        post postStateChange(LISTEN, DEFAULT_LISTEN_PORT);
    }

    event void Tinynet.transportPacketRecieve(pack* myMsg, uint16_t src){
        transport* mySeg = (transport*) myMsg->payload;
        dbg(TRANSPORT_CHANNEL, "TCP Packet Arrived\n");
        
        switch(mySeg->flag){
            case SEND:
                //processData
                break;

            case CONNECT:
                post postStateChange(CONNECT, mySeg->dest_port);
                break;

            case LISTEN:
                post postStateChange(LISTEN, mySeg->dest_port);
                break;

            case SYN:
                post postStateChange(SYN, mySeg->dest_port);
                break;

            case SYNACK:
                post postStateChange(SYNACK, mySeg->dest_port);
                break;

            case CLOSE:
                post postStateChange(CLOSE, mySeg->dest_port);
                break;

            case ACK:
                post postStateChange(ACK, mySeg->dest_port);
                break;

            case FIN:
                post postStateChange(FIN, mySeg->dest_port);
            
            case FINACK:
                post postStateChange(FINACK, mySeg->dest_port);

            default:
                dbg(TRANSPORT_CHANNEL, "Couldn't Identify TCP Action");
                break;
        }
    }

    command error_t TCP.stateChange(uint8_t flag, uint8_t port, uint16_t dest_addr){
        post postStateChange(flag, port, dest_addr);
        return SUCCESS;
    }

    task void postStateChange(uint8_t flag, uint8_t port, uint16_t dest_addr){
        uint8_t = portTimeout;
        conn_store storedConn;

        switch(mySeg->flag){
            case SEND:
                //processData
                break;

            case CONNECT:
                if(!Ports.contains(port)) {
                    makeConn(&storedConn, SYN_SENT, dest_addr, DEFAULT_LISTEN_PORT, mySeq, 0);
                    Ports.insert(port, storedConn);
                    call sendSetup(SYN, dest_addr, port, DEFAULT_LISTEN_PORT, "");
                }

                break;

            case LISTEN:
                if(!Ports.contains(port)){
                    makeConn(&storedConn, LISTENING, NO_ADDRESS, NO_PORT, 0, 0);
                    Ports.insert(port, storedConn);
                }

                break;

            case SYN:
                if(Port.contains(port)){
                    storedConn = Ports.get(port);
                    if(storedConn->state == LISTENING){

                        portTimeout = 200;
                        while(activePort(avaliablePort) == TRUE && portTimeout > 0){
                            avaliablePort += 1;
                            portTimeout -= 1;
                        }
                    }
                }

                break;

            case SYNACK:
                
                break;

            case CLOSE:
                
                break;

            case ACK:
                
                break;

            case FIN:

                break;    
            
            case FINACK:

                break;

            default:
                dbg(TRANSPORT_CHANNEL, "Couldn't Identify TCP Action");
                break;
    }

    command error_t TCP.sendSetup(uint8_t flag, uint8_t dest, uint8_t src_port, uint8_t dest_port, uint8_t* payload){
        pack sendPack;
        transport sendSegment;
        uint8_t* ptr_payload;
        
        makeSegment(&sendSegment, src_port, dest_port, mySeq, 0, SYN, payload, SEGMENT_MAX_PAYLOAD_SIZE);
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