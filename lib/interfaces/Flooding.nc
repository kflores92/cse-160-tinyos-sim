interface Flooding{
    command void init();
    command void send(pack msg, uint16_t dest);
}