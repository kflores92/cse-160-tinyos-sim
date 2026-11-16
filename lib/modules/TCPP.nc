#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/socket.h"

module TCPP {
    provides interface TCP;
}

implementation {

    socket_store_t *conn;

    command void TCP.start(){

        uint16_t timeNow = call resend.getNow();

        //for each connection that a node has
            

            /*if(conn->state == ESTABLISHED && conn->txInProg == FALSE){
                call TCP.testSendData(conn);
            }*/

    }



    command void TCP.testSendData(socket_store_t *connection){

        

        if((connection->state != ESTABLISHED) || (connection->txInProg == TRUE)){
            return;
        }

        if (connection->nextSeqNum > connection ->oldestUnAckedSeqNum){
            // Handle the case where the next sequence number is greater than the oldest unacknowledged sequence number
            return;
        }

        uint16_t unAckedPackets = connection->nextSeqNum - connection->oldestUnAckedSeqNum;
        uint16_t unSentPackets = connection->bytesRcvd - connection->unAckedBytes;

        if(unSentPackets <= 0 || connection->advWindow <= 0){
            return;
        }

        uint16_t sendLength = min(unSentPackets, connection->advWindow, MAX_SEGMENT_SIZE);

        

        //helper function to find maximum number of packets that can be sent based on the advertised window and unacknowledged packets
        uint16_t min(uint16_t a, uint16_t b, uint16_t c) {
            uint16_t minVal = (a < b) ? a : b;
            return (minVal < c) ? minVal : c;
        }

        //define the payload
        //make Segment/Packet

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
            dbg(TRANSPORT_CHANNEL, "Problem detected, packet dropped\n");
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

    

    



}