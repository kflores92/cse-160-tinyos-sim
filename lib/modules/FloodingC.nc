configuration FloodingC {
    provides interface Flooding;
}

implementation {

    components FloodingP;
    Flooding = FloodingP;

    components RandomC as Random;
    FloodingP.Random -> Random;

    components new SimpleSendC(AM_PACK) as Sender;
    FloodingP.Sender -> Sender;

    components new AMReceiverC(AM_PACK) as GeneralReceive;
    FloodingP.Receive -> GeneralReceive;

    components new HashmapC(uint8_t, 64) as Table;
    FloodingP.Table -> Table;
}