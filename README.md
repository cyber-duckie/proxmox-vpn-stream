# Hardened Home Server Setup (Proxmox + VPN Streaming + Modular LXC Stack)
1. 📦 Overview

This project documents a hardened, media streaming server that uses Stremio which I built as a gift.
The system is designed for security, modularity, and expandability, using Proxmox VE as the hypervisor.

In it's current configuration, it runs:

--> 📡 VPN LXC – Runs ProtonVPN-CLI / WireGuard and acts as a gateway.

--> 📺 Stremio LXC – Runs the Stremio server, sending all outbound traffic through the VPN container.

Network routing is handled using policy-based routing, iptables, and Proxmox container configuration.

A future-proof architecture that allows adding LXC containers for Home Assistant, Frigate, and other home-automation services

The goal of the project was to build a privacy-focused streaming and automation environment that can grow over time without compromising security.

This Github Project aims to give others a guide on how to setup such a streaming server and for myself as a repository to copy the code if i want to replicate this server for other relatives with ease without having to rebuild and reconfigure everything from scratch.

2. Architecture Diagram (ASCII)
```
                ┌─────────────────────────┐
                │     Proxmox Host        │   <--- VPN Connection via Tailscale
                │  (Bridged Network, LXC  │        for remote management/ access
                │    management)          │                      │
                └───────▲───────────▲─────┘                      └────► My remote Network
                        │           │
                        │           │
           ┌────────────┘           └───────────────┐
           │                                        │
   ┌───────┴───────────┐                    ┌───────┴─────────┐
   │    VPN LXC        │   Bridged Network  │    Stremio LXC  │
   │ wg0: 192.168.0.28 │ <────────────────> │ No direct WAN   │
   │ DNS: X.X.X.X      │                    │ Uses VPN LXC    │
   │ Torbox / AI       │                    │ AIostreams Addon│
   └───────▲───────────┘                    └─────────────────┘
           │                                       │
           │                                       │
           │                                       │
    ┌────────────┐                 ┌────────────────────────────────┐ 
    │  Internet  │                 │          192.168.0.X           │
    └────────────┘                 │ Internal Network for Streaming │
                                   │    on Smart TV/ IPad / etc     │
                                   └────────────────────────────────┘
```

3. How It Works
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


4. Setup Summary

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


5. Systemd Auto-Start Integration

To ensure the DNS-lock script runs automatically on every boot, I created a custom systemd service that executes /usr/local/bin/vpn-dns-lock.sh during startup. The service is placed in /etc/systemd/system/vpn-dns-lock.service and is configured to run after the network comes online.

After creating the service, I enabled it with:

```
systemctl enable vpn-dns-lock.service
systemctl start vpn-dns-lock.service
```
This guarantees that the script always boots with the container, applies the temporary DNS, brings up the VPN, switches to Proton’s DNS, and enforces DNS leak protection without manual intervention.

--> The script is located at VPN-LXC/initial-vpn-connection-script for reference!

6. Final test for any DNS / IP Leaks from both containers:

![Testing VPN](images/vpn-lxc-test.png)

Then a quick check using an online IP lookup tool:

![IP location](images/vpn-location.png)


It works! All routing goes through my VPN including any DNS queries!

6. Future Expansion

The architecture supports adding more containers, such as:

Home Assistant (home automation)

Frigate NVR (AI IP camera processing)

Pi-hole or AdGuard Home (DNS filtering)

Media servers (Jellyfin/Plex)

Backup systems (UrBackup, Syncthing, etc.)
