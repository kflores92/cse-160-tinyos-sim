from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.ROUTING_CHANNEL);

    s.runTime(20);
    s.routeDMP(1);
    s.runTime(2);
    s.routeDMP(4);
    s.runTime(10);
    s.ping(1, 4, "Hello 4 from 1.");
    s.runTime(20);


if __name__ == '__main__':
    main()