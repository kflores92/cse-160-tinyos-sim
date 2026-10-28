#ifndef ROUTING_H
#define ROUTING_H

typedef nx_struct tuple{
    nx_uint8_t dest;
    nx_uint8_t next_hop;
    nx_uint8_t cost;
}tuple;

typedef nx_struct valid{
    nx_uint16_t age;
}valid;

enum {
    INF = 16,
    INVALID_NH = 0,
    MAX_NODES = 32,
    MAX_PAYLOAD_TUPLES = 4,
    IMMORTAL = 1024,
    AD_AGE = 8
};

#endif