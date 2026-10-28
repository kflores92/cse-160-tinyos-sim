interface Tinynet {
    command error_t send(pack* msg, uint16_t dest);
    command message_t* forwardIP(message_t* msg, void* payload, uint8_t len);
    
}