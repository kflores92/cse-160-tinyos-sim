- DV Module (Distance Vector)

    - Access to The Neighbor Table
    - Use Bellman Ford to Update.
    - Use Split Horizon with Poison Reverse
    - Make a Routing Table <Hash>
        Maintain Destination, Next-Hop, Hop-Count
    - Remove Entries That Aren't In The Neighbor Table

- IP Module
    - Look at the routing table, keep most information unchanged,
    update the TTL, and then use SimpleSend to send to next hop.

Questions

    - Why is the Network wiring error happening?
        - Network is a reserved module.

    - How do we send the routingTable as a payload in a packet?
        - typecast
        - message_t*
        - ActiveMessageC

    - What format do we write the discussion questions in, 

Development

    - Send the RoutingTable as a payload.
    - Rewrite the processing logic in DVRouting.
    - Fixing an IP Compilation Errors after adding the send code.
    - Testing every case mentioned in the pdf.
    - Discussion Questions.