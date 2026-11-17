#ifndef CONNECTION_H
#define CONNECTION_H

enum {
    NO_ADDRESS = 0;
    NO_PORT = 0;
    DEFAULT_LISTEN_PORT = 255;
}

enum action{
    SEND,
    CLOSE,
    CONNECT,
    LISTEN,
    SYN,
    SYNACK,
    ACK,
    FIN,
    FINACK
};

typedef nx_struct conn_store {
    nx_uint8_t state;
    nx_uint16_t dest_addr;
    nx_uint8_t dest_port;
    nx_uint8_t seq;
    nx_uint8_t lastAck;
}conn_store;

#endif