interface Flooding{
    command void send(pack msg, uint16_t dest);
    command message_t* updateFlood(message_t* msg, void* payload, uint8_t len);
}