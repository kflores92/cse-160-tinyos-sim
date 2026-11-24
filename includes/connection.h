#ifndef CONNECTION_H
#define CONNECTION_H

#include "socket.h"

enum {
    NO_ADDRESS = 0,
    NO_PORT = 0,
    DEFAULT_LISTEN_PORT = 255,
    MAX_CONNECTIONS = 10,
    DEFAULT_SENDER_WND = 52,
    RETRY_TIMEOUT_MS = 1000,
    MAX_RETRIES = 8
};

enum tcp_flags{
    DATA_FLAG = 1,
    ACK_FLAG = 2,
    SYN_FLAG = 4,
    FIN_FLAG = 8
};

typedef nx_struct tcp_hdr{
    nx_uint8_t srcPort;
    nx_uint8_t destPort;
    nx_uint8_t flags;
    nx_uint16_t seqNum;
    nx_uint16_t AckSeqNum;
    nx_uint8_t advertisedWindow;
    nx_uint8_t length;
}tcp_hdr;


typedef struct conn_store {
    bool isActive;

//next 4 states needed for 4 element tuple lookup
    uint8_t state;
    uint8_t src_port;
    uint16_t dest_addr;
    uint8_t dest_port;


    uint16_t seq;
    uint8_t lastAck;

    //SENDER STATE
    uint16_t oldestUnAckedByte;
    uint16_t nxtUnSentByte;
    uint16_t queuedAppBytes;
    uint16_t retUnAckedBytes;
    uint8_t senderWindowLim;
    uint8_t advWindowLim;

    uint8_t sendBuff[SOCKET_BUFFER_SIZE];
    uint8_t lastWritten;

    //RECIEVER STATE
    uint8_t rcvdBuff[SOCKET_BUFFER_SIZE];
    uint16_t nxtExpectedByte;
    uint8_t lastRead;
    uint8_t lastRcvdByte;
    uint16_t unreadBytes;

    uint16_t bytesRead;

    //TIMERS AND COUNTERS
    bool connInProg;
    uint32_t lastConnectionTime;
    uint8_t retransmitCount;
    bool closeRequested;
    uint16_t targetBytes;
    uint16_t bytesAccepted;
    uint16_t bytesAcked;
    uint16_t bytesConsumed;
    bool consumerPaused;
}conn_store;

#endif