#ifndef ROUTING_H
#define ROUTING_H

typedef nx_struct tuple{
    nx_uint8_t dest;
    nx_uint8_t next_hop;
    nx_uint8_t cost;
}tuple;

enum {
    INF = 16,
    INVALID_NH = 0,
    MAX_NODES = 32,
    MAX_PAYLOAD_TUPLES = 4
};

#endif