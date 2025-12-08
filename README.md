# Hardened Home Server Setup (Proxmox + VPN Streaming + Modular LXC Stack)

## 1. 📦 Overview

This project documents a hardened, media streaming server that uses Stremio which I built as a gift.
The system is designed for security, modularity, and expandability, using Proxmox VE as the hypervisor.

In it's current configuration, it runs:

--> 📡 VPN LXC – Runs ProtonVPN-CLI / WireGuard and acts as a gateway.

--> 📺 Stremio LXC – Runs the Stremio server, sending all outbound traffic through the VPN container.

Network routing is handled using policy-based routing, iptables, and Proxmox container configuration.

A future-proof architecture that allows adding LXC containers for Home Assistant, Frigate, and other home-automation services

The goal of the project was to build a privacy-focused streaming and automation environment that can grow over time without compromising security.

This Github Project aims to give others a guide on how to setup such a streaming server and for myself as a repository to copy the code if i want to replicate this server for other relatives with ease without having to rebuild and reconfigure everything from scratch.

## 2. Architecture Diagram (ASCII)
```
                ┌─────────────────────────┐
                │     Proxmox Host        │   <--- VPN Connection via Tailscale
                │  (Bridged Network, LXC  │        for remote Management/ Access
                │    management)          │                     │
                │  - Fail2Ban             │                     │
                │  - Tailscale VPN        │                     │
                │  - Netdata              │                     │    ┌───────────────────┐
                └─────▲─────▲─────▲───────┘                     └────► My remote Network │
                        │   │     │                                  └───────────────────┘
                        │   │     └────────────────────────────────────────────┐
           ┌────────────┘   └───────────────────────┐                          │
           │                                        │                          │
   ┌───────┴───────────┐                    ┌───────┴───────┐     ┌────────────┴────────────┐
   │    VPN LXC        │   Bridged Network  │   Stremio LXC │     │  Lightweight ARCH Linux │
   │ wg0: 192.168.0.28 │ <────────────────> │ No direct WAN │     │  for remote access      │
   │ VPN DNS           │                    │ Uses VPN LXC  │     │  of network devices     │
   │                   │                    │               │     │  e.g. router interface  │
   └───────▲───────────┘                    └───────────────┘     │  to add IP reservations │
           │                                       │              │  for future LXCs        │
           │                                       │              └─────────────────────────┘ 
           │                                       │
    ┌────────────┐                 ┌────────────────────────────────┐ 
    │  Internet  │                 │          192.168.0.X           │
    └────────────┘                 │ Internal Network for Streaming │
                                   │    on Smart TV/ IPad / etc     │
                                   └────────────────────────────────┘
```

## 3. How It Works
-  Proxmox as the Core

The Proxmox host manages all LXCs and provides hardware virtualization, backups, and isolation features.

-  📡 VPN LXC (Gateway Container)

This LXC contains the VPN client (e.g., ProtonVPN running on wireguard WireGuard).
It exposes a private internal interface to the Stremio LXC via a separate bridge (vmbr99) in my case but this is up to you.

Responsibilities:

Handles all outbound internet traffic for the Stremio LXC

Provides region-unlocked streaming access

Acts as the secure gateway for dependent containers

-  📺 Stremio LXC

This container runs Docker with a Stremio Server instance.
It has no direct internet route — its only network path goes through the VPN LXC (vmbr99).

Benefits:

Enforced privacy

Streaming addon geolocation freedom


## 4. Setup Summary

- Install Proxmox and configure secure defaults

- Create VPN LXC (Debian)

- Install and configure the VPN client (Wireguard using a ProtonVPN subscription)

- Create internal bridge (vmbr99) for isolated routing between both LXCs

- Create a Stremio LXC attached to the private VPN bridge, disable outbound internet connectivity

- Run Stremio Docker container

- Configure routing so Stremio uses the VPN as its gateway

- Test: verify Stremio has only VPN-based internet access

- Harden the system with firewall rules and access control + configure NAT and disable IPv6

- Create a script to handle automatic setting up of a Wireguard connection on startup / Boot and then removing the non-vpn outbound connection (see point following point 5.)


## 5. Systemd Auto-Start Integration

The following will show the steps I took to make a custom script that automatically runs on every boot. It ensures:

- No DNS leaks

- The VPN DNS is only used after the VPN tunnel is up

- All DNS traffic is blocked unless it goes to the VPN DNS

- The system temporarily uses a public DNS to bring up the VPN interface

- Fully automatic on boot via systemd

This tutorial assumes:

- Your ProtonVPN LXC runs WireGuard (wg0)

- VPN DNS is: 10.2.0.1

- Temporary DNS for bootstrapping: 1.1.1.1 (cloudflare)

(1). Create the VPN bootstrap script
Inside the VPN LXC, create:

```
sudo nano /usr/local/bin/vpn-dns-lock.sh
```

(2). Enter the following script:
```
#!/bin/bash
# vpn-dns-lock.sh

WG_IF="wg0"
VPN_DNS="10.2.0.1"
TEMP_DNS="1.1.1.1"
WAIT_TIMEOUT=15

# 1. Set temporary DNS to bootstrap VPN
echo "nameserver $TEMP_DNS" > /etc/resolv.conf
echo "[INFO] Temporary DNS $TEMP_DNS set."

# 2. Bring up WireGuard if not already up
if ! wg show $WG_IF &>/dev/null; then
    echo "[INFO] Bringing up WireGuard interface $WG_IF..."
    wg-quick up $WG_IF
fi

# 3. Wait until VPN DNS responds
echo "[INFO] Waiting for VPN DNS $VPN_DNS..."
for i in $(seq 1 $WAIT_TIMEOUT); do
    if dig @"$VPN_DNS" google.com +short &>/dev/null; then
        echo "[INFO] VPN DNS reachable!"
        break
    fi
    sleep 1
done

# 4. Switch resolv.conf to VPN DNS
echo "nameserver $VPN_DNS" > /etc/resolv.conf
echo "[INFO] Switched to VPN DNS $VPN_DNS."

# 5. Apply DNS leak protection
iptables -C OUTPUT ! -d $VPN_DNS -p udp --dport 53 -j REJECT 2>/dev/null || \
iptables -I OUTPUT ! -d $VPN_DNS -p udp --dport 53 -j REJECT
iptables -C OUTPUT ! -d $VPN_DNS -p tcp --dport 53 -j REJECT 2>/dev/null || \
iptables -I OUTPUT ! -d $VPN_DNS -p tcp --dport 53 -j REJECT
echo "[INFO] DNS leak protection applied."
```

Then, make it executable:

```
sudo chmod +x /usr/local/bin/vpn-dns-lock.sh
```
(3). Prevent Systemd-Resolved from overwriting DNS:

Enter:
```
chattr +i /etc/resolv.conf
```

(4). Create a Systemd Service:
Enter:
```
sudo nano /etc/systemd/system/vpn-dns-lock.service
```

Then paste in:

```
# /etc/systemd/system/vpn-dns-lock.service
[Unit]
Description=VPN DNS Lock
After=network-online.target wg-quick@wg0.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vpn-dns-lock.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```
Enable and start (automatically start on every boot):
```
sudo systemctl enable vpn-dns-lock.service
sudo systemctl start vpn-dns-lock.service
```

What this ensures against:
✔ DNS leaks
✔ LXC trying to use LAN DNS during boot
✔ Apps resolving via host (Proxmox) DNS
✔ Fallback DNS hijacking
✔ Fail-open scenarios when VPN temporarily drops

## 6. Set up a hardened Firewall to:


- General Policy: Drop all inbound traffic by default; allow only explicitly defined connections.

![Firewall Rules](contentimages/Firewallrules.png)

Apply the above shown Firewall rules on the Host-level under Proxmox->Firewall->Add.
Important here is to keep the Block all other connections as the very last rule to avoid locking yourtself out!



## 7. Final test for any DNS / IP Leaks from both containers:

![Testing VPN](contentimages/vpn-lxc-test.png)

Then a quick check using an online IP lookup tool:

![IP location](contentimages/vpn-location.png)


It works! All routing goes through my VPN including any DNS queries!

## 8. Future Expansion

The architecture supports adding more containers, such as:

Home Assistant (home automation)

Frigate NVR (AI IP camera processing)

Pi-hole or AdGuard Home (DNS filtering)

Media servers (Jellyfin/Plex)

Backup systems (UrBackup, Syncthing, etc.)
