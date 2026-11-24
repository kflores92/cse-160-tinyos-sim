#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/socket.h"
#include "../../includes/connection.h"

module TCPP {
    provides interface TCP;
    uses interface Tinynet;
    uses interface Timer<TMilli> as resend;
}

implementation {

    conn_store connections[MAX_CONNECTIONS];
    uint16_t TinynetPacketSeq = 0;

    //BUFFER HELPERS
    void copyFromBuffer(uint8_t* buff, uint8_t startIndx, uint8_t* out, uint8_t length) {
        uint8_t i;
        for (i = 0; i < length; i++) {
            out[i] = buff[(startIndx + i) % SOCKET_BUFFER_SIZE];
        }
    }

    void writeToBuffer(uint8_t* buff, uint8_t startIndx, uint8_t* in, uint8_t length) {
        uint8_t i;
        for (i = 0; i < length; i++) {
            buff[(startIndx + i) % SOCKET_BUFFER_SIZE] = in[i];
        }
    }

    uint16_t min3(uint16_t a, uint16_t b, uint16_t c) {
        uint16_t minVal = (a < b) ? a : b;
        return (minVal < c) ? minVal : c;
    }

    //CONNECTION TABLE HELPERS
    conn_store* findConnection(uint8_t localPort, uint16_t remoteAddr, uint8_t remotePort) {
        uint8_t i;
        for (i = 0; i < MAX_CONNECTIONS; i++) {
            if (connections[i].isActive &&
                connections[i].state != LISTEN &&
                connections[i].src_port == localPort &&
                connections[i].dest_addr == remoteAddr &&
                connections[i].dest_port == remotePort) {
                return &connections[i];
            }
        }
        return NULL;
    }

    conn_store* findListener(uint8_t localPort) {
        uint8_t i;
        for (i = 0; i < MAX_CONNECTIONS; i++) {
            if (connections[i].isActive &&
                connections[i].state == LISTEN &&
                connections[i].src_port == localPort) {
                return &connections[i];
            }
        }
        return NULL;
    }

    conn_store* allocateConnection() {
        uint8_t i;
        for (i = 0; i < MAX_CONNECTIONS; i++) {
            if (!connections[i].isActive) {
                memset(&connections[i], 0, sizeof(conn_store));
                connections[i].isActive = TRUE;
                connections[i].senderWindowLim = DEFAULT_SENDER_WND;
                connections[i].advWindowLim = SOCKET_BUFFER_SIZE;
                return &connections[i];
            }
        }
        return NULL;
    }

    //WRAP TCP HEADER AND PAYLOAD IN TINYNET PACK
    error_t sendTransportPacket(conn_store* connection, uint8_t flags, uint16_t seq,
                                uint16_t ack, uint8_t window, uint8_t* data, uint8_t dataLength) {
        pack ipPkt;
        uint8_t rawBuf[PACKET_MAX_PAYLOAD_SIZE];
        tcp_hdr* hdr = (tcp_hdr*) rawBuf;

        hdr->srcPort = connection->src_port;
        hdr->destPort = connection->dest_port;
        hdr->flags = flags;
        hdr->seqNum = seq;
        hdr->AckSeqNum = ack;
        hdr->advertisedWindow = window;
        hdr->length = dataLength;

        if (dataLength > 0 && data != NULL) {
            memcpy(rawBuf + sizeof(tcp_hdr), data, dataLength);
        }

        ipPkt.src = TOS_NODE_ID;
        ipPkt.dest = connection->dest_addr;
        ipPkt.TTL = MAX_TTL;
        ipPkt.protocol = PROTOCOL_TCP;
        ipPkt.seq = ++TinynetPacketSeq;
        memcpy(ipPkt.payload, rawBuf, sizeof(tcp_hdr) + dataLength);

        return call Tinynet.send(&ipPkt, connection->dest_addr);
    }

    //SLIDING WINDOW SENDER
    void testSendData(conn_store* connection) {
        uint16_t inFlightBytes;
        uint16_t effectiveWindow;
        uint16_t usableWindow;
        uint16_t unSentBytes;
        uint8_t maxData;
        uint8_t sendLength;
        uint8_t startIndx;
        uint8_t currentWindow;
        uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];

        if (connection->connInProg || connection->state != ESTABLISHED) {
            return;
        }

        inFlightBytes = connection->nxtUnSentByte - connection->oldestUnAckedByte;
        effectiveWindow = min3(connection->senderWindowLim, connection->advWindowLim, SOCKET_BUFFER_SIZE);
        maxData = PACKET_MAX_PAYLOAD_SIZE - sizeof(tcp_hdr);

        if (inFlightBytes >= effectiveWindow) {
            return;
        }

        usableWindow = effectiveWindow - inFlightBytes;
        unSentBytes = connection->queuedAppBytes - inFlightBytes;

        if (unSentBytes == 0) {
            return;
        }

        sendLength = (uint8_t) min3(maxData, usableWindow, unSentBytes);
        startIndx = (connection->lastAck + inFlightBytes) % SOCKET_BUFFER_SIZE;
        copyFromBuffer(connection->sendBuff, startIndx, payload, sendLength);
        currentWindow = SOCKET_BUFFER_SIZE - connection->unreadBytes;

        if (sendTransportPacket(connection, DATA_FLAG, connection->nxtUnSentByte,
                                connection->nxtExpectedByte, currentWindow, payload, sendLength) == SUCCESS) {
            if (inFlightBytes == 0) {
                connection->lastConnectionTime = call resend.getNow();
            }
            connection->nxtUnSentByte += sendLength;
            connection->retUnAckedBytes += sendLength;
        }
    }

    task void serviceConnectionsTask() {
        uint8_t i;
        for (i = 0; i < MAX_CONNECTIONS; i++) {
            if (connections[i].isActive && connections[i].state == ESTABLISHED) {
                testSendData(&connections[i]);
            }
        }
    }

    //ACK AND DATA HANDLERS
    void handleAckSegment(tcp_hdr* seg, conn_store* connection, uint8_t peerAdvertisedWindow) {
        uint16_t newlyAcked;

        connection->advWindowLim = peerAdvertisedWindow;
        if (seg->AckSeqNum > connection->oldestUnAckedByte && seg->AckSeqNum <= connection->nxtUnSentByte) {
            newlyAcked = seg->AckSeqNum - connection->oldestUnAckedByte;

            connection->lastAck = (connection->lastAck + newlyAcked) % SOCKET_BUFFER_SIZE;
            connection->queuedAppBytes -= newlyAcked;
            connection->retUnAckedBytes -= newlyAcked;
            connection->oldestUnAckedByte = seg->AckSeqNum;
            connection->bytesAcked += newlyAcked;
            connection->retransmitCount = 0;

            if (connection->oldestUnAckedByte < connection->nxtUnSentByte) {
                connection->lastConnectionTime = call resend.getNow();
            }
        }
        post serviceConnectionsTask();
    }

    void handleData(conn_store* connection, uint16_t seqNum, uint8_t* data, uint8_t length) {
        uint8_t freeSpace = SOCKET_BUFFER_SIZE - connection->unreadBytes;
        uint8_t currentWindow;

        if (seqNum == connection->nxtExpectedByte && length <= freeSpace) {
            writeToBuffer(connection->rcvdBuff, connection->lastRcvdByte, data, length);
            connection->lastRcvdByte = (connection->lastRcvdByte + length) % SOCKET_BUFFER_SIZE;
            connection->unreadBytes += length;
            connection->nxtExpectedByte += length;
        } else {
            dbg(TRANSPORT_CHANNEL, "Discarding packet due to OOR, duplicate or buffer full\n");
        }

        currentWindow = SOCKET_BUFFER_SIZE - connection->unreadBytes;
        sendTransportPacket(connection, ACK_FLAG, connection->nxtUnSentByte,
                            connection->nxtExpectedByte, currentWindow, NULL, 0);
    }

    //INCOMING PACKET DISPATCHER
    event void Tinynet.receiveTCP(pack* ipMsg) {
        tcp_hdr* seg = (tcp_hdr*) ipMsg->payload;
        uint8_t* data = ((uint8_t*) ipMsg->payload) + sizeof(tcp_hdr);
        conn_store* conn = findConnection(seg->destPort, ipMsg->src, seg->srcPort);

        if (conn == NULL && seg->flags == SYN_FLAG) {
            if (findListener(seg->destPort) != NULL) {
                conn = allocateConnection();
                if (conn != NULL) {
                    conn->src_port = seg->destPort;
                    conn->dest_addr = ipMsg->src;
                    conn->dest_port = seg->srcPort;
                    conn->state = SYN_RCVD;
                    conn->oldestUnAckedByte = 1;
                    conn->nxtUnSentByte = 2;
                    conn->nxtExpectedByte = seg->seqNum + 1;
                    conn->advWindowLim = seg->advertisedWindow;
                    conn->lastConnectionTime = call resend.getNow();
                    sendTransportPacket(conn, SYN_FLAG | ACK_FLAG, 1, conn->nxtExpectedByte, SOCKET_BUFFER_SIZE, NULL, 0);
                }
            }
            return;
        }
        if (conn == NULL) return;

        switch (conn->state) {
            case SYN_SENT:
                if (seg->flags == (SYN_FLAG | ACK_FLAG) && seg->AckSeqNum == conn->nxtUnSentByte) {
                    conn->oldestUnAckedByte = seg->AckSeqNum;
                    conn->nxtExpectedByte = seg->seqNum + 1;
                    conn->advWindowLim = seg->advertisedWindow;
                    conn->state = ESTABLISHED;
                    conn->retransmitCount = 0;
                    sendTransportPacket(conn, ACK_FLAG, conn->nxtUnSentByte, conn->nxtExpectedByte, SOCKET_BUFFER_SIZE, NULL, 0);
                    post serviceConnectionsTask();
                }
                break;

            case SYN_RCVD:
                if (seg->flags == ACK_FLAG && seg->AckSeqNum == conn->nxtUnSentByte) {
                    conn->oldestUnAckedByte = seg->AckSeqNum;
                    conn->state = ESTABLISHED;
                    conn->retransmitCount = 0;
                }
                break;

            case ESTABLISHED:
                if (seg->flags == DATA_FLAG) {
                    handleData(conn, seg->seqNum, data, seg->length);
                } else if (seg->flags == ACK_FLAG) {
                    handleAckSegment(seg, conn, seg->advertisedWindow);
                }
                break;
        }
    }

    //TCP INTERFACE COMMANDS
    command void TCP.start() {
        call resend.startPeriodic(200);
    }

    command error_t TCP.startServer(uint8_t listenPort) {
        conn_store* conn = allocateConnection();
        if (conn == NULL) return FAIL;
        conn->src_port = listenPort;
        conn->state = LISTEN;
        return SUCCESS;
    }

    command error_t TCP.startClient(uint16_t destAddr, uint8_t srcPort, uint8_t destPort, uint16_t transferBytes) {
        conn_store* conn = allocateConnection();
        if (conn == NULL) return FAIL;
        conn->src_port = srcPort;
        conn->dest_addr = destAddr;
        conn->dest_port = destPort;
        conn->state = SYN_SENT;
        conn->oldestUnAckedByte = 1;
        conn->nxtUnSentByte = 2;
        conn->targetBytes = transferBytes;
        conn->lastConnectionTime = call resend.getNow();
        sendTransportPacket(conn, SYN_FLAG, 1, 0, SOCKET_BUFFER_SIZE, NULL, 0);
        return SUCCESS;
    }

    //PERIODIC TIMER
    event void resend.fired() {
        uint32_t timeNow = call resend.getNow();
        uint8_t i;

        for (i = 0; i < MAX_CONNECTIONS; i++) {
            conn_store* connection = &connections[i];
            if (!connection->isActive || connection->state == CLOSED || connection->state == LISTEN) {
                continue;
            }

            //Feed test bytes into sendBuff
            if (connection->state == ESTABLISHED && connection->bytesAccepted < connection->targetBytes) {
                uint16_t space = SOCKET_BUFFER_SIZE - connection->queuedAppBytes;
                uint16_t rem = connection->targetBytes - connection->bytesAccepted;
                uint16_t toAdd = min3(space, rem, SOCKET_BUFFER_SIZE);
                uint8_t j;

                for (j = 0; j < toAdd; j++) {
                    connection->sendBuff[connection->lastWritten] = (uint8_t)((connection->bytesAccepted + j) % 256);
                    connection->lastWritten = (connection->lastWritten + 1) % SOCKET_BUFFER_SIZE;
                }
                connection->queuedAppBytes += toAdd;
                connection->bytesAccepted += toAdd;
            }

            //Drain receive buffer
            if (connection->unreadBytes > 0 && !connection->consumerPaused) {
                uint8_t count = (uint8_t) connection->unreadBytes;
                uint8_t k;

                for (k = 0; k < count; k++) {
                    uint8_t val = connection->rcvdBuff[connection->lastRead];
                    uint8_t expected = (uint8_t)((connection->bytesRead + k) % 256);
                    if (val != expected) {
                        dbg(TRANSPORT_CHANNEL, "MISMATCH at %u: got %u expected %u\n",
                            connection->bytesRead + k, val, expected);
                    }
                    connection->lastRead = (connection->lastRead + 1) % SOCKET_BUFFER_SIZE;
                }
                connection->bytesRead += count;
                connection->unreadBytes = 0;
                dbg(TRANSPORT_CHANNEL, "t=%lu node=%u CONSUMED total=%u\n",
                    timeNow, TOS_NODE_ID, connection->bytesRead);
            }

            //Go-Back-N Timeout Check
            if (connection->state == ESTABLISHED && connection->oldestUnAckedByte < connection->nxtUnSentByte) {
                if ((timeNow - connection->lastConnectionTime) >= RETRY_TIMEOUT_MS) {
                    if (connection->retransmitCount >= MAX_RETRIES) {
                        dbg(TRANSPORT_CHANNEL, "Connection failed after max retries\n");
                        connection->isActive = FALSE;
                        connection->state = CLOSED;
                    } else {
                        connection->retransmitCount++;
                        connection->nxtUnSentByte = connection->oldestUnAckedByte;
                        connection->retUnAckedBytes = 0;
                        connection->lastConnectionTime = timeNow;
                        testSendData(connection);
                    }
                }
            }
        }
        post serviceConnectionsTask();
    }
}