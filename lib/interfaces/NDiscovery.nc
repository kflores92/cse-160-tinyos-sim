interface NDiscovery{
    command void start();
    command uint32_t* getNeighbors();
    command uint16_t getTableSize();
    command void printNeighbors();
}