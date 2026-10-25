#ifndef ROUTING_H
#define ROUTING_H

typedef nx_struct tuple{
    nx_uint16_t dest;
    nx_uint16_t next_hop;
    nx_uint16_t cost;
}tuple;

enum {
    INF = 33;
    MAX_NODES = 32;
}

#endif