#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/socket.h"

module TCPP {
    provides interface TCP;
}

implementation {

    void makeSegment(transport* Segment, uint8_t src_port, uint8_t dest_port, uint8_t seq, uint8_t ack, uint8_t flag, uint8_t* payload, uint8_t length);

    //helper function to find maximum number of packets that can be sent based on the advertised window and unacknowledged packets
    uint16_t min(uint16_t a, uint16_t b, uint16_t c) {
        uint16_t minVal = (a < b) ? a : b;
        return (minVal < c) ? minVal : c;
    }

    socket_store_t *conn;

    command void TCP.start(){

        uint16_t timeNow = call resend.getNow();

        //for each connection that a node has
            

            /*if(conn->state == ESTABLISHED && conn->txInProg == FALSE){
                call TCP.testSendData(conn);
            }*/

    }



    command void TCP.testSendData(socket_store_t *connection){

        
        //check if the connection is in ESTABLISHED state and if there is no transmission in progress
        if((connection->state != ESTABLISHED) || (connection->txInProg == TRUE)){
            return;
        }

        if (connection->nextSeqNum > connection ->oldestUnAckedSeqNum){
            // Handle the case where the next sequence number is greater than the oldest unacknowledged sequence number
            return;
        }

        //check how many unsent packets are in the send buffer
        uint16_t unAckedPackets = connection->nextSeqNum - connection->oldestUnAckedSeqNum;
        uint16_t unSentPackets = connection->bytesRcvd - connection->unAckedBytes;

        if(unSentPackets <= 0 || connection->advWindow <= 0){
            return;
        }

        uint16_t sendLength = min(unSentPackets, connection->advWindow, MAX_SEGMENT_SIZE);

        

        

        //define the payload
        //uint8_t payload = connection->sendBuffer + connection->unAckedBytes;
        //make Segment/Packet

        pack pkt = makeSegment(connection->src_port, connection->dest_port, connection->nextSeqNum, 0, 0, connection->sendBuffer, sendLength);



        if(call Tinynet.send(pkt, connection->dest) == SUCCESS){
            connection->txInProg = TRUE;
            connection->nextSeqNum = connection->oldestUnAckedSeqNum + sendLength;
            connection->lastHeard = call resend.getNow();
        }


        



    }

    event void TCP.TinynetDone(pack* msg, error_t result){
        //conn = findConnectionFromPacket(Packet);
        if(conn != NULL){
            conn->txInProg = FALSE;
        }
    }

    command void TCP.handleDataSegment(transport* seg, socket_store_t *connection){
        uint16_t freeSpace = 128 - connection->bytesRcvd;

        if(seg->seq == connection->nextSeqNumToRcv && seg->len <= freeSpace){
            //process the packet
            connection->nextSeqNumToRcv += seg->len;
            connection->bytesRcvd += seg->len;
        
        }
        else{
            //problem with the packet, do not advance nextSeqNumToRcv
            dbg(TRANSPORT_CHANNEL, "Problem detected, do not advance\n");
            return;
        }

        uint16_t updatedAdvWindow = 128 - connection->bytesRcvd;

        //send ACK with updated advertised window
        transport ackSeg;
        ackSeg.seq = connection->nextSeqNumToRcv;
        ackSeg.len = 0;
        ackSeg.advWindow = updatedAdvWindow;
        call Tinynet.send(ackSeg, connection->dest);



    }

    task void TCP.handleAckSegment(transport* seg, socket_store_t *connection){
        connection->advWindow = seg->advWindow;

        //ignore old/duplicate ACKs and ACKs beyond the next expected sequence number
        if(seg->ack > connection->oldestUnAckedSeqNum && seg->ack <= connection->nextSeqNum){
            nx_uint8_t newlyAcked = seg->ack - connection->oldestUnAckedSeqNum;
            //free retained bytes from send buffer, still need to implement
            connection->sendBuffer -= newlyAcked;
            connection->oldestUnAckedSeqNum = seg->ack;
            connection->BytesAcked += newlyAcked;
            conn->retxCount = 0; //reset retransmission count on successful ACK

            call TCP.testSendData(connection); //call testSendData to check if more data can be sent after receiving ACK

        }
        else{
            dbg(TRANSPORT_CHANNEL, "Ignoring old/duplicate ACK or ACK beyond next expected sequence number\n");
        }
    }


    event void onPeriodicTimer(){
        uint16_t timeNow = call resend.getNow();

        for(conn = connections; conn != NULL; conn = conn->next){
            if(conn->state == ESTABLISHED && conn->txInProg == FALSE){
                call TCP.testSendData(conn);
                return;
            }
        }


        //feeding test recieved bytes to the send buffer
        if(conn->state == ESTABLISHED && conn->bytesRcvd < conn->targetBytesRcvd){
            uint16_t currSpace = 128 - conn->bytesRcvd;
            uint16_t sendLength = min(currSpace, conn->targetBytesRcvd - conn->bytesRcvd, MAX_SEGMENT_SIZE);

            for (uint8_t i = 0; i < sendLength-1; i++){
                uint8_t byteVal = (uint8_t) (conn->bytesRcvd + i) % 256;
                //push byteVal into sendBuffer
                conn->sendBuffer[i] = byteVal;

            }

            connection->sendBuffer += sendLength;
            connection->bytesRcvd += sendLength;
            call TCP.testSendData(conn);

        }

        //read recieve buffer
        if((conn->bytesRcvd > 0) && conn->consumerStopped != TRUE;){
            uint8_t segChunk[]  = conn->rcvdBuff;
            //verify pattern, still need implementation
            conn->bytesRead += segChunk.length;
            conn->bytesRcvd = 0;
            //check current state and buffer count
        }

        //check for retransmission timeouts
        if(conn->nextSeqNum > conn-> oldestUnAckedSeqNum){
            bool hasUnAcked = TRUE;
        }

        //check if we're waiting
        if(hasUnAcked == TRUE) // || iswaiting == TRUE) && conn->txInProg != TRUE
        {
            if(timeNow - conn->lastHeard >= 2 * RTT){
                if(conn->numOfRetransmissions >= maxRetries){
                    //connection failed, force close state
                }
                else{
                    conn->numOfRetransmissions += 1
                    if(hasUnAcked == TRUE){
                        conn->nextSeqNum = conn->oldestUnAckedSeqNum;
                        call TCP.testSendData(conn)
                    }
                    else{
                        //resend control pkt
                    }
                }
            }
        }
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