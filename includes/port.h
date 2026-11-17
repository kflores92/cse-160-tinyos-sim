#ifndef PORT
#define PORT

enum action{
    NONE,
    CLOSE,
    CONNECT,
    LISTEN,
    SYN,
    FIN
};

typedef nx_struct conn_store {
    nx_uint8_t state;
    nx_uint16_t dest_addr;
    nx_uint8_t dest_port;

    nx_uint8_t seq;
    nx_uint8_t lastAck;
}

#endif