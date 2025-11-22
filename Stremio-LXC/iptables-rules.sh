Chain INPUT (policy ACCEPT XXX packets, XXXXX bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DOCKER-USER  0    --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 DOCKER-FORWARD  0    --  *      *       0.0.0.0/0            0.0.0.0/0           

Chain OUTPUT (policy ACCEPT XX packets, XXXX bytes)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 REJECT     6    --  *      *       0.0.0.0/0           !10.XX.XX.XX             tcp dpt:53 reject-with icmp-port-unreachable
    0     0 REJECT     17   --  *      *       0.0.0.0/0           !10.XX.XX.XX             udp dpt:53 reject-with icmp-port-unreachable

Chain DOCKER (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DROP       0    --  !docker0 docker0  0.0.0.0/0            0.0.0.0/0           

Chain DOCKER-BRIDGE (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DOCKER     0    --  *      docker0  0.0.0.0/0            0.0.0.0/0           

Chain DOCKER-CT (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 ACCEPT     0    --  *      docker0  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED

Chain DOCKER-FORWARD (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DOCKER-CT  0    --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 DOCKER-ISOLATION-STAGE-1  0    --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 DOCKER-BRIDGE  0    --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     0    --  docker0 *       0.0.0.0/0            0.0.0.0/0           

Chain DOCKER-ISOLATION-STAGE-1 (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DOCKER-ISOLATION-STAGE-2  0    --  docker0 !docker0  0.0.0.0/0            0.0.0.0/0           

Chain DOCKER-ISOLATION-STAGE-2 (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DROP       0    --  *      docker0  0.0.0.0/0            0.0.0.0/0           

Chain DOCKER-USER (1 references)
 pkts bytes target     prot opt in     out     source               destination   
