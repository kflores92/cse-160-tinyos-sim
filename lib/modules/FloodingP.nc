#include "../../includes/channels.h"
#include "../../includes/packet.h"

module FloodingP {
    provides interface Flooding;

    uses interface Random;
    uses interface SimpleSend as Sender;
    uses interface Receive;
    uses interface Hashmap<uint8_t> as Table;
}

implementation {  

    command void Flooding.init(){
        call Table.insert(0, 0);
    }

    command void Flooding.send(pack msg, uint16_t dest){
        call Sender.send(msg, AM_BROADCAST_ADDR);
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){   
        return msg;
    }
}