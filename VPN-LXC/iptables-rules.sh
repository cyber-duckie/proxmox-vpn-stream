Chain INPUT (policy ACCEPT XXXK packets, XXXM bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
 XXXK  XXXK ACCEPT     0    --  eth1   wg0     0.0.0.0/0            0.0.0.0/0           
 XXXK  XXXM ACCEPT     0    --  wg0    eth1    0.0.0.0/0            0.0.0.0/0            state RELATED,ESTABLISHED
    0     0 ACCEPT     0    --  eth1   wg0     0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     0    --  wg0    eth1    0.0.0.0/0            0.0.0.0/0            state RELATED,ESTABLISHED
    0     0 ACCEPT     0    --  eth1   wg0     0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     0    --  wg0    eth1    0.0.0.0/0            0.0.0.0/0            state RELATED,ESTABLISHED
    0     0 ACCEPT     0    --  eth1   wg0     0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     0    --  wg0    eth1    0.0.0.0/0            0.0.0.0/0            state RELATED,ESTABLISHED
    0     0 ACCEPT     0    --  eth1   wg0     0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     0    --  wg0    eth1    0.0.0.0/0            0.0.0.0/0            state RELATED,ESTABLISHED

Chain OUTPUT (policy ACCEPT 102K packets, 16M bytes)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 REJECT     6    --  *      *       0.0.0.0/0           !10.X.X.X             tcp dpt:53 reject-with icmp-port-unreachable
   XX   XXX REJECT     17   --  *      *       0.0.0.0/0           !10.X.X.X             udp dpt:53 reject-with icmp-port-unreachable
