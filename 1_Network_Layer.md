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