interface NDiscovery{
    command void start();
    command uint32_t* getNeighbors();
    command uint16_t getTableSize();
    command void printNeighbors();
    command message_t* updateNeighbors(message_t* msg, void* payload, uint8_t len);
}