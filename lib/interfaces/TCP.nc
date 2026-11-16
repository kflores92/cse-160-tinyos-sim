interface TCP {
    command void start();

    command void testSendData(socket_store_t *connection);

    event void TinynetDone(pack* msg, error_t result);

    command void handleDataSegment(transport* seg, socket_store_t *connection);

    task void handleAckSegment(transport* seg, socket_store_t *connection);
}