interface TCP {
    command void startTCP();
    command error_t stateChange(uint8_t flag, pack* myMsg);
    command error_t sendSetup(uint8_t flag, uint8_t dest, uint8_t src_port, uint8_t dest_port, uint8_t ack, uint8_t* payload,);
    command error_t sendData(uint8_t* payload, uint8_t len, uint8_t dest, uint8_t port);
    command error_t processData(uint8_t* payload, uint8_t port);
}